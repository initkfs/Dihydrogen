module app.dn.protocols.stomp.stomp_codec;

import app.dn.codecs.codec : Codec;
import app.core.mem.static_buffer : StaticBuffer;

import std.typecons : Nullable;

debug import std.stdio : writefln, writeln;

enum StompControlСhars : byte
{
    //10
    lf = '\n',
    //13
    cr = '\r',
    //0
    nul = 0,
    //58
    colon = ':',
}

enum StompCommand : string
{
    //client
    SEND = "SEND",
    SUBSCRIBE = "SUBSCRIBE",
    UNSUBSCRIBE = "UNSUBSCRIBE",
    BEGIN = "BEGIN",
    CONNECT = "CONNECT",
    COMMIT = "COMMIT",
    ABORT = "ABORT",
    ACK = "ACK",
    NACK = "NACK",
    DISCONNECT = "DISCONNECT",
    STOMP = "STOMP",

    //server
    CONNECTED = "CONNECTED",
    MESSAGE = "MESSAGE",
    RECEIPT = "RECEIPT",
    ERROR = "ERROR"
}

struct StompHeader(T, size_t NameSize, size_t ValueSize)
{
    StaticBuffer!(T, NameSize) name;
    StaticBuffer!(T, ValueSize) value;
}

struct StompHeaders(T, size_t HeadersCount, size_t NameSize, size_t ValueSize)
{
    StaticBuffer!(StompHeader!(T, NameSize, ValueSize), HeadersCount, false) headers;
}

/**
 * Authors: initkfs
 */
class StompCodec : Codec
{
    StompCommand command;
    string headersLine;
    string bodyLine;

    StompCodecState state;

    char cr = StompControlСhars.cr;
    char lf = StompControlСhars.lf;

    size_t limitBodySizeBytes = size_t.max;

    StompHeaders!(char, 20, 256, 256) headersBuf;

    enum StompCodecState : string
    {
        none = "none",
        ok = "ok",
        error = "Common parser error",

        parseCmd = "Command parsing",
        parseCmdEOL = "Command EOL parsing",
        parseHeaders = "Headers parsing",
        parseBody = "Body parsing",
        endFrame = "End STOMP frame",

        errorEmptyBuffer = "Error. Input buffer is empty",
        errorInvalidCommand = "Error. Invalid command",
        errorParseCmdEOLEmpty = "Error. Received empty EOL line",
        errorParseCmdEOLNotSpec = "Error. Command EOL starting with invalid symbols",
        errorParseCmdEOLSpaceLimit = "Error. Command EOL exceeds the limit of empty chars after command",
        errorMessageEndWithoutEOL = "Error. The message ends without a trailing EOL",
        errorHeadersWithoutEOL = "Error. Header ends without a trailing EOL",
        errorHeaderNameTooLong = "Error. Header name too long",
        errorHeaderValueTooLong = "Error. Header value too long",
        errorHeadersCountOverflow = "Error. Headers count overflow",

        errorBodyIsOverLimit = "Error. Message body is over limit",
        errorBodyNoAllowedInFrame = "Error. Only the SEND, MESSAGE, and ERROR frames may have a body"
    }

