module app.dn.channels.pipes.pipleline;

import app.dn.channels.handlers.channel_handler : ChannelHandler;
import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.contexts.channel_context : ChannelContext;

/**
 * Authors: initkfs
 */
class Pipeline
{
    ChannelHandler first;

    protected void onHandler(scope bool delegate(ChannelHandler) onHandlerIsContinue)
    {
        ChannelHandler curr = first;
        while (curr)
        {
            if (!onHandlerIsContinue(curr))
            {
                break;
            }

            curr = curr.next;
        }
    }

    ChannelContext onAccept(FdChannel* chan)
    {
        ChannelContext ctx = ChannelContext(this, chan);
        onHandler((h) { h.onAccept(ctx); return true; });
        return ctx;
    }

    ChannelContext onRead(FdChannel* chan)
    {
        ChannelContext ctx = ChannelContext(this, chan);
        onHandler((h) { h.onRead(ctx); return true; });
        return ctx;
    }

    ChannelContext onReadEnd(FdChannel* chan)
    {
        ChannelContext ctx = ChannelContext(this, chan);
        onHandler((h) { h.onReadComplete(ctx); return true; });
        return ctx;
    }

    void onClose(FdChannel* chan)
    {
        ChannelContext ctx = ChannelContext(this, chan);
        onHandler((h) { h.onClose(ctx); return true; });
    }

    ChannelContext onWrite(FdChannel* chan)
    {
        ChannelContext ctx = ChannelContext(this, chan);
        onHandler((h) { h.onWrite(ctx); return true; });
        return ctx;
    }

    bool add(ChannelHandler handler)
    {
        if (!first)
        {
            first = handler;
            return true;
        }

        assert(first != handler);

        first.next = handler;
        handler.prev = first;

        return true;
    }

}
