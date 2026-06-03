module api.dn.io.loops.endpointable_event_loop;

import api.dn.io.loops.eventable_event_loop : EventableEventLoop;
import api.dn.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.chans.fd_chan : FdChan, FdChanType;

import api.dn.events.routes.event_router : EventRouter;
import api.dn.events.converters.event_converter : EventConverter;
import api.dn.events.monitors.event_monitor : EventMonitor;
import api.dn.events.channel_events : ChanInEvent, ChanOutEvent;

import api.core.loggers.logging : Logging;

/**
 * Authors: initkfs
 */
class EndpointableEventLoop : EventableEventLoop
{
    EventRouter eventRouter;
    EventConverter eventConverter;
    EventMonitor eventMonitor;

    this(Logging logger, EventRouter router, EventConverter translator = null, EventMonitor monitor = null)
    {
        super(logger);

        assert(router);
        eventRouter = router;
        this.eventConverter = translator;
        this.eventMonitor = monitor;

        eventRouter.onOutEvent = (outEvent) {

            if (eventMonitor)
            {
                eventMonitor.onOutRouterEvent(outEvent);
            }

            if (eventConverter && eventConverter.isNeedConvert(outEvent))
            {
                auto convOutEvent = eventConverter.convertOutEvent(outEvent);
                if (eventMonitor)
                {
                    eventMonitor.onConvertedOutEvent(outEvent, convOutEvent);
                }
                outEvent = convOutEvent;
            }

            return sendOutEvent(outEvent);
        };
    }

    override bool sendInEvent(ChanInEvent chanInEvent)
    {
        super.sendInEvent(chanInEvent);

        if (eventMonitor)
        {
            eventMonitor.onInEvent(chanInEvent);
        }

        if (eventConverter && eventConverter.isNeedConvert(chanInEvent))
        {
            auto convInEvent = eventConverter.convertInEvent(chanInEvent);
            if (eventMonitor)
            {
                eventMonitor.onConvertedInEvent(chanInEvent, convInEvent);
            }
            chanInEvent = convInEvent;
        }

        assert(eventRouter);
        return eventRouter.routeInEvent(chanInEvent);
    }

    override void create()
    {
        super.create;

    }
}
