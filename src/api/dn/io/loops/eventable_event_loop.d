module api.dn.io.loops.eventable_event_loop;

import api.dn.io.loops.event_loop : EventLoop;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.fd_channel : FdChannel, FdChannelType;

import api.core.loggers.logging: Logging;

/**
 * Authors: initkfs
 */
class EventableEventLoop : EventLoop
{

    void delegate(ChanInEvent) onInEvent;

    this(Logging logger)
    {
        super(logger);
    }

    override void create()
    {
        onAccepted = (conn) => sendInEvent(conn, ChanInEvent.ChanInEventState.accepted);
        onReadStart = (conn) => sendInEvent(conn, ChanInEvent.ChanInEventState.readStart);
        onReadEnd = (conn) => sendInEvent(conn, ChanInEvent.ChanInEventState.readEnd);
        onWrote = (conn) => sendInEvent(conn, ChanInEvent.ChanInEventState.wrote);
        onClosed = (conn) => sendInEvent(conn, ChanInEvent.ChanInEventState.closed);

        super.create;

        assert(onInEvent);
    }

    private void sendInEvent(FdChannel* conn, ChanInEvent.ChanInEventState state)
    {
        onInEvent(ChanInEvent(conn, state));
    }

    void sendOutEvent(ChanOutEvent event)
    {
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