    void decode(ubyte[] buff)
    {
        ubyte[] buffSlice = buff;
        parseLoop: while (buffSlice.length > 0)
        {
            switch (state) with (StompCodecState)
            {
                case none:
                    state = StompCodecState.parseCmd;

                    StompCommand mustBeCmd;
                    state = parseFrameCommand(buff, mustBeCmd);
                    if (state != StompCodecState.ok)
                    {
                        continue;
                    }

                    command = mustBeCmd;
                    buffSlice = buff[(command.length) .. $];
                    if (buffSlice.length == 0)
                    {
                        state = StompCodecState.endFrame;
                        continue;
                    }

                    state = parseCmdEOL;
                    continue;
                    break;
                case parseCmdEOL:
                    size_t offset;
                    state = parseFrameCommandEOL(buffSlice, offset);
                    if (state != StompCodecState.ok)
                    {
                        continue;
                    }

                    if (offset == 0)
                    {
                        state = StompCodecState.errorParseCmdEOLEmpty;
                        continue;
                    }

                    buffSlice = buffSlice[offset .. $];
                    if (buffSlice.length == 0)
                    {
                        //state = StompCodecState.errorMessageEndWithoutEOL;
                        state = StompCodecState.endFrame;
                        continue;
                    }

                    if (auto startOffset = isStartFromEOL(buffSlice))
                    {
                        buffSlice = buffSlice[startOffset .. $];
                        if (buffSlice.length == 0)
                        {
                            state = StompCodecState.endFrame;
                            continue;
                        }

                        state = parseBody;
                        continue;
                    }

                    state = parseHeaders;
                    continue;
                    break;
                case parseHeaders:
                    size_t headersEOLSize;
                    size_t headersOffset;
                    state = parseFrameHeaders(buffSlice, headersOffset, headersEOLSize);
                    if (state != StompCodecState.ok)
                    {
                        continue;
                    }

                    if (headersEOLSize == 0)
                    {
                        state = StompCodecState.errorHeadersWithoutEOL;
                        continue;
                    }

                    if (headersOffset == 0)
                    {
                        //TODO validate command
                        state = StompCodecState.endFrame;
                        return;
                    }

                    import std.conv : to;

                    headersLine = (cast(char[]) buffSlice[0 .. headersOffset]).to!string;

                    buffSlice = buffSlice[headersOffset + headersEOLSize .. $];
                    if (buffSlice.length == 0)
                    {
                        state = StompCodecState.endFrame;
                        return;
                    }

                    if (command != StompCommand.SEND
                        && command != StompCommand.MESSAGE
                        && command != StompCommand.ERROR)
                    {
                        state = StompCodecState.errorBodyNoAllowedInFrame;
                        continue;
                    }

                    state = parseBody;

                    break;
                case parseBody:
                    size_t offset;
                    state = parseFrameBodyLine(buffSlice, offset);
                    if (state != StompCodecState.ok)
                    {
                        continue;
                    }

                    if (offset == 0)
                    {
                        state = StompCodecState.endFrame;
                        continue;
                    }

                    import std.conv : to;

                    bodyLine = (cast(char[]) buffSlice[0 .. offset]).to!string;
                    state = StompCodecState.endFrame;
                    break;
                default:
                    break parseLoop;
            }
        }
    }

    size_t isStartFromEOL(scope const(ubyte)[] buff) @safe
    {
        if (buff.length == 0)
        {
            return 0;
        }

        auto firstChar = buff[0];
        if (firstChar == lf)
        {
            return lf.sizeof;
        }

        if (firstChar != cr || buff.length < 2)
        {
            return 0;
        }

        if (buff[1] == lf)
        {
            return cr.sizeof + lf.sizeof;
        }

        return 0;
    }

    size_t parseEOL(scope const(ubyte)[] buff, bool isAllowSpaces = false, out bool isSpacesOverflow, size_t spaceLimit = 100) @safe
    {
        if (buff.length == 0)
        {
            return 0;
        }

        size_t offset;
        const size_t lastIndex = buff.length - 1;
        size_t spacesCount;
        foreach (i, ch; buff)
        {
            if (ch == ' ')
            {
                if (!isAllowSpaces)
                {
                    return 0;
                }
                else if (spacesCount >= spaceLimit)
                {
                    isSpacesOverflow = true;
                    return 0;
                }
                else
                {
                    offset++;
                    spacesCount++;
                }
            }

            if (ch == StompControlСhars.lf)
            {
                return offset + StompControlСhars.lf.sizeof;
            }

            if (ch == StompControlСhars.cr)
            {
                if (i == lastIndex)
                {
                    return 0;
                }
                auto nextChar = buff[i + 1];
                if (nextChar == StompControlСhars.lf)
                {
                    offset += (StompControlСhars.cr.sizeof + StompControlСhars.lf.sizeof);
                    return offset;
                }
            }
        }

        return offset;
    }

