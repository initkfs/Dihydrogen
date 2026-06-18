module api.dn.chans.chan_context;

import api.dn.events.chan_events : ChanInEvent, ChanOutEvent;
import api.dn.pipelines.handler_pipeline: HandlerPipeline;

/**
 * Authors: initkfs
 */
struct ChanContext
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
