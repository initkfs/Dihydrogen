module app.dn.protocols.stomp.stomp_encoder;

import app.core.mem.static_buffer : StaticBuffer;

import app.dn.protocols.stomp.stomp_common;

auto newStompEncoder(
    size_t HeadersCount = 10,
    size_t HeaderNameLen = StompBufferLength,
    size_t HeaderValueLen = StompBufferLength,
    size_t BodyLength = StompBufferLength
)()
{
    return new StompEncoder!(HeadersCount, HeaderNameLen, HeaderValueLen, BodyLength);
}

/**
 * Authors: initkfs
 */
class StompEncoder(
    size_t HeadersCount,
    size_t HeaderNameLen,
    size_t HeaderValueLen,
    size_t BodyLength)
{
    alias StaticStompFrame = StompFrame!(HeadersCount, HeaderNameLen, HeaderValueLen, BodyLength);

    StaticStompFrame frame()
    {
        return StompFrame!(HeadersCount, HeaderNameLen, HeaderValueLen, BodyLength)();
    }

    StompEncoder addCommand(ref StaticStompFrame frame, StompCommand command)
    {
        frame.command = command;
        return this;
    }

    import std.traits : EnumMembers;

    static foreach (i, commandName; EnumMembers!StompCommand)
    {
        //TODO replace with interpolations
        import std.format : format;

        mixin(format("StompEncoder add%s(ref StaticStompFrame frame) => addCommand(frame,%s.%s);", commandName, __traits(
                identifier, StompCommand), commandName));
    }

    StompEncoder addHeader(ref StaticStompFrame frame, const(char)[] name, const(char)[] value)
    {
        StompHeader!(char, HeaderNameLen, HeaderValueLen) header;
        header.name ~= name;
        header.value ~= value;

        if (!frame.headers.append(header))
        {
            throw new Exception("Stomp headers overflow");
        }
        return this;
    }

    StompEncoder addContentLength(ref StaticStompFrame frame, size_t len)
    {
        //TODO static buffer;
        import std.conv : to;

        return addHeader(frame, StompDefaultHeader.contentLength, len.to!string);
    }

    StompEncoder addContentType(ref StaticStompFrame frame, const(char)[] contentType) => addHeader(frame, StompDefaultHeader
            .contentType, contentType);

    StompEncoder addDefaultVersion(ref StaticStompFrame frame) => addHeader(frame, StompDefaultHeader.ver, StompVersion
            .current);

    StompEncoder addDestination(ref StaticStompFrame frame, const(char[]) destination) => addHeader(frame, StompDefaultHeader
            .destination, destination);

    StompEncoder addTransaction(ref StaticStompFrame frame, const(char[]) transactionId) => addHeader(frame, StompDefaultHeader
            .transaction, transactionId);

    StompEncoder addMessageId(ref StaticStompFrame frame, const(char[]) messageId) => addHeader(frame, StompDefaultHeader
            .messageID, messageId);

    void decode(T, size_t BufferLength, char lf = StompControlСhar.lf)(ref StaticStompFrame frame, ref StaticBuffer!(T, BufferLength, true) buffer)
    {
        buffer ~= frame.command;
        buffer ~= " ";
        buffer ~= lf;
        foreach(i; 0..(frame.headers.length))
        {
            buffer ~= (frame.headers[i]).name[];
            buffer ~= ":";
            buffer ~= (frame.headers[i]).value[];
            buffer ~= lf;
        }

        buffer ~= lf;

        if(frame.content.length > 0){
            buffer ~= frame.content[];
        }

        buffer ~= StompControlСhar.nul;
    }
}

unittest
{
    auto encoder = newStompEncoder;
    auto frame = encoder.frame;
    encoder.addCONNECT(frame);
    encoder.addDefaultVersion(frame);

    import app.core.mem.static_buffer: StaticBuffer;

    StaticBuffer!(char, 256) buff;
    encoder.decode!(char, 256, '|')(frame, buff);

    assert(buff[] == "CONNECT |version:1.2||\0");
}
