module api.dn.events.monitors.event_monitor;

import api.core.loggers.logging : Logging;
import api.core.components.units.services.loggable_unit : LoggableUnit;
import api.dn.events.chan_events : ChanInEvent, ChanOutEvent;

/**
 * Authors: initkfs
 */
class EventMonitor : LoggableUnit
{

    this(Logging logging)
    {
        super(logging);
    }

    bool onInEvent(ChanInEvent inEvent) => false;
    bool onConvertedInEvent(ChanInEvent inEvent, ChanInEvent convertedInEvent) => false;
    bool onOutRouterEvent(ChanOutEvent inEvent) => false;
    bool onConvertedOutEvent(ChanOutEvent outEvent, ChanOutEvent convertedOutEvent) => false;
}