    StompCodecState parseFrameCommand(scope const(char)[] buff, out StompCommand cmd) @safe
    {
        return parseFrameCommand(cast(const(ubyte)[]) buff, cmd);
    }

    StompCodecState parseFrameCommand(scope const(ubyte)[] buff, out StompCommand cmd) @safe
    {
        if (buff.length == 0)
        {
            return StompCodecState.errorEmptyBuffer;
        }

        import std.traits : EnumMembers;

        bool isStartsFromCommand(scope const(ubyte)[] buff, string command) @safe
        {
            if (buff.length < command.length || command.length == 0)
            {
                return false;
            }
            auto buffSlice = buff[0 .. (command.length)];
            foreach (i, ch; buffSlice)
            {
                if (ch != command[i])
                {
                    return false;
                }
            }
            return true;
        }

        static foreach (i, member; EnumMembers!StompCommand)
        {
            if (isStartsFromCommand(buff, member.stringof))
            {
                cmd = member;
                return StompCodecState.ok;
            }
        }

        return StompCodecState.errorInvalidCommand;
    }

    StompCodecState parseFrameCommandEOL(
        scope const(char)[] buff,
        out size_t eolOffset,
        bool isAllowSpaces = true,
        size_t spaceLimits = 100) @safe
    {
        return parseFrameCommandEOL(cast(const(ubyte)[]) buff, eolOffset, isAllowSpaces, spaceLimits);
    }

    StompCodecState parseFrameCommandEOL(
        scope const(ubyte)[] buff,
        out size_t eolOffset,
        bool isAllowSpaces = true,
        size_t spaceLimits = 100
    ) @safe
    {
        if (buff.length == 0)
        {
            return StompCodecState.errorEmptyBuffer;
        }

        bool isSpaceOverflow;

        auto offset = parseEOL(buff, isAllowSpaces, isSpaceOverflow, spaceLimits);

        if (isSpaceOverflow)
        {
            return StompCodecState.errorParseCmdEOLSpaceLimit;
        }

        if (offset == 0)
        {
            return StompCodecState.errorParseCmdEOLNotSpec;
        }

        eolOffset = offset;

        return StompCodecState.ok;
    }

    StompCodecState parseFrameHeadersLine(
        scope const(char)[] buff,
        out size_t headersOffset,
        out size_t headersEndEOL)
    @safe
    {
        return parseFrameHeadersLine(cast(const(ubyte)[]) buff, headersOffset, headersEndEOL);
    }

    StompCodecState parseFrameHeadersLine(
        scope const(ubyte)[] buff,
        out size_t headersOffset,
        out size_t headersEndEOL)
    @safe
    {
        if (buff.length == 0)
        {
            return StompCodecState.errorEmptyBuffer;
        }

        size_t offset;

        for (size_t i = 0; i < buff.length; i++)
        {
            size_t eolOffset = isStartFromEOL(buff[i .. $]);
            if (eolOffset > 0)
            {
                if (i == 0 || (buff[i - 1] != lf))
                {
                    offset += eolOffset;
                    i += (eolOffset - 1);
                    continue;
                }

                headersEndEOL = eolOffset;
                headersOffset = offset;
                return StompCodecState.ok;
            }

            offset++;
        }

        return StompCodecState.errorHeadersWithoutEOL;
    }

