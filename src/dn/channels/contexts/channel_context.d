module dn.channels.contexts.channel_context;

import dn.channels.fd_channel : FdChannel, FdChannelType;
import dn.channels.pipes.pipleline : Pipeline;

/**
 * Authors: initkfs
 */
struct ChannelContext
{
    Pipeline pipeline;
    FdChannel* channel;
    ChannelContextType type;

    ubyte* buff;
    size_t buffLen;

    void read()
    {
        type = ChannelContextType.read;
    }

    void write()
    {
        type = ChannelContextType.write;
    }

    void close()
    {
        type = ChannelContextType.close;
    }
}

enum ChannelContextType
{
    none,
    read,
    write,
    close
}
