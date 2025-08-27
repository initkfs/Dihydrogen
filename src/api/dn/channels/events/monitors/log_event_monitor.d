module api.dn.channels.events.monitors.log_event_monitor;

import api.dn.channels.events.monitors.event_monitor : EventMonitor;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

import api.core.loggers.logging: Logging;

/**
 * Authors: initkfs
 */
class LogEventMonitor : EventMonitor
{
    
    this(Logging logging)
    {
        super(logging);
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
        if (inEvent.state == ChanInEvent.ChanInEventState.readStart)
        {
            import std.conv : to;

            dstring buffStr = (cast(string) inEvent
                    .chan.readableBytes).to!dstring;
            logger.tracef("%s:%s, %s, buff:%s", typeof(inEvent).stringof, inEvent.chan.fd, inEvent.state, escape(
                    buffStr));
            return;
        }

        logger.tracef("%s:%s, %s", typeof(inEvent).stringof, inEvent.chan.fd, inEvent.state);
    }

    override void onOutRouterEvent(ChanOutEvent outEvent)
    {
        if (outEvent.state == ChanOutEvent.ChanOutEventState.write)
        {
            import std.conv : to;

            //TODO utf, remove unsafe cast
            // dstring buffStr = (cast(string) outEvent.buffer).to!dstring;
            // logger.tracef("%s:%s, %s, buff:%s", typeof(outEvent).stringof, outEvent.chan.fd, outEvent.state, escape(
            //         buffStr));
            return;
        }

        logger.tracef("%s:%s, %s", typeof(outEvent).stringof, outEvent.chan.fd, outEvent.state);
    }
}
