module app.dn.channels.events.routes.pipeline_router;

import app.dn.channels.events.routes.event_router : EventRouter;
import app.dn.channels.pipes.pipeline : Pipeline;
import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

/**
 * Authors: initkfs
 */

class PipelineRouter : EventRouter
{
    Pipeline pipeline;

    this(Pipeline pipeline)
    {
        assert(pipeline);
        this.pipeline = pipeline;

        //TODO move to create()
        pipeline.onOutEvent = (event) => routeOutEvent(event);
    }

    override void routeInEvent(ChanInEvent eventIn)
    {
        pipeline.onInEvent(eventIn);
    }

    override void routeOutEvent(ChanOutEvent eventOut)
    {
        assert(onOutEvent, "On out event listener must not be null");
        onOutEvent(eventOut);
    }
}
