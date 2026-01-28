module api.dn.events.routes.pipeline_router;

import api.dn.events.routes.event_router : EventRouter;
import api.dn.pipelines.handler_pipeline : HandlerPipeline;
import api.dn.events.channel_events : ChanInEvent, ChanOutEvent;

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
        pipeline.onOutEvent = (event) {
            routeOutEvent(event);
        };
    }

    override bool routeInEvent(ChanInEvent eventIn)
    {
        return pipeline.onInEvent(eventIn);
    }

    override bool routeOutEvent(ChanOutEvent eventOut)
    {
        assert(onOutEvent, "On out event listener must not be null");
        return onOutEvent(eventOut);
    }
}
