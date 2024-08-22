module api.dn.channels.events.channel_events;

import api.dn.channels.fd_channel : FdChannel, FdChannelType;

/**
 * Authors: initkfs
 */
struct ChanInEvent
{
    enum ChanInEventType
    {
        none,
        accepted,
        readStart,
        readedEnd,
        wrote,
        closed,
    }

    FdChannel* chan;
    ChanInEventType type;
}

struct ChanOutEvent
{
    enum ChanOutEventType
    {
        none,
        read,
        write,
        close
    }

    FdChannel* chan;
    ChanOutEventType type;
    ubyte[] buffer;
    bool isConsumed;

    void setRead()
    {
        type = ChanOutEventType.read;
    }

    void setWrite()
    {
        type = ChanOutEventType.write;
    }

    void setClose()
    {
        type = ChanOutEventType.close;
    }
}
