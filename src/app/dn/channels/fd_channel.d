module app.dn.channels.fd_channel;

/**
 * Authors: initkfs
 */
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
    void* data;

    string toSimpleString() const
    {
        import std.format : format;
        
        return format("[%s:%s]", typeof(this).stringof, fd);
    }
}
