module api.dn.channels.events.monitors.event_monitor;

import api.core.loggers.logging: Logging;
import api.core.components.units.services.loggable_unit: LoggableUnit;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

/**
 * Authors: initkfs
 */
class EventMonitor : LoggableUnit {

    this(Logging logging){
        super(logging);
    }
    
    void onInEvent(ChanInEvent inEvent){

    }

    void onConvertedInEvent(ChanInEvent inEvent, ChanInEvent transEvent){

    }

    void onOutRouterEvent(ChanOutEvent inEvent){

    }

    void onConvertedOutEvent(ChanOutEvent outEvent, ChanOutEvent convOutEvent){

    }
}