    StompCodecState parseFrameHeaders(
        scope const(ubyte)[] buff,
        out size_t headersOffset,
        out size_t headersEndEOL)
    @safe
    {
        if (buff.length == 0)
        {
            return StompCodecState.errorEmptyBuffer;
        }

        foreach (i; 0..headersBuf.headers.capacity)
        {
            headersBuf.headers[i].name.reset;
            headersBuf.headers[i].value.reset;
        }

        headersBuf.headers.reset;

        size_t curHeaderIndex;

        size_t offset;

        bool isParseHeaderName = true;

        for (size_t i = 0; i < buff.length; i++)
        {
            if (curHeaderIndex >= headersBuf.headers.capacity)
            {
                return StompCodecState.errorHeadersCountOverflow;
            }

            if(buff[i] == ':'){
                if(isParseHeaderName){
                    isParseHeaderName = false;
                }
                offset++;
                continue;
            }

            size_t eolOffset = isStartFromEOL(buff[i .. $]);
            if (eolOffset > 0)
            {
                if (i == 0 || (buff[i - 1] != lf))
                {
                    offset += eolOffset;
                    i += (eolOffset - 1);

                    if(!isParseHeaderName){
                        isParseHeaderName = true;
                    }

                    curHeaderIndex++;

                    continue;
                }

                headersBuf.headers.length = curHeaderIndex;

                headersEndEOL = eolOffset;
                headersOffset = offset;
                return StompCodecState.ok;
            }

            if(isParseHeaderName){
                headersBuf.headers[curHeaderIndex].name ~= buff[i];
            }else {
                headersBuf.headers[curHeaderIndex].value ~= buff[i];
            }

            offset++;
        }

        return StompCodecState.errorHeadersWithoutEOL;
    }

    StompCodecState parseFrameBodyLine(scope const(ubyte)[] buff, out size_t bodySize) @safe
    {
        size_t offset;
        foreach (ch; buff)
        {
            if (offset >= limitBodySizeBytes)
            {
                return StompCodecState.errorBodyIsOverLimit;
            }

            if (ch == StompControlСhars.nul)
            {
                break;
            }

            offset++;
        }

        bodySize = offset;

        return StompCodecState.ok;
    }

    void reset()
    {
        state = StompCodecState.none;
        headersLine = null;
        bodyLine = null;
    }

}

//parseFrameCommand
unittest
{
    auto codec = new StompCodec;

    StompCommand mustBeCmd;

    ubyte[] str;
    assert(codec.parseFrameCommand(str, mustBeCmd) == StompCodec.StompCodecState.errorEmptyBuffer);
    assert(codec.parseFrameCommand(['a', 'c'], mustBeCmd) == StompCodec
            .StompCodecState.errorInvalidCommand);
    assert(codec.parseFrameCommand("COMMIT", mustBeCmd) == StompCodec.StompCodecState.ok);
    assert(mustBeCmd == StompCommand.COMMIT);

    assert(codec.parseFrameCommand("commit", mustBeCmd) == StompCodec
            .StompCodecState.errorInvalidCommand);

    assert(codec.parseFrameCommand("ACK", mustBeCmd) == StompCodec
            .StompCodecState.ok);
    assert(mustBeCmd == StompCommand.ACK);

    assert(codec.parseFrameCommand("ACK111", mustBeCmd) == StompCodec
            .StompCodecState.ok);
    assert(mustBeCmd == StompCommand.ACK);

    assert(codec.parseFrameCommand("111ACK", mustBeCmd) == StompCodec
            .StompCodecState.errorInvalidCommand);
}

//parseFrameCommandEOL
unittest
{
    auto codec = new StompCodec;
    enum spaceLimit = 5;
    size_t offset;
    assert(codec.parseFrameCommandEOL("     \r\n", offset, true, spaceLimit) == StompCodec
            .StompCodecState.ok);
    assert(offset == 7);
    assert(codec.parseFrameCommandEOL("      \r\n", offset, true, spaceLimit) == StompCodec
            .StompCodecState.errorParseCmdEOLSpaceLimit);

    assert(codec.parseFrameCommandEOL("\n", offset, true, spaceLimit) == StompCodec
            .StompCodecState.ok);
    assert(offset == 1);

    assert(codec.parseFrameCommandEOL("\r\n", offset, true, spaceLimit) == StompCodec
            .StompCodecState.ok);
    assert(offset == 2);

    assert(codec.parseFrameCommandEOL("\r\t", offset, true, spaceLimit) == StompCodec
            .StompCodecState.errorParseCmdEOLNotSpec);

    assert(codec.parseFrameCommandEOL("\t", offset, true, spaceLimit) == StompCodec
            .StompCodecState.errorParseCmdEOLNotSpec);

}

