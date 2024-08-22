module api.dn.protocols.stomp.stomp_decoder;

import api.dn.codecs.codec : Codec;
import api.core.mem.buffers.static_buffer : StaticBuffer;

import api.dn.protocols.stomp.stomp_common;

import std.typecons : Nullable;

debug import std.stdio : writefln, writeln;

enum DecoderState : string
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
    errorHeadersBufferCountOverflow = "Error. Headers buffers count overflow",
    errorHeadersLimitsOverflow = "Error. Header limits overflow",
    errorHeaderNameBufCapOverflow = "Error. Header name buffer length overflow",
    errorHeaderValueBufCapOverflow = "Error. Header value buffer length overflow",

    errorBodyIsOverLimit = "Error. Message body is over limit",
    errorBodyNoAllowedInFrame = "Error. Only the SEND, MESSAGE, and ERROR frames may have a body",

    errorMessageWithoutContentLength = "Error. SEND, MESSAGE and ERROR frames should include a content-length header",
    errorMessageInvalidContentLength = "Error. Invalid content-length header value",
    errorMessageWithoutContentType = "Error. SEND, MESSAGE and ERROR frames should include a content-type",
    errorMessageInvalidContentType = "Error. Frame invalid content type",
    errorMessageNotAllowedReceipt = "Error. CONNECT framemust not contain a receipt header",
    errorMessageWithoutDest = "Error. MESSAGE frame must contain a destination",
    errorFrameWithoutReceiptId = "ERROR. RECEIPT frame must contain receipt id header" ~ StompDefaultHeader.receiptID,
    errorMessageWithoutMessageID = "Error, MESSAGE frame must contain message id headers " ~ StompDefaultHeader
        .messageID,
    errorVersionNotCurrent = "Error. Only allowed STOMP protocol version: " ~ StompVersion
        .current,
    errorFrameWithoutDestination = "Error. SEND, SUBSCRIBE frame must contain a destination header",
    errorFrameWithoudID = "Error. SUBSCRIBE, UNSUBSCRIBE, NACK, ACK frame must contain an id header",
    errorFrameWithoudTransactionHeader = "Error. BEGIN, COMMIT, ABORT frame must contain an transaction header"
}

/**
 * Authors: initkfs
 */
class StompDecoder : Codec
{
    StompCommand command;

    string headersLine;
    string bodyLine;

    DecoderState state;

    char cr = StompControlСhar.cr;
    char lf = StompControlСhar.lf;

    size_t limitBodySizeBytes = size_t.max;
    size_t limitHeadersCount = 20;

    bool isValidateFrames;

    StaticBuffer!(StompHeader!(char, 256, 256), 20, false) headers;

