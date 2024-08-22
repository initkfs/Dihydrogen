module api.dn.channels.events.routes.event_router;

import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

/**
 * Authors: initkfs
 */

abstract class EventRouter
{
    void delegate(ChanOutEvent) onOutEvent;

    void routeInEvent(ChanInEvent eventIn);
    void routeOutEvent(ChanOutEvent eventOut);
}
