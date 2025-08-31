module api.dn.channels.events.channel_events;

import api.dn.channels.fd_channel : FdChannel, FdChannelType;

/**
 * Authors: initkfs
 */
struct ChanInEvent
{
    enum ChanInEventState
    {
        none,
        accepted,
        readStart,
        readEnd,
        readError,
        wrote,
        spliced,
        closed,
    }

    FdChannel* chan;
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

    FdChannel* chan;
    ChanOutEventState state;
    ubyte[] buffer;
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
