module app.dn.channels.events.monitors.log_event_monitor;

import app.dn.channels.events.monitors.event_monitor : EventMonitor;
import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

import std.logger : Logger;

/**
 * Authors: initkfs
 */
class LogEventMonitor : EventMonitor
{
    protected
    {
        Logger logger;
    }
    this(Logger logger)
    {
        assert(logger);
        this.logger = logger;
    }

    //TODO best implementation
    private dstring escape(dstring str)
    {
        import std;

        dstring s = str.chunks(1).map!(c =>
                (c == "\n") ? "\\n" : (c == "\r") ? "\\r" : (c == "\t") ? "\\t" : c)
            .joiner.array;
        return s;
    }

    override void onInEvent(ChanInEvent inEvent)
    {
        if (inEvent.type == ChanInEvent.ChanInEventType.readed)
        {
            import std.conv : to;

            dstring buffStr = (cast(string) inEvent
                .chan.buff[0 .. (
                        inEvent.chan.availableBytes)]).to!dstring;
            logger.tracef("%s:%s, %s, buff:%s", typeof(inEvent).stringof, inEvent.chan.fd, inEvent.type, escape(
                    buffStr));
            return;
        }

        logger.tracef("%s:%s, %s", typeof(inEvent).stringof, inEvent.chan.fd, inEvent.type);
    }

    override void onOutRouterEvent(ChanOutEvent outEvent)
    {
        if (outEvent.type == ChanOutEvent.ChanOutEventType.write)
        {
            import std.conv: to;
            //TODO utf, remove unsafe cast
            dstring buffStr = (cast(string)outEvent
                .buff[0 .. outEvent.buffLen]).to!dstring;
            logger.tracef("%s:%s, %s, buff:%s", typeof(outEvent).stringof, outEvent.chan.fd, outEvent.type, escape(
                    buffStr));
            return;
        }

        logger.tracef("%s:%s, %s", typeof(outEvent).stringof, outEvent.chan.fd, outEvent.type);
    }
}
