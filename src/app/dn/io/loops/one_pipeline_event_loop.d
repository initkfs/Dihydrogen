module app.dn.io.loops.one_pipeline_event_loop;

import app.dn.io.loops.server_loop: ServerLoop;
import app.dn.channels.fd_channel : FdChannel, FdChannelType;
import app.dn.channels.contexts.channel_context : ChannelContext, ChannelContextType;
import app.dn.channels.pipes.pipleline : Pipeline;
import app.dn.channels.server_channel: ServerChannel;

import std.logger: Logger;

/**
 * Authors: initkfs
 */
class OnePipelineEventLoop : ServerLoop
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

        onWrite = (chan) { return pipeline.onWrite(chan); };

        onClose = (chan) { pipeline.onClose(chan); };
    }
}
