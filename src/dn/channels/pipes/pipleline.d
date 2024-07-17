module dn.channels.pipes.pipleline;

import dn.channels.handlers.channel_handler : ChannelHandler;
import dn.channels.fd_channel: FdChannel, FdChannelType;

/**
 * Authors: initkfs
 */
class Pipeline
{
    ChannelHandler first;

    void run()
    {
        ChannelHandler curr = first;
        while (curr)
        {


            curr = first.next;
        }
    }

}
