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

    override void onInEvent(ChanInEvent inEvent)
    {
        if (inEvent.type == ChanInEvent.ChanInEventType.readed)
        {
            logger.tracef("IN. fd:%s, type:%s, buff:%s", inEvent.chan.fd, inEvent.type, cast(string) inEvent.chan.buff[0 .. (
                    inEvent.chan.availableBytes)]);
            return;
        }

        logger.tracef("IN. fd:%s, type: %s", inEvent.chan.fd, inEvent.type);
    }

    override void onOutRouterEvent(ChanOutEvent outEvent)
    {
        if (outEvent.type == ChanOutEvent.ChanOutEventType.write)
        {
            logger.tracef("OUT. fd:%s, type:%s, buff:%s", outEvent.chan.fd, outEvent.type, cast(string) outEvent
                    .buff[0 .. outEvent.buffLen]);
            return;
        }

        logger.tracef("OUT. fd:%s, type:%s", outEvent.chan.fd, outEvent.type);
    }
}
