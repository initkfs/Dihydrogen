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
    ubyte[] buff;
    size_t readIndex;
    size_t writeIndex;
    void* data;

    bool incRead(size_t offset = 1) @nogc nothrow @safe
    {
        size_t newIndex = readIndex + offset;
        if (newIndex >= buff.length)
        {
            return false;
        }
        readIndex = newIndex;
        return true;
    }

    bool incMaxRead() @nogc nothrow @safe
    {
        if (buff.length == 0)
        {
            return false;
        }
        readIndex = buff.length - 1;
        return true;
    }

    bool incWrite(size_t offset = 1) @nogc nothrow @safe
    {
        size_t newIndex = writeIndex + offset;
        if (newIndex >= buff.length)
        {
            return false;
        }
        writeIndex = newIndex;
        return true;
    }

    bool incMaxWrite() @nogc nothrow @safe
    {
        if (buff.length == 0)
        {
            return false;
        }
        writeIndex = buff.length - 1;
        return true;
    }

    ubyte[] readableBytes()
    {
        return buff[0 .. readIndex];
    }

    ubyte[] writableBytes()
    {
        return buff[writeIndex .. $];
    }

    void resetBufferRead(){
        readIndex = 0;
    }

    void resetBufferWrite(){
        writeIndex = 0;
    }

    void resetBufferIndices()
    {
        readIndex = 0;
        writeIndex = 0;
    }

    string toSimpleString() const
    {
        import std.format : format;

        return format("[%s:%s]", typeof(this).stringof, fd);
    }
}
