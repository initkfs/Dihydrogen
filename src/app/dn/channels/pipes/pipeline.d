module app.dn.channels.pipes.pipeline;

import app.dn.channels.handlers.channel_handler : ChannelHandler;
import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import app.dn.channels.contexts.channel_context : ChannelContext;

/**
 * Authors: initkfs
 */
class Pipeline
{
    ChannelHandler first;

    void delegate(ChanOutEvent) onOutEvent;

    void onInEvent(ChanInEvent event)
    {
        switch (event.type) with (ChanInEvent.ChanInEventType)
        {
            case accepted:
                onAccept(event);
                break;
            case readed:
                onRead(event);
                break;
            case readedAll:
                onReadEnd(event);
                break;
            case writed:
                onWrite(event);
                break;
            case closed:
                onClose(event);
                break;
            default:
                break;
        }
    }

    void sendEvent(ChanOutEvent event)
    {
        assert(onOutEvent);
        onOutEvent(event);
    }

    protected void onHandler(scope bool delegate(ChannelHandler) onHandlerIsContinue)
    {
        assert(onOutEvent);

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

    void onAccept(ChanInEvent event)
    {
        onHandler((h) {
            h.onAccept(ChannelContext(this, event, ChanOutEvent(event.chan), onOutEvent));
            return true;
        });
    }

    void onRead(ChanInEvent event)
    {
        onHandler((h) {
            h.onRead(ChannelContext(this, event, ChanOutEvent(event.chan), onOutEvent));
            return true;
        });
    }

    void onReadEnd(ChanInEvent event)
    {
        onHandler((h) {
            h.onReadEnd(ChannelContext(this, event, ChanOutEvent(event.chan), onOutEvent));
            return true;
        });
    }

    void onWrite(ChanInEvent event)
    {
        onHandler((h) {
            h.onWrite(ChannelContext(this, event, ChanOutEvent(event.chan), onOutEvent));
            return true;
        });
    }

    void onClose(ChanInEvent event)
    {
        onHandler((h) {
            h.onClose(ChannelContext(this, event, ChanOutEvent(event.chan), onOutEvent));
            return true;
        });
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
