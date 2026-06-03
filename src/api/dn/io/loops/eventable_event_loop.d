module api.dn.io.loops.eventable_event_loop;

import api.dn.io.loops.event_loop : EventLoop;
import api.dn.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.fd_channel : FdChannel, FdChannelType;

import api.core.loggers.logging : Logging;

/**
 * Authors: initkfs
 */
class EventableEventLoop : EventLoop
{
    bool delegate(ChanInEvent) onInEvent;
    bool delegate(ChanOutEvent) onOutEvent;

    this(Logging logger)
    {
        super(logger);
    }

    override void create()
    {
        onAcceptEnd = (conn) => sendNewInEvent(conn, ChanInEvent.ChanInEventState.accepted);
        onReadStart = (conn) => sendNewInEvent(conn, ChanInEvent.ChanInEventState.readStart);
        onReadEnd = (conn) => sendNewInEvent(conn, ChanInEvent.ChanInEventState.readEnd);
        onReadError = (conn) => sendNewInEvent(conn, ChanInEvent.ChanInEventState.readError);
        onWriteEnd = (conn) => sendNewInEvent(conn, ChanInEvent.ChanInEventState.wrote);
        onSpliceEnd = (conn) => sendNewInEvent(conn, ChanInEvent.ChanInEventState.wrote);
        onCloseEnd = (conn) => sendNewInEvent(conn, ChanInEvent.ChanInEventState.closed);

        super.create;
    }

    ChanInEvent newChanInEvent(FdChannel* conn, ChanInEvent.ChanInEventState state) => ChanInEvent(conn, state);

    void sendNewInEvent(FdChannel* conn, ChanInEvent.ChanInEventState state)
    {
        sendInEvent(newChanInEvent(conn, state));
    }

    bool sendInEvent(ChanInEvent inEvent)
    {
        if (onInEvent)
        {
            return onInEvent(inEvent);
        }

        return false;
    }

    bool sendOutEvent(ChanOutEvent event)
    {
        bool isSend;
        if (onOutEvent)
        {
            isSend |= onOutEvent(event);
        }

        if (event.isConsumed)
        {
            return isSend;
        }

        switch (event.state) with (ChanOutEvent.ChanOutEventState)
        {
            case read:
                addSocketReadv(&ring, event.chan);
                break;
            case write:
                addSocketWrite(&ring, event.chan, event.chan.outb.buff.ptr, event.chan.outb.length);
                break;
            case writezc:
                addSocketWriteZC(&ring, event.chan, event.chan.outb.buff.ptr, event.chan.outb.length);
                break;
            case close:
                addSocketClose(&ring, event.chan);
                break;
            case splice:
                addSocketSplice(&ring, event.chan);
                break;
            default:
                break;
        }

        return true;
    }

}
