module api.dn.chans.fd_chan;

import api.dn.sockets.socket_connect : SocketConnectState;
import api.dn.chans.chan_buffers : InBuffer, OutBuffer;
import api.dn.chans.chan_ssl_context : ChanSSLContext;

/**
 * Authors: initkfs
 */
enum FdChanType
{
    none,
    socket,
    timer,
    file,
    control,
}

struct FdChan
{
    enum invalidValue = -1;

    int fd = invalidValue;
    FdChanType type;
    int state = invalidValue;
    int stateNext = invalidValue;

    InBuffer inb;
    OutBuffer outb;
    bool isChain;

    ChanSSLContext sslContext;

    void* data;

    void clear()
    {
        this = FdChan.init;
    }

    void start()
    {
        sslContext.isOpen = true;
    }

    void reset()
    {
        inb.resetBufferIndices;
        state = invalidValue;
        stateNext = invalidValue;
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

    static FdChan* newChan()
    {
        import core.stdc.stdlib : malloc;

        FdChan* chan = cast(FdChan*) malloc(FdChan.sizeof);
        if (!chan)
        {
            throw new Error("Chan not allocated");
        }
        chan.clear;
        return chan;
    }

    static freeChan(FdChan* chan)
    {
        import core.stdc.stdlib : free;

        chan.inb.dispose;
        chan.outb.dispose;

        free(chan);
    }
}
