module app.dn.channels.pipes.pipeline;

import app.dn.channels.handlers.channel_handler : ChannelHandler;
import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.commands.channel_context : ChannelCommand, ChannelCommandType;
import app.dn.channels.contexts.channel_context: ChannelContext;

/**
 * Authors: initkfs
 */
class Pipeline
{
    ChannelHandler first;

    void delegate(ChannelCommand) onOutputCommandRun;

    void runInputCommand(ChannelCommand cmd)
    {
        switch (cmd.type) with (ChannelCommandType)
        {
            case accepted:
                onAccept(cmd);
                break;
            case readed:
                onRead(cmd);
                break;
            case readedAll:
                onReadEnd(cmd);
                break;
            case writed:
                onWrite(cmd);
                break;
            case closed:
                onClose(cmd);
                break;
            default:
                break;
        }
    }

    void runOutputCommand(ChannelCommand cmd)
    {
        assert(onOutputCommandRun);
        onOutputCommandRun(cmd);
    }

    protected void onHandler(scope bool delegate(ChannelHandler) onHandlerIsContinue)
    {
        assert(onOutputCommandRun);

        ChannelHandler curr = first;
        while (curr)
        {
            if (!onHandlerIsContinue(curr))
            {
                break;
            }

            curr = curr.next;
        }
    }

    void onAccept(ChannelCommand cmd)
    {
        onHandler((h) {
            h.onAccept(ChannelContext(this, cmd, onOutputCommandRun));
            return true;
        });
    }

    void onRead(ChannelCommand cmd)
    {
        onHandler((h) {
            h.onRead(ChannelContext(this, cmd, onOutputCommandRun));
            return true;
        });
    }

    void onReadEnd(ChannelCommand cmd)
    {
        onHandler((h) {
            h.onReadEnd(ChannelContext(this, cmd, onOutputCommandRun));
            return true;
        });
    }

    void onWrite(ChannelCommand cmd)
    {
        onHandler((h) {
            h.onWrite(ChannelContext(this, cmd, onOutputCommandRun));
            return true;
        });
    }

    void onClose(ChannelCommand cmd)
    {
        onHandler((h) {
            h.onClose(ChannelContext(this, cmd, onOutputCommandRun));
            return true;
        });
    }

    bool add(ChannelHandler handler)
    {
        if (!first)
        {
            first = handler;
            return true;
        }

        assert(first != handler);

        first.next = handler;
        handler.prev = first;

        return true;
    }

}
