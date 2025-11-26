module api.dn.channels.fd_channel_buffers;

/**
 * Authors: initkfs
 */

struct InBuffer
{
    ubyte[] buff;

    size_t readIndex;
    size_t writeIndex;

    bool isText;

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

    void resetBufferRead()
    {
        readIndex = 0;
    }

    void resetBufferWrite()
    {
        writeIndex = 0;
    }

    void reset()
    {
        resetBufferIndices;
        buff = null;
        isText = false;
    }

    void resetBufferIndices()
    {
        readIndex = 0;
        writeIndex = 0;
    }
}

struct OutBuffer
{
    ubyte[] slice;
    bool isMustClose;
    bool isText;

    void function(void*) closeFunc;

    size_t length() const => slice.length;

    void resetUnsafe()
    {
        isMustClose = false;
        slice = null;
        closeFunc = null;
        isText = false;
    }

    void reset()
    {
        if (isMustClose)
        {
            dispose;
            return;
        }

        resetUnsafe;
    }

    bool dispose()
    {
        if (!isMustClose || slice.length == 0)
        {
            return false;
        }

        if (closeFunc)
        {
            closeFunc(slice.ptr);
        }
        else
        {
            import core.memory : pureFree;

            pureFree(slice.ptr);
        }

        resetUnsafe;
        return true;
    }
}
