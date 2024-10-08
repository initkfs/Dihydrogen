module api.dn.channels.events.routes.pipeline_router;

import api.dn.channels.events.routes.event_router : EventRouter;
import api.dn.channels.handlers.pipelines.handler_pipeline : HandlerPipeline;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

/**
 * Authors: initkfs
 */

class PipelineRouter : EventRouter
{
    HandlerPipeline pipeline;

    this(HandlerPipeline pipeline)
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
