module app.dn.io.loops.one_pipeline_event_loop;

import app.dn.io.loops.server_loop: ServerLoop;
import app.dn.channels.fd_channel : FdChannel, FdChannelType;
import app.dn.channels.commands.channel_command : ChannelCommand, ChannelCommandType;
import app.dn.channels.pipes.pipeline : Pipeline;
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

        onInputCommand = (cmd) => pipeline.runInputCommand(cmd);
        pipeline.onOutputCommandRun = (cmd) => runCommand(cmd);
    }
}
