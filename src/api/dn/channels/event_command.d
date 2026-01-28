module api.dn.channels.event_command;

import api.dn.channels.fd_channel : FdChannel, FdChannelType;

/**
 * Authors: initkfs
 */
enum EventCommandType
{
    socket
}

struct EventCommand
{
    FdChannel chan;
}
