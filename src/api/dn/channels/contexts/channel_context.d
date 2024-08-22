module api.dn.channels.contexts.channel_context;

import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.handlers.pipelines.handler_pipeline: HandlerPipeline;

/**
 * Authors: initkfs
 */
struct ChannelContext
{
    HandlerPipeline pipe;
    ChanInEvent inEvent;
    ChanOutEvent outEvent;
    void delegate(ChanOutEvent) onOutEvent;

    void send(){
        assert(onOutEvent);
        assert(outEvent.chan);
        assert(outEvent.type != ChanOutEvent.ChanOutEventType.none);
        onOutEvent(outEvent);
    }
}
