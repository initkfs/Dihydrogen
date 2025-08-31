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

    void onAcceptEnd(ChannelContext ctx)
    {
        if (next)
        {
            next.onAcceptEnd(ctx);
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

    void onReadError(ChannelContext ctx)
    {
        if (next)
        {
            next.onReadError(ctx);
        }
    }

    void onWriteEnd(ChannelContext ctx)
    {
        if (next)
        {
            next.onWriteEnd(ctx);
        }
    }

    void onSpliceEnd(ChannelContext ctx)
    {
        if (next)
        {
            next.onSpliceEnd(ctx);
        }
    }

    void onCloseEnd(ChannelContext ctx)
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
