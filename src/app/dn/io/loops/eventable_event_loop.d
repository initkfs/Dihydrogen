module app.dn.io.loops.eventable_event_loop;

import app.dn.io.loops.event_loop : EventLoop;
import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import std.logger : Logger;

/**
 * Authors: initkfs
 */
class EventableEventLoop : EventLoop
{

    void delegate(ChanInEvent) onInEvent;

    this(Logger logger)
    {
        super(logger);
    }

    override void create()
    {
        onAccepted = (conn) => sendInEvent(conn, ChanInEvent.ChanInEventType.accepted);
        onReadStart = (conn) => sendInEvent(conn, ChanInEvent.ChanInEventType.readStart);
        onReadEnd = (conn) => sendInEvent(conn, ChanInEvent.ChanInEventType.readedEnd);
        onWrote = (conn) => sendInEvent(conn, ChanInEvent.ChanInEventType.wrote);
        onClosed = (conn) => sendInEvent(conn, ChanInEvent.ChanInEventType.closed);

        super.create;

        assert(onInEvent);
    }

    private void sendInEvent(FdChannel* conn, ChanInEvent.ChanInEventType type)
    {
        onInEvent(ChanInEvent(conn, type));
    }

    void sendOutEvent(ChanOutEvent event)
    {
        if (event.isConsumed)
        {
            return;
        }

        switch (event.type) with (ChanOutEvent.ChanOutEventType)
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
