module app.dn.channels.contexts.channel_context;

import app.dn.channels.commands.channel_context : ChannelCommand, ChannelCommandType;
import app.dn.channels.pipes.pipeline: Pipeline;

/**
 * Authors: initkfs
 */
struct ChannelContext
{
    Pipeline pipe;
    ChannelCommand inCmd;
    void delegate(ChannelCommand) onOutputCmd;

    void run(){
        assert(onOutputCmd);
        onOutputCmd(inCmd);
    }
}
