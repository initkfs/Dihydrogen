module api.dn.pipelines.handler_pipeline;

import api.dn.handlers.channel_handler : ChannelHandler;
import api.dn.channels.fd_channel : FdChannel, FdChannelType;

import api.dn.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.channel_context : ChannelContext;

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

    bool onInEvent(ChanInEvent event)
    {
        switch (event.state) with (ChanInEvent.ChanInEventState)
        {
            case accepted:
                onAcceptEnd(event);
                break;
            case connect:
                onConnect(event);
                break;
            case readStart:
                onReadStart(event);
                break;
            case readEnd:
                onReadEnd(event);
                break;
            case wrote:
                onWriteEnd(event);
                break;
            case spliced:
                onSpliceEnd(event);
                break;
            case closed:
                onCloseEnd(event);
                break;
            default:
                break;
        }

        return true;
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

    void onConnect(ChanInEvent event)
    {
        onHandler((h) {
            h.onConnect(ChannelContext(this, event, ChanOutEvent(event.chan), _onOutEvent));
            return true;
        });
    }

    void onAcceptEnd(ChanInEvent event)
    {
        onHandler((h) {
            h.onAcceptEnd(ChannelContext(this, event, ChanOutEvent(event.chan), _onOutEvent));
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

    void onReadError(ChanInEvent event)
    {
        onHandler((h) {
            h.onReadError(ChannelContext(this, event, ChanOutEvent(event.chan), _onOutEvent));
            return true;
        });
    }

    void onWriteEnd(ChanInEvent event)
    {
        onHandler((h) {
            h.onWriteEnd(ChannelContext(this, event, ChanOutEvent(event.chan), _onOutEvent));
            return true;
        });
    }

    void onSpliceEnd(ChanInEvent event)
    {
        onHandler((h) {
            h.onSpliceEnd(ChannelContext(this, event, ChanOutEvent(event.chan), _onOutEvent));
            return true;
        });
    }

    void onCloseEnd(ChanInEvent event)
    {
        onHandler((h) {
            h.onCloseEnd(ChannelContext(this, event, ChanOutEvent(event.chan), _onOutEvent));
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
