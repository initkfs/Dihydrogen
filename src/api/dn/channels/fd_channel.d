module api.dn.channels.fd_channel;

import api.dn.net.sockets.socket_connect : SocketConnectState;
import api.dn.channels.fd_channel_buffers: InBuffer, OutBuffer;

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

    InBuffer inb;
    OutBuffer outb;
    bool isChain;

    void* data;

    import openssl_libs : SSL, BIO, SSL_shutdown, SSL_free;

    SSL* ssl;
    BIO* rbio;
    BIO* wbio;
    bool isInitSSL;

    void shutdownSSL()
    {
        if (ssl)
        {
            SSL_shutdown(ssl);
        }
    }

    void freeSSL()
    {
        if (ssl)
        {
            SSL_free(ssl);
        }
    }

    void resetFull()
    {
        fd = -1;
        type = FdChannelType.none;
        state = -1;
        
        outb.reset;
        inb.reset;

        ssl = null;
        resetPart;
    }

    void resetPart()
    {
        inb.resetBufferIndices;
        state = 0;
        data = null;
        isChain = false;
        isInitSSL = false;
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
