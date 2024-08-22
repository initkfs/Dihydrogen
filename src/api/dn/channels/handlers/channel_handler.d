module api.dn.channels.handlers.channel_handler;

import api.dn.channels.fd_channel : FdChannel, FdChannelType;

import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.contexts.channel_context : ChannelContext;

/**
 * Authors: initkfs
 */
class ChannelHandler
{
    ChannelHandler prev;
    ChannelHandler next;

    void delegate(ChanOutEvent) onOutEvent;

    void onAccepted(ChannelContext ctx)
    {
        if (next)
        {
            next.onAccepted(ctx);
        }
    }

    void onReadStart(ChannelContext ctx)
    {
        if (next)
        {
            next.onReadStart(ctx);
        }
    }

    void onReadEnd(ChannelContext ctx)
    {
        if (next)
        {
            next.onReadEnd(ctx);
        }
    }

    void onWrote(ChannelContext ctx)
    {
        if (next)
        {
            next.onWrote(ctx);
        }
    }

    void onClosed(ChannelContext ctx)
    {
        if (next)
        {
            next.onClosed(ctx);
        }
    }

    long timestamp()
    {
        import std.datetime;

        return Clock.currTime().toUnixTime;
    }

}
