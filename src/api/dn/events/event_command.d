module api.dn.events.event_command;

import api.dn.chans.fd_chan : FdChan, FdChanType;

/**
 * Authors: initkfs
 */
enum EventCommandType
{
    socket
}

struct EventCommand
{
    FdChan chan;
}
