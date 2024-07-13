module dn.net.connects.fd_connect;

enum FdConnectType {
    socket
}

struct FdConnect(size_t BuffSize)
{
    int fd;
    FdConnectType type;
    int state;
    ubyte[BuffSize] buff;
    size_t availableBytes;
}
