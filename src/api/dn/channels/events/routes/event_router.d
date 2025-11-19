module api.dn.channels.events.routes.event_router;

import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

/**
 * Authors: initkfs
 */

abstract class EventRouter
{
    bool delegate(ChanOutEvent) onOutEvent;

    bool routeInEvent(ChanInEvent eventIn);
    bool routeOutEvent(ChanOutEvent eventOut);
}
