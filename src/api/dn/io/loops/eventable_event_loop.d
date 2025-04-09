module api.dn.io.loops.eventable_event_loop;

import api.dn.io.loops.event_loop : EventLoop;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.fd_channel : FdChannel, FdChannelType;

import api.core.loggers.logging : Logging;

/**
 * Authors: initkfs
 */
class EventableEventLoop : EventLoop
{
    void delegate(ChanInEvent) onInEvent;
    void delegate(ChanOutEvent) onOutEvent;

    this(Logging logger)
    {
        super(logger);
    }

    override void create()
    {
        onAcceptEnd = (conn) => sendNewInEvent(conn, ChanInEvent.ChanInEventState.accepted);
        onReadStart = (conn) => sendNewInEvent(conn, ChanInEvent.ChanInEventState.readStart);
        onReadEnd = (conn) => sendNewInEvent(conn, ChanInEvent.ChanInEventState.readEnd);
        onWriteEnd = (conn) => sendNewInEvent(conn, ChanInEvent.ChanInEventState.wrote);
        onCloseEnd = (conn) => sendNewInEvent(conn, ChanInEvent.ChanInEventState.closed);

        super.create;
    }

    ChanInEvent newChanInEvent(FdChannel* conn, ChanInEvent.ChanInEventState state) => ChanInEvent(conn, state);

    void sendNewInEvent(FdChannel* conn, ChanInEvent.ChanInEventState state)
    {
        sendInEvent(newChanInEvent(conn, state));
    }

    void sendInEvent(ChanInEvent inEvent)
    {
        if (onInEvent)
        {
            onInEvent(inEvent);
        }
    }

    void sendOutEvent(ChanOutEvent event)
    {
        if (onOutEvent)
        {
            onOutEvent(event);
        }

        if (event.isConsumed)
        {
            return;
        }

        switch (event.state) with (ChanOutEvent.ChanOutEventState)
        {
            case read:
                addSocketReadv(&ring, event.chan);
                break;
            case write:
                addSocketWrite(&ring, event.chan, event.buffer.ptr, event.buffer.length);
                break;
            case close:
                addSocketClose(&ring, event.chan);
                break;
            default:
                break;
        }
    }

}
