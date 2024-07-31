module app.dn.channels.contexts.channel_context;

import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import app.dn.channels.pipes.pipeline: Pipeline;

/**
 * Authors: initkfs
 */
struct ChannelContext
{
    Pipeline pipe;
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
