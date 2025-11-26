module api.dn.channels.fd_channel;

import api.dn.net.sockets.socket_connect : SocketConnectState;
import api.dn.channels.fd_channel_buffers : InBuffer, OutBuffer;

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

struct SSLContext
{
    import openssl_libs : SSL, BIO, SSL_shutdown, SSL_free, BIO_reset, SSL_clear;

    SSL* ssl;
    BIO* rbio;
    BIO* wbio;
    bool isInitSSL;
    bool isOpen;

    void clear()
    {
        ssl = null;
        rbio = null;
        wbio = null;
        isInitSSL = false;
        isOpen = false;
    }

    void shutdown()
    {
        if (ssl)
        {
            SSL_shutdown(ssl);
        }
    }

    void close()
    {
        if (!isOpen && !isInitSSL)
        {
            return;
        }

        if (ssl)
        {
            SSL_clear(ssl);
        }

        resetbio;
        isOpen = false;
        isInitSSL = false;
    }

    void resetbio()
    {
        if (rbio)
        {
            BIO_reset(rbio);
        }

        if (wbio)
        {
            BIO_reset(wbio);
        }
    }

    void freeSSL()
    {
        if (ssl)
        {
            SSL_free(ssl);
            ssl = null;
        }
    }

    void reset()
    {
        if (ssl)
        {
            //TODO errror code == -1
            SSL_clear(ssl);
        }

        resetbio;
        isOpen = false;
        isInitSSL = false;


    }
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

    SSLContext sslContext;

    void* data;

    void clear(){
        fd = -1;
        type = FdChannelType.none;
        state = -1;
        stateNext = -1;

        outb.reset;
        inb.reset;

        sslContext = SSLContext();
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