//parseFrameHeadersLine
unittest
{
    auto codec = new StompCodec;
    size_t headersOffset;
    size_t headersEOLOffset;
    assert(codec.parseFrameHeadersLine(" ", headersOffset, headersEOLOffset) == StompCodec
            .StompCodecState.errorHeadersWithoutEOL);
    assert(codec.parseFrameHeadersLine("al:df", headersOffset, headersEOLOffset) == StompCodec
            .StompCodecState.errorHeadersWithoutEOL);

    assert(codec.parseFrameHeadersLine(" \r\n", headersOffset, headersEOLOffset) == StompCodec
            .StompCodecState.errorHeadersWithoutEOL);

    assert(codec.parseFrameHeadersLine(" \r\n\r\n", headersOffset, headersEOLOffset) == StompCodec
            .StompCodecState.ok);
    assert(headersOffset == 3);
    assert(headersEOLOffset == 2);

    assert(codec.parseFrameHeadersLine(" \n\n", headersOffset, headersEOLOffset) == StompCodec
            .StompCodecState.ok);
    assert(headersOffset == 2);
    assert(headersEOLOffset == 1);

    assert(codec.parseFrameHeadersLine("hello\r\nworld\n\n", headersOffset, headersEOLOffset) == StompCodec
            .StompCodecState.ok);
    assert(headersOffset == 13);
    assert(headersEOLOffset == 1);

    assert(codec.parseFrameHeadersLine("hello\r\nworld\n\r\n", headersOffset, headersEOLOffset) == StompCodec
            .StompCodecState.ok);
    assert(headersOffset == 13);
    assert(headersEOLOffset == 2);

    assert(codec.parseFrameHeadersLine("hello\nworld\r\n\r\n", headersOffset, headersEOLOffset) == StompCodec
            .StompCodecState.ok);
    assert(headersOffset == 13);
    assert(headersEOLOffset == 2);
}

//parseBodyLine
unittest
{
    auto codec = new StompCodec;
    const(ubyte)[] message = cast(const(ubyte)[]) "hello world\0";
    size_t size;
    assert(codec.parseFrameBodyLine(message, size) == StompCodec.StompCodecState.ok);
    assert(size == 11);
}

unittest
{
    import std.conv : to;

    ubyte[] connectFrame = cast(ubyte[]) "MESSAGE \r\naccept-version:1.2\r\nhost:stomp.github.org\r\n\r\nhello world \0"
        .dup;

    auto codec = new StompCodec;
    codec.decode(connectFrame);
    assert(codec.state == StompCodec.StompCodecState.endFrame);
    assert(codec.command == StompCommand.MESSAGE);

    assert(codec.headersLine == "accept-version:1.2\r\nhost:stomp.github.org\r\n");
    assert(codec.bodyLine == "hello world ");

    // writeln(codec.headersBuf.headers.length);
    // foreach (i; 0..codec.headersBuf.headers.length)
    // {
    //     writefln("%s: %s", codec.headersBuf.headers[i].name, codec.headersBuf.headers[i].value);
    // }
    assert(codec.headersBuf.headers.length == 2);
    auto header1 = codec.headersBuf.headers[0];
    assert(header1.name[] == "accept-version");
    assert(header1.value[] == "1.2");

    auto header2 = codec.headersBuf.headers[1];
    assert(header2.name[] == "host");
    assert(header2.value[] == "stomp.github.org");

    ubyte[] connectFrame2 = cast(ubyte[]) "CONNECT\naccept-version:1.2\nhost:127.0.0.1\n\n".dup;
    codec = new StompCodec;
    codec.decode(connectFrame2);
    assert(codec.state == StompCodec.StompCodecState.endFrame);
    assert(codec.command == StompCommand.CONNECT);
    assert(codec.headersLine == "accept-version:1.2\nhost:127.0.0.1\n");
    assert(codec.bodyLine == "");
}
