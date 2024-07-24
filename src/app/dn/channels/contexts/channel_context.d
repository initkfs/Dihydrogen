module app.dn.channels.contexts.channel_context;

import app.dn.channels.fd_channel : FdChannel, FdChannelType;
import app.dn.channels.pipes.pipleline : Pipeline;

/**
 * Authors: initkfs
 */
struct ChannelContext
{
    Pipeline pipeline;
    FdChannel* channel;
    ChannelContextType type;
    bool isConsumed;

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
