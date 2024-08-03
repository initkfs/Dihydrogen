module app.dn.protocols.stomp.stomp_codec;

import app.dn.codecs.codec : Codec;

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

enum StompCommandType : string
{
    UNKNOWN = "UNKNOWN",
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

struct StompCommand
{
    StompCommandType type;
}

struct StompFrame
{
    StompCommand frameCommand;
    Nullable!StompHeaders frameHeaders;
    Nullable!StompBody frameBody;
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

    enum StompCodecState
    {
        none,
        error,
        parseCmdEOL,
        parseHeaders,
        parseBody,
        endFrame
    }

    void decode(ubyte[] buff)
    {
        ubyte[] buffSlice = buff;
        parseLoop: while (buffSlice.length > 0)
        {
            final switch (state) with (StompCodecState)
            {
                case none:
                    command = parseCommand(buff);
                    if (command.type == StompCommandType.UNKNOWN)
                    {
                        state = StompCodecState.error;
                        return;
                    }

                    auto offset = command.type.length;
                    buffSlice = buff[offset .. $];
                    if (buffSlice.length == 0)
                    {
                        state = StompCodecState.endFrame;
                        continue;
                    }
                    state = parseCmdEOL;
                    continue;
                    break;
                case parseCmdEOL:
                    auto offset = parseEOL(buffSlice, isAllowSpaces:
                        true);
                    if (offset == 0)
                    {
                        state = StompCodecState.error;
                        return;
                    }

                    buffSlice = buffSlice[offset .. $];
                    if (buffSlice.length == 0)
                    {
                        state = StompCodecState.error;
                        return;
                    }

                    if (auto startOffset = isStartFromEOL(buffSlice))
                    {
                        buffSlice = buffSlice[startOffset .. $];
                        if (buffSlice.length == 0)
                        {
                            state = StompCodecState.endFrame;
                            return;
                        }
                        state = parseBody;
                        continue;
                    }

                    state = parseHeaders;
                    continue;
                    break;
                case parseHeaders:
                    size_t headersEOLSize;
                    auto offset = parseHeadersLine(buffSlice, headersEOLSize);
                    if (headersEOLSize == 0)
                    {
                        state = StompCodecState.error;
                        return;
                    }
                    if (offset == 0)
                    {
                        //TODO validate command
                        state = StompCodecState.endFrame;
                        return;
                    }

                    import std.conv : to;

                    headersLine = (cast(char[]) buffSlice[0 .. offset]).to!string;

                    buffSlice = buffSlice[offset + headersEOLSize .. $];
                    if (buffSlice.length == 0)
                    {
                        state = StompCodecState.endFrame;
                        return;
                    }
                    state = parseBody;
                    break;
                case parseBody:
                    auto offset = parseBodyLine(buffSlice);
                    if (offset == 0)
                    {
                        state = StompCodecState.endFrame;
                        return;
                    }

                    import std.conv : to;

                    bodyLine = (cast(char[]) buffSlice[0 .. offset]).to!string;
                    state = StompCodecState.endFrame;
                    break;
                case endFrame:
                    break parseLoop;
                case error:
                    break parseLoop;
                    break;
            }
        }
    }

    size_t isStartFromEOL(ubyte[] buff)
    {
        if (buff.length == 0)
        {
            return 0;
        }

        auto firstChar = buff[0];
        if (firstChar == StompControlСhars.lf)
        {
            return StompControlСhars.lf.sizeof;
        }

        if (firstChar != StompControlСhars.cr || buff.length < 2)
        {
            return 0;
        }

        if (buff[1] == StompControlСhars.lf)
        {
            return StompControlСhars.cr.sizeof + StompControlСhars.lf.sizeof;
        }

        return 0;
    }

    size_t parseBodyLine(ubyte[] buff)
    {
        size_t offset;
        foreach (ch; buff)
        {
            if (ch == StompControlСhars.nul)
            {
                break;
            }

            offset++;
        }

        return offset;
    }

    size_t parseHeadersLine(ubyte[] buff, out size_t headersEndEOL)
    {
        if (buff.length == 0)
        {
            return 0;
        }

        size_t offset;
        for (size_t i = 0; i < buff.length; i++)
        {
            if (auto eolOffset = isStartFromEOL(buff[i .. $]))
            {
                if (i == 0)
                {
                    offset += eolOffset;
                    i += eolOffset;
                    continue;
                }
                auto prevChar = buff[i - 1];
                if (prevChar == StompControlСhars.lf)
                {
                    headersEndEOL = eolOffset;
                    return offset;
                }
            }

            offset++;
        }

        return offset;
    }

    size_t parseEOL(ubyte[] buff, bool isAllowSpaces = false)
    {
        if (buff.length == 0)
        {
            return 0;
        }

        size_t offset;
        const size_t lastIndex = buff.length - 1;
        foreach (i, ch; buff)
        {
            if (ch == ' ')
            {
                if (!isAllowSpaces)
                {
                    return 0;
                }
                else
                {
                    offset++;
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

    StompCommand parseCommand(ubyte[] buff)
    {
        if (buff.length == 0)
        {
            return StompCommand(StompCommandType.UNKNOWN);
        }

        import std.traits : EnumMembers;

        bool isStartsFromCommand(ubyte[] buff, string command)
        {
            import std.algorithm.searching : startsWith;

            return buff.startsWith(command);
        }

        static foreach (i, member; EnumMembers!StompCommandType)
        {
            if (isStartsFromCommand(buff, member.stringof))
            {
                return StompCommand(member);
            }
        }

        return StompCommand(StompCommandType.UNKNOWN);
    }

    void reset()
    {
        state = StompCodecState.none;
        headersLine = null;
        bodyLine = null;
        command = StompCommand.init;
    }

}

unittest
{
    import std.conv : to;

    ubyte[] connectFrame = cast(ubyte[]) "CONNECT \r\naccept-version:1.2\r\nhost:stomp.github.org\r\n\r\nhello world \0"
        .dup;

    auto codec = new StompCodec;
    codec.decode(connectFrame);
    assert(codec.state == StompCodec.StompCodecState.endFrame);
    assert(codec.command.type == StompCommandType.CONNECT);
    assert(codec.headersLine == "accept-version:1.2\r\nhost:stomp.github.org\r\n");
    assert(codec.bodyLine == "hello world ");
}
