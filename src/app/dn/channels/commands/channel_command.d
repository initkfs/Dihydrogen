module app.dn.channels.commands.channel_command;

import app.dn.channels.fd_channel : FdChannel, FdChannelType;
import app.dn.channels.pipes.pipeline : Pipeline;

/**
 * Authors: initkfs
 */
struct ChannelCommand
{
    FdChannel* channel;
    ChannelCommandType type;
    bool isConsumed;

    ubyte* buff;
    size_t buffLen;

    void setRead()
    {
        type = ChannelCommandType.read;
    }

    void setWrite()
    {
        type = ChannelCommandType.write;
    }

    void setClose()
    {
        type = ChannelCommandType.close;
    }
}

enum ChannelCommandType
{
    none,
    accepted,
    readed,
    readedAll,
    writed,
    closed,
    read,
    write,
    close
}
