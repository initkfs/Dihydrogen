module app.dn.io.loops.endpointable_event_loop;

import app.dn.io.loops.eventable_event_loop : EventableEventLoop;
import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.events.routes.event_router : EventRouter;
import app.dn.channels.events.translators.event_translator : EventTranslator;
import app.dn.channels.events.monitors.event_monitor : EventMonitor;

import std.logger : Logger;

/**
 * Authors: initkfs
 */
class EndpointableEventLoop : EventableEventLoop
{
    EventRouter eventRouter;
    EventTranslator eventTranslator;
    EventMonitor eventMonitor;

    this(Logger logger, EventRouter router, EventTranslator translator = null, EventMonitor monitor = null)
    {
        super(logger);

        assert(router);
        eventRouter = router;
        this.eventTranslator = translator;
        this.eventMonitor = monitor;
    }

    override void create()
    {
        onInEvent = (chanInEvent) { eventRouter.routeInEvent(chanInEvent); };
        
        super.create;

        assert(eventRouter);
        eventRouter.onOutEvent = (outEvent) => sendOutEvent(outEvent);
        
    }
}
