module api.dn.events.chan_events;

import api.dn.chans.fd_chan : FdChan, FdChanType;

/**
 * Authors: initkfs
 */
struct ChanInEvent
{
    enum ChanInEventState
    {
        none,
        accepted,
        connect,
        readStart,
        readEnd,
        readError,
        wrote,
        spliced,
        closed,
    }

    FdChan* chan;
    ChanInEventState state;
}

struct ChanOutEvent
{
    enum ChanOutEventState
    {
        none,
        read,
        write,
        writezc,
        splice,
        close
    }

    FdChan* chan;
    ChanOutEventState state;
    bool isConsumed;

    void setRead()
    {
        state = ChanOutEventState.read;
    }

    void setWrite()
    {
        state = ChanOutEventState.write;
    }

    void setWriteZC()
    {
        state = ChanOutEventState.writezc;
    }

    void setSplice()
    {
        state = ChanOutEventState.splice;
    }

    void setClose()
    {
        state = ChanOutEventState.close;
    }
}
