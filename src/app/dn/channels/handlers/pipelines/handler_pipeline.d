module app.dn.channels.handlers.pipelines.handler_pipeline;

import app.dn.channels.handlers.channel_handler : ChannelHandler;
import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import app.dn.channels.contexts.channel_context : ChannelContext;

/**
 * Authors: initkfs
 */
class HandlerPipeline
{
    ChannelHandler first;

    protected
    {
        void delegate(ChanOutEvent) _onOutEvent;
    }

    void onInEvent(ChanInEvent event)
    {
        switch (event.type) with (ChanInEvent.ChanInEventType)
        {
            case accepted:
                onAccepted(event);
                break;
            case readStart:
                onReadStart(event);
                break;
            case readedEnd:
                onReadEnd(event);
                break;
            case wrote:
                onWrote(event);
                break;
            case closed:
                onClosed(event);
                break;
            default:
                break;
        }
    }

    void sendEvent(ChanOutEvent event)
    {
        assert(_onOutEvent);
        _onOutEvent(event);
    }

    protected void onHandler(scope bool delegate(ChannelHandler) onHandlerIsContinue)
    {
        assert(_onOutEvent);

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

    void onAccepted(ChanInEvent event)
    {
        onHandler((h) {
            h.onAccepted(ChannelContext(this, event, ChanOutEvent(event.chan), _onOutEvent));
            return true;
        });
    }

    void onReadStart(ChanInEvent event)
    {
        onHandler((h) {
            h.onReadStart(ChannelContext(this, event, ChanOutEvent(event.chan), _onOutEvent));
            return true;
        });
    }

    void onReadEnd(ChanInEvent event)
    {
        onHandler((h) {
            h.onReadEnd(ChannelContext(this, event, ChanOutEvent(event.chan), _onOutEvent));
            return true;
        });
    }

    void onWrote(ChanInEvent event)
    {
        onHandler((h) {
            h.onWrote(ChannelContext(this, event, ChanOutEvent(event.chan), _onOutEvent));
            return true;
        });
    }

    void onClosed(ChanInEvent event)
    {
        onHandler((h) {
            h.onClosed(ChannelContext(this, event, ChanOutEvent(event.chan), _onOutEvent));
            return true;
        });
    }

    bool add(ChannelHandler handler)
    {
        if (_onOutEvent)
        {
            handler.onOutEvent = _onOutEvent;
        }

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

    void onOutEvent(void delegate(ChanOutEvent) dg)
    {
        _onOutEvent = dg;
        auto currHandler = first;
        while (currHandler)
        {
            currHandler.onOutEvent = dg;
            currHandler = currHandler.next;
        }
    }

}
