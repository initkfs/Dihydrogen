module dn.channels.fd_channel;

enum FdChannelType {
    socket
}

struct FdChannel(size_t BuffSize)
{
    int fd;
    FdChannelType type;
    int state;
    ubyte[BuffSize] buff;
    size_t availableBytes;
}
