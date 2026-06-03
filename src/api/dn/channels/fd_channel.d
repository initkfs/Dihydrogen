module api.dn.channels.fd_channel;

import api.dn.sockets.socket_connect : SocketConnectState;
import api.dn.channels.fd_channel_buffers : InBuffer, OutBuffer;
import api.dn.channels.channel_ssl_context: ChannelSSLContext;

/**
 * Authors: initkfs
 */
enum FdChannelType
{
    none,
    socket,
    timer,
    file
}

struct FdChannel
{
    int fd;
    FdChannelType type;
    int state;
    int stateNext;

    InBuffer inb;
    OutBuffer outb;
    bool isChain;

    ChannelSSLContext sslContext;

    void* data;

    void clear(){
        fd = -1;
        type = FdChannelType.none;
        state = -1;
        stateNext = -1;

        outb.reset;
        inb.reset;

        sslContext = ChannelSSLContext();
        resetPart;
    }

    void resetFull()
    {
        fd = -1;
        type = FdChannelType.none;
        state = -1;
        stateNext = -1;

        outb.reset;
        inb.reset;

        sslContext.reset;
        resetPart;
    }

    void start()
    {
        sslContext.isOpen = true;
    }

    void resetPart()
    {
        inb.resetBufferIndices;
        state = -1;
        stateNext = -1;
        data = null;
        isChain = false;
        sslContext.isInitSSL = false;

        sslContext.resetbio;
    }

    ubyte[] readableBytes() => inb.readableBytes;
    ubyte[] writableBytes() => inb.writableBytes;

    void resetBufferRead()
    {
        inb.resetBufferRead;
    }

    void resetBufferWrite()
    {
        inb.resetBufferWrite;
    }

    void resetBufferIndices()
    {
        inb.resetBufferIndices;
    }

    string toSimpleString() const
    {
        import std.format : format;

        return format("[%s:%s]", typeof(this).stringof, fd);
    }
}