    void decode(ubyte[] buff)
    {
        reset;

        ubyte[] buffSlice = buff;
        parseLoop: while (buffSlice.length > 0)
        {
            switch (state) with (DecoderState)
            {
                case none:
                    state = DecoderState.parseCmd;

                    StompCommand mustBeCmd;
                    state = parseFrameCommand(buff, mustBeCmd);
                    if (state != DecoderState.ok)
                    {
                        continue;
                    }

                    command = mustBeCmd;
                    buffSlice = buff[(command.length) .. $];
                    if (buffSlice.length == 0)
                    {
                        state = DecoderState.endFrame;
                        continue;
                    }

                    state = parseCmdEOL;
                    continue;
                    break;
                case parseCmdEOL:
                    size_t offset;
                    state = parseFrameCommandEOL(buffSlice, offset);
                    if (state != DecoderState.ok)
                    {
                        continue;
                    }

                    if (offset == 0)
                    {
                        state = DecoderState.errorParseCmdEOLEmpty;
                        continue;
                    }

                    buffSlice = buffSlice[offset .. $];
                    if (buffSlice.length == 0)
                    {
                        //state = DecoderState.errorMessageEndWithoutEOL;
                        state = DecoderState.endFrame;
                        continue;
                    }

                    if (auto startOffset = isStartFromEOL(buffSlice))
                    {
                        buffSlice = buffSlice[startOffset .. $];
                        if (buffSlice.length == 0)
                        {
                            state = DecoderState.endFrame;
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
                    if (state != DecoderState.ok)
                    {
                        continue;
                    }

                    if (headersEOLSize == 0)
                    {
                        state = DecoderState.errorHeadersWithoutEOL;
                        continue;
                    }

                    if (headersOffset == 0)
                    {
                        //TODO validate command
                        state = DecoderState.endFrame;
                        return;
                    }

                    import std.conv : to;

                    headersLine = (cast(char[]) buffSlice[0 .. headersOffset]).to!string;

                    if (isValidateFrames)
                    {
                        if (auto versionHeader = hasHeader(StompDefaultHeader.ver))
                        {
                            auto versionValue = versionHeader.value[];
                            if (versionValue != StompVersion.current)
                            {
                                state = DecoderState.errorVersionNotCurrent;
                                continue;
                            }
                        }

                        if (hasHeader(StompDefaultHeader.receipt) && command == StompCommand
                            .CONNECT)
                        {
                            state = DecoderState.errorMessageNotAllowedReceipt;
                            continue;
                        }

                        if (command == StompCommand.SEND || command == StompCommand.SUBSCRIBE)
                        {
                            if (!hasHeader(StompDefaultHeader.destination))
                            {
                                state = DecoderState.errorFrameWithoutDestination;
                                continue;
                            }

                            if (!hasHeader(StompDefaultHeader.id))
                            {
                                state = DecoderState.errorFrameWithoudID;
                                continue;
                            }

                        }

                        if (command == StompCommand.UNSUBSCRIBE || command == StompCommand.ACK || command == StompCommand
                            .NACK)
                        {
                            if (!hasHeader(StompDefaultHeader.id))
                            {
                                state = DecoderState.errorFrameWithoudID;
                                continue;
                            }
                        }

                        if (command == StompCommand.BEGIN || command == StompCommand.ABORT || command == StompCommand
                            .COMMIT)
                        {
                            if (!hasHeader(StompDefaultHeader.transaction))
                            {
                                state = DecoderState.errorFrameWithoudTransactionHeader;
                                continue;
                            }
                        }

                        if (command == StompCommand.RECEIPT)
                        {
                            if (!hasHeader(StompDefaultHeader.receiptID))
                            {
                                state = DecoderState.errorFrameWithoutReceiptId;
                                continue;
                            }
                        }

                        if (command == StompCommand.MESSAGE)
                        {
                            if (!hasHeader(StompDefaultHeader.destination))
                            {
                                state = DecoderState.errorMessageWithoutDest;
                                continue;
                            }

                            if (!hasHeader(StompDefaultHeader.messageID))
                            {
                                state = DecoderState.errorMessageWithoutMessageID;
                                continue;
                            }
                        }
                    }

                    buffSlice = buffSlice[headersOffset + headersEOLSize .. $];
                    if (buffSlice.length == 0)
                    {
                        state = DecoderState.endFrame;
                        continue;
                    }

                    if (isValidateFrames)
                    {
                        if (command != StompCommand.SEND
                            && command != StompCommand.MESSAGE
                            && command != StompCommand.ERROR)
                        {
                            state = DecoderState.errorBodyNoAllowedInFrame;
                            continue;
                        }
                    }

                    state = parseBody;

                    break;
                case parseBody:

                    size_t offset;

                    if (!isValidateFrames)
                    {
                        state = parseFrameBodyLine(buffSlice, offset);
                    }
                    else
                    {
                        if (command == StompCommand.SEND || command == StompCommand.MESSAGE || command == StompCommand
                            .ERROR)
                        {
                            if (auto headerPtr = hasHeader(StompDefaultHeader.contentLength))
                            {
                                //TODO remove allocation
                                import std.conv : to;

                                try
                                {
                                    size_t bodySize = headerPtr.value[].to!size_t;
                                    //TODO 0?
                                    if (bodySize >= limitBodySizeBytes)
                                    {
                                        state = DecoderState.errorBodyIsOverLimit;
                                        continue;
                                    }

                                    if (bodySize > buffSlice.length)
                                    {
                                        state = DecoderState.error;
                                        continue;
                                    }

                                    //TODO The NULL terminator may not be present at the end
                                    offset = bodySize;
                                }
                                catch (Exception e)
                                {
                                    state = DecoderState.errorMessageInvalidContentLength;
                                    continue;
                                }
                            }
                            else
                            {
                                state = DecoderState.errorMessageWithoutContentLength;
                                continue;
                            }

                            if (!hasHeader(StompDefaultHeader.contentType))
                            {
                                state = DecoderState.errorMessageWithoutContentType;
                                continue;
                            }
                        }
                        else
                        {
                            state = parseFrameBodyLine(buffSlice, offset);
                        }
                    }

                    if (state != DecoderState.ok)
                    {
                        continue;
                    }

                    if (offset == 0)
                    {
                        state = DecoderState.endFrame;
                        continue;
                    }

                    import std.conv : to;

                    //TODO MIME + encoding
                    bodyLine = (cast(char[]) buffSlice[0 .. offset]).to!string;
                    state = DecoderState.endFrame;
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

            if (ch == StompControlСhar.lf)
            {
                return offset + StompControlСhar.lf.sizeof;
            }

            if (ch == StompControlСhar.cr)
            {
                if (i == lastIndex)
                {
                    return 0;
                }
                auto nextChar = buff[i + 1];
                if (nextChar == StompControlСhar.lf)
                {
                    offset += (StompControlСhar.cr.sizeof + StompControlСhar.lf.sizeof);
                    return offset;
                }
            }
        }

        return offset;
    }

    DecoderState parseFrameCommand(scope const(char)[] buff, out StompCommand cmd) @safe
    {
        return parseFrameCommand(cast(const(ubyte)[]) buff, cmd);
    }

    DecoderState parseFrameCommand(scope const(ubyte)[] buff, out StompCommand cmd) @safe
    {
        if (buff.length == 0)
        {
            return DecoderState.errorEmptyBuffer;
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
                return DecoderState.ok;
            }
        }

        return DecoderState.errorInvalidCommand;
    }

    DecoderState parseFrameCommandEOL(
        scope const(char)[] buff,
        out size_t eolOffset,
        bool isAllowSpaces = true,
        size_t spaceLimits = 100) @safe
    {
        return parseFrameCommandEOL(cast(const(ubyte)[]) buff, eolOffset, isAllowSpaces, spaceLimits);
    }

    DecoderState parseFrameCommandEOL(
        scope const(ubyte)[] buff,
        out size_t eolOffset,
        bool isAllowSpaces = true,
        size_t spaceLimits = 100
    ) @safe
    {
        if (buff.length == 0)
        {
            return DecoderState.errorEmptyBuffer;
        }

        bool isSpaceOverflow;

        auto offset = parseEOL(buff, isAllowSpaces, isSpaceOverflow, spaceLimits);

        if (isSpaceOverflow)
        {
            return DecoderState.errorParseCmdEOLSpaceLimit;
        }

        if (offset == 0)
        {
            return DecoderState.errorParseCmdEOLNotSpec;
        }

        eolOffset = offset;

        return DecoderState.ok;
    }

    DecoderState parseFrameHeadersLine(
        scope const(char)[] buff,
        out size_t headersOffset,
        out size_t headersEndEOL)
    @safe
    {
        return parseFrameHeadersLine(cast(const(ubyte)[]) buff, headersOffset, headersEndEOL);
    }

    DecoderState parseFrameHeadersLine(
        scope const(ubyte)[] buff,
        out size_t headersOffset,
        out size_t headersEndEOL)
    @safe
    {
        if (buff.length == 0)
        {
            return DecoderState.errorEmptyBuffer;
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
                return DecoderState.ok;
            }

            offset++;
        }

        return DecoderState.errorHeadersWithoutEOL;
    }

    DecoderState parseFrameHeaders(
        scope const(ubyte)[] buff,
        out size_t headersOffset,
        out size_t headersEndEOL)
    @safe
    {
        if (buff.length == 0)
        {
            return DecoderState.errorEmptyBuffer;
        }

        foreach (i; 0 .. headers.capacity)
        {
            headers[i].name.reset;
            headers[i].value.reset;
        }

        headers.reset;

        size_t curHeaderIndex;

        size_t offset;

        bool isParseHeaderName = true;

        for (size_t i = 0; i < buff.length; i++)
        {
            if (curHeaderIndex > limitHeadersCount)
            {
                return DecoderState.errorHeadersLimitsOverflow;
            }

            if (curHeaderIndex >= headers.capacity)
            {
                return DecoderState.errorHeadersBufferCountOverflow;
            }

            if (buff[i] == ':')
            {
                if (isParseHeaderName)
                {
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

                    if (!isParseHeaderName)
                    {
                        isParseHeaderName = true;
                    }

                    //TODO first \r\n without header name
                    curHeaderIndex++;

                    continue;
                }

                headers.length = curHeaderIndex;

                headersEndEOL = eolOffset;
                headersOffset = offset;
                return DecoderState.ok;
            }

            if (isParseHeaderName)
            {
                if (!headers[curHeaderIndex].name.append(buff[i]))
                {
                    return DecoderState.errorHeaderNameBufCapOverflow;
                }
            }
            else
            {
                if (!headers[curHeaderIndex].value.append(buff[i]))
                {
                    return DecoderState.errorHeaderValueBufCapOverflow;
                }
            }

            offset++;
        }

        return DecoderState.errorHeadersWithoutEOL;
    }

    DecoderState parseFrameBodyLine(scope const(ubyte)[] buff, out size_t bodySize) @safe
    {
        size_t offset;
        foreach (ch; buff)
        {
            if (offset >= limitBodySizeBytes)
            {
                return DecoderState.errorBodyIsOverLimit;
            }

            if (ch == StompControlСhar.nul)
            {
                break;
            }

            offset++;
        }

        bodySize = offset;

        return DecoderState.ok;
    }

    void reset()
    {
        state = DecoderState.none;
        headersLine = null;
        bodyLine = null;
    }

    const(char[]) headerValue(const(char)[] headerName)
    {
        if (auto header = hasHeader(headerName))
        {
            //TODO error?
            return header.value[];
        }

        return null;
    }

    //TODO headers duplications
    auto hasHeader(const(char)[] name)
    {
        foreach (i; 0 .. headers.length)
        {
            if (headers[i].name[] == name)
            {
                return headers[i];
            }
        }

        return null;
    }

}

//parseFrameCommand
unittest
{
    auto codec = new StompDecoder;

    StompCommand mustBeCmd;

    ubyte[] str;
    assert(codec.parseFrameCommand(str, mustBeCmd) == DecoderState.errorEmptyBuffer);
    assert(codec.parseFrameCommand(['a', 'c'], mustBeCmd) == DecoderState.errorInvalidCommand);
    assert(codec.parseFrameCommand("COMMIT", mustBeCmd) == DecoderState.ok);
    assert(mustBeCmd == StompCommand.COMMIT);

    assert(codec.parseFrameCommand("commit", mustBeCmd) == DecoderState.errorInvalidCommand);

    assert(codec.parseFrameCommand("ACK", mustBeCmd) == DecoderState.ok);
    assert(mustBeCmd == StompCommand.ACK);

    assert(codec.parseFrameCommand("ACK111", mustBeCmd) == DecoderState.ok);
    assert(mustBeCmd == StompCommand.ACK);

    assert(codec.parseFrameCommand("111ACK", mustBeCmd) == DecoderState.errorInvalidCommand);
}

//parseFrameCommandEOL
unittest
{
    auto codec = new StompDecoder;
    enum spaceLimit = 5;
    size_t offset;
    assert(codec.parseFrameCommandEOL("     \r\n", offset, true, spaceLimit) == DecoderState.ok);
    assert(offset == 7);
    assert(codec.parseFrameCommandEOL("      \r\n", offset, true, spaceLimit) == DecoderState
            .errorParseCmdEOLSpaceLimit);

    assert(codec.parseFrameCommandEOL("\n", offset, true, spaceLimit) == DecoderState.ok);
    assert(offset == 1);

    assert(codec.parseFrameCommandEOL("\r\n", offset, true, spaceLimit) == DecoderState.ok);
    assert(offset == 2);

    assert(codec.parseFrameCommandEOL("\r\t", offset, true, spaceLimit) == DecoderState
            .errorParseCmdEOLNotSpec);

    assert(codec.parseFrameCommandEOL("\t", offset, true, spaceLimit) == DecoderState
            .errorParseCmdEOLNotSpec);

}

//parseFrameHeadersLine
unittest
{
    auto codec = new StompDecoder;
    size_t headersOffset;
    size_t headersEOLOffset;
    assert(codec.parseFrameHeadersLine(" ", headersOffset, headersEOLOffset) == DecoderState
            .errorHeadersWithoutEOL);
    assert(codec.parseFrameHeadersLine("al:df", headersOffset, headersEOLOffset) == DecoderState
            .errorHeadersWithoutEOL);

    assert(codec.parseFrameHeadersLine(" \r\n", headersOffset, headersEOLOffset) == DecoderState
            .errorHeadersWithoutEOL);

    assert(codec.parseFrameHeadersLine(" \r\n\r\n", headersOffset, headersEOLOffset) == DecoderState
            .ok);
    assert(headersOffset == 3);
    assert(headersEOLOffset == 2);

    assert(codec.parseFrameHeadersLine(" \n\n", headersOffset, headersEOLOffset) == DecoderState.ok);
    assert(headersOffset == 2);
    assert(headersEOLOffset == 1);

    assert(codec.parseFrameHeadersLine("hello\r\nworld\n\n", headersOffset, headersEOLOffset) == DecoderState
            .ok);
    assert(headersOffset == 13);
    assert(headersEOLOffset == 1);

    assert(codec.parseFrameHeadersLine("hello\r\nworld\n\r\n", headersOffset, headersEOLOffset) == DecoderState
            .ok);
    assert(headersOffset == 13);
    assert(headersEOLOffset == 2);

    assert(codec.parseFrameHeadersLine("hello\nworld\r\n\r\n", headersOffset, headersEOLOffset) == DecoderState
            .ok);
    assert(headersOffset == 13);
    assert(headersEOLOffset == 2);
}

//parseBodyLine
unittest
{
    auto codec = new StompDecoder;
    const(ubyte)[] message = cast(const(ubyte)[]) "hello world\0";
    size_t size;
    assert(codec.parseFrameBodyLine(message, size) == DecoderState.ok);
    assert(size == 11);
}

unittest
{
    import std.conv : to;

    ubyte[] connectFrame = cast(ubyte[]) "MESSAGE \r\naccept-version:1.2\r\nhost:stomp.github.org\r\n\r\nhello world \0"
        .dup;

    auto codec = new StompDecoder;
    codec.decode(connectFrame);
    assert(codec.state == DecoderState.endFrame);
    assert(codec.command == StompCommand.MESSAGE);

    assert(codec.headersLine == "accept-version:1.2\r\nhost:stomp.github.org\r\n");
    assert(codec.bodyLine == "hello world ");

    // writeln(codec.headers.length);
    // foreach (i; 0..codec.headers.length)
    // {
    //     writefln("%s: %s", codec.headers[i].name, codec.headers[i].value);
    // }
    assert(codec.headers.length == 2);
    auto header1 = codec.headers[0];
    assert(header1.name[] == "accept-version");
    assert(header1.value[] == "1.2");

    auto header2 = codec.headers[1];
    assert(header2.name[] == "host");
    assert(header2.value[] == "stomp.github.org");

    ubyte[] connectFrame2 = cast(ubyte[]) "CONNECT\naccept-version:1.2\nhost:127.0.0.1\n\n".dup;
    codec = new StompDecoder;
    codec.decode(connectFrame2);
    assert(codec.state == DecoderState.endFrame);
    assert(codec.command == StompCommand.CONNECT);
    assert(codec.headersLine == "accept-version:1.2\nhost:127.0.0.1\n");
    assert(codec.bodyLine == "");
}
