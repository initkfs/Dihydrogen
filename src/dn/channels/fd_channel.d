module dn.channels.fd_channel;

enum FdChannelType
{
    socket
}

struct FdChannel
{
    int fd;
    FdChannelType type;
    int state;
    ubyte* buff;
    size_t buffLength;
    size_t availableBytes;
}
