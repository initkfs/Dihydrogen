module app.dn.channels.events.monitors.event_monitor;

import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

/**
 * Authors: initkfs
 */
class EventMonitor {
    
    void onInEvent(ChanInEvent inEvent){

    }

    void onTranslatedInEvent(ChanInEvent inEvent, ChanInEvent transEvent){

    }

    void onOutRouterEvent(ChanOutEvent inEvent){

    }

    void onTranslatedOutEvent(ChanOutEvent outEvent, ChanOutEvent transOutEvent){

    }
}