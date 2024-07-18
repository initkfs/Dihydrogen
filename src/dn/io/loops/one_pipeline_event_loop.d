module dn.io.loops.one_pipeline_event_loop;

import dn.io.loops.event_loop : EventLoop;
import dn.channels.fd_channel : FdChannel, FdChannelType;
import dn.channels.contexts.channel_context : ChannelContext, ChannelContextType;
import dn.channels.pipes.pipleline : Pipeline;
import dn.channels.server_channel: ServerChannel;

import std.logger: Logger;

/**
 * Authors: initkfs
 */
class OnePipelineEventLoop : EventLoop
{
    Pipeline pipeline;

    this(Logger logger, ServerChannel[] serverSockets, Pipeline pipeline)
    {
        super(logger, serverSockets);

        assert(pipeline);
        this.pipeline = pipeline;
    }

    override void create()
    {
        super.create;

        onAccept = (chan) { return pipeline.onAccept(chan); };

        onRead = (chan) { return pipeline.onRead(chan); };

        onReadEnd = (chan) { return pipeline.onReadEnd(chan); };

        onWrite = (chan) { return pipeline.onReadEnd(chan); };

        onClose = (chan) { pipeline.onClose(chan); };
    }
}
