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
    int fd;
    FdChanType type;
    int state;
    int stateNext;

    InBuffer inb;
    OutBuffer outb;
    bool isChain;

    ChanSSLContext sslContext;

    void* data;

    void clear()
    {
        fd = -1;
        type = FdChanType.none;
        state = -1;
        stateNext = -1;

        outb.reset;
        inb.reset;

        sslContext = ChanSSLContext();
        resetPart;
    }

    void resetFull()
    {
        fd = -1;
        type = FdChanType.none;
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

    static FdChan* newChanClear()
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

        free(chan);
    }
}
