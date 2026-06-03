module api.dn.handlers.channel_handler;

import api.dn.chans.fd_chan : FdChan, FdChanType;

import api.dn.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.chans.chan_context : ChanContext;

/**
 * Authors: initkfs
 */
class ChannelHandler
{
    ChannelHandler prev;
    ChannelHandler next;

    void delegate(ChanOutEvent) onOutEvent;

    void onConnect(ChanContext ctx)
    {
        if (next)
        {
            next.onConnect(ctx);
        }
    }

    void onAcceptEnd(ChanContext ctx)
    {
        if (next)
        {
            next.onAcceptEnd(ctx);
        }
    }

    void onReadStart(ChanContext ctx)
    {
        if (next)
        {
            next.onReadStart(ctx);
        }
    }

    void onReadEnd(ChanContext ctx)
    {
        if (next)
        {
            next.onReadEnd(ctx);
        }
    }

    void onReadError(ChanContext ctx)
    {
        if (next)
        {
            next.onReadError(ctx);
        }
    }

    void onWriteEnd(ChanContext ctx)
    {
        if (next)
        {
            next.onWriteEnd(ctx);
        }
    }

    void onSpliceEnd(ChanContext ctx)
    {
        if (next)
        {
            next.onSpliceEnd(ctx);
        }
    }

    void onCloseEnd(ChanContext ctx)
    {
        if (next)
        {
            next.onCloseEnd(ctx);
        }
    }

    long timestamp()
    {
        import std.datetime;

        return Clock.currTime().toUnixTime;
    }

}
