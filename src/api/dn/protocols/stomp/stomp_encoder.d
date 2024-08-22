module api.dn.protocols.stomp.stomp_encoder;

import api.core.mem.buffers.static_buffer : StaticBuffer;

import api.dn.protocols.stomp.stomp_common;

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

    StaticStompFrame connected(){
        auto newFrame = frame;
        addCONNECTED(newFrame);
        addDefaultVersion(newFrame);
        return newFrame;
    }

    StaticStompFrame disconnect(){
        auto newFrame = frame;
        addDISCONNECT(newFrame);
        addDefaultVersion(newFrame);
        return newFrame;
    }

    StaticStompFrame message(
        const(char)[] content = "message",
        const(char)[] dest = "/", 
        const(char)[] messageId = "0", 
        const(char)[] subscription = "0"){
        auto newFrame = frame;
        addMESSAGE(newFrame);
        addDefaultVersion(newFrame);
        addDestination(newFrame, dest);
        addMessageId(newFrame, messageId);
        addSubscription(newFrame, subscription);
        addBody(newFrame, cast(const(ubyte[])) content);
        return newFrame;
    }

    StaticStompFrame receipt(const(char)[] receiptId){
        auto newFrame = frame;
        addRECEIPT(newFrame);
        addReceiptId(newFrame, receiptId);
        return newFrame;
    }

    StaticStompFrame error(const(char)[] message){
        auto newFrame = frame;
        addERROR(newFrame);
        addDefaultVersion(newFrame);
        addContentType(newFrame, "text/plain");
        addContentLength(newFrame, message.length);
        addBody(newFrame, cast(const(ubyte)[]) message);
        return newFrame;
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

    StompEncoder addDestination(ref StaticStompFrame frame, const(char)[] destination) => addHeader(frame, StompDefaultHeader
            .destination, destination);

    StompEncoder addReceiptId(ref StaticStompFrame frame, const(char)[] destination) => addHeader(frame, StompDefaultHeader
            .receiptID, destination);

     StompEncoder addSubscription(ref StaticStompFrame frame, const(char)[] subscription) => addHeader(frame, StompDefaultHeader
            .subscription, subscription);

    StompEncoder addTransaction(ref StaticStompFrame frame, const(char)[] transactionId) => addHeader(frame, StompDefaultHeader
            .transaction, transactionId);

    StompEncoder addMessageId(ref StaticStompFrame frame, const(char)[] messageId) => addHeader(frame, StompDefaultHeader
            .messageID, messageId);

    StompEncoder addBody(ref StaticStompFrame frame, const(ubyte)[] content){
        frame.content.reset;
        frame.content ~= content;
        return this;
    }

    void decode(size_t BufferLength, char lf = StompControlСhar.lf)(ref StaticStompFrame frame, ref StaticBuffer!(char, BufferLength, true) buffer)
    {
        buffer ~= frame.command;
        //buffer ~= " ";
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
            //TODO ubyte -> char
            buffer ~= cast(char[]) frame.content;
        }

        buffer ~= StompControlСhar.nul;
    }

    size_t headerValueLength() const @nogc nothrow pure @safe => HeaderValueLen;
    size_t headerNameLength() const @nogc nothrow pure @safe => HeaderNameLen;
}

unittest
{
    auto encoder = newStompEncoder;
    auto frame = encoder.frame;
    encoder.addCONNECT(frame);
    encoder.addDefaultVersion(frame);

    import api.core.mem.buffers.static_buffer: StaticBuffer;

    StaticBuffer!(char, 256) buff;
    encoder.decode!(256, '|')(frame, buff);

    assert(buff[] == "CONNECT|version:1.2||\0");
}
