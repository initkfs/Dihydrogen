module api.dn.channels.fd_channel;

import api.dn.net.sockets.socket_connect : SocketConnectState;

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
    ubyte[] buff;
    size_t readIndex;
    size_t writeIndex;
    bool isChain;
    bool isText;
    void* data;

    import openssl_libs : SSL, BIO, SSL_shutdown, SSL_free;

    SSL* ssl;
    BIO* rbio;
    BIO* wbio;
    bool isInitSSL;

    void shutdownSSL()
    {
        if(ssl){
            SSL_shutdown(ssl);
        }
    }

    void freeSSL(){
        if(ssl){
            SSL_free(ssl);
        }
    }

    void resetFull()
    {
        fd = -1;
        type = FdChannelType.none;
        state = -1;
        buff = null;
        ssl = null;
        resetPart;
    }

    void resetPart()
    {
        resetBufferIndices;
        state = 0;
        data = null;
        isChain = false;
        isInitSSL = false;
        isText = false;
    }

    bool incRead(size_t offset = 1) @nogc nothrow @safe
    {
        size_t newIndex = readIndex + offset;
        if (newIndex >= buff.length)
        {
            return false;
        }
        readIndex = newIndex;
        return true;
    }

    bool incMaxRead() @nogc nothrow @safe
    {
        if (buff.length == 0)
        {
            return false;
        }
        readIndex = buff.length - 1;
        return true;
    }

    bool incWrite(size_t offset = 1) @nogc nothrow @safe
    {
        size_t newIndex = writeIndex + offset;
        if (newIndex >= buff.length)
        {
            return false;
        }
        writeIndex = newIndex;
        return true;
    }

    bool incMaxWrite() @nogc nothrow @safe
    {
        if (buff.length == 0)
        {
            return false;
        }
        writeIndex = buff.length - 1;
        return true;
    }

    ubyte[] readableBytes()
    {
        return buff[0 .. readIndex];
    }

    ubyte[] writableBytes()
    {
        return buff[writeIndex .. $];
    }

    void resetBufferRead()
    {
        readIndex = 0;
    }

    void resetBufferWrite()
    {
        writeIndex = 0;
    }

    void resetBufferIndices()
    {
        readIndex = 0;
        writeIndex = 0;
    }

    string toSimpleString() const
    {
        import std.format : format;

        return format("[%s:%s]", typeof(this).stringof, fd);
    }
}
