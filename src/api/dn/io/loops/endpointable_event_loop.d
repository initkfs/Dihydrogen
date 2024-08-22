module api.dn.io.loops.endpointable_event_loop;

import api.dn.io.loops.eventable_event_loop : EventableEventLoop;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.fd_channel : FdChannel, FdChannelType;

import api.dn.channels.events.routes.event_router : EventRouter;
import api.dn.channels.events.translators.event_translator : EventTranslator;
import api.dn.channels.events.monitors.event_monitor : EventMonitor;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

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
        onInEvent = (chanInEvent) {

            if (eventMonitor)
            {
                eventMonitor.onInEvent(chanInEvent);
            }

            if (!eventTranslator)
            {
                eventRouter.routeInEvent(chanInEvent);
                return;
            }

            ChanInEvent transInEvent = eventTranslator.translateInEvent(chanInEvent);
            if (eventMonitor)
            {
                eventMonitor.onTranslatedInEvent(chanInEvent, transInEvent);
            }

            eventRouter.routeInEvent(transInEvent);
        };

        super.create;

        assert(eventRouter);
        eventRouter.onOutEvent = (outEvent) {

            if (eventMonitor)
            {
                eventMonitor.onOutRouterEvent(outEvent);
            }

            if (!eventTranslator)
            {
                sendOutEvent(outEvent);
                return;
            }

            ChanOutEvent transOutEvent = eventTranslator.translateOutEvent(outEvent);
            if (eventMonitor)
            {
                eventMonitor.onTranslatedOutEvent(outEvent, transOutEvent);
            }

            eventRouter.routeOutEvent(transOutEvent);
        };
    }
}
