module api.dn.channels.server_channel;

struct ServerChannel
{
    int fd = -1;
    ushort port;
}
