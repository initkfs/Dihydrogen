module api.dn.channels.channel_context;

import api.dn.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.pipelines.handler_pipeline: HandlerPipeline;

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
        assert(outEvent.state != ChanOutEvent.ChanOutEventState.none);
        onOutEvent(outEvent);
    }
}
