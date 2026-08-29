module api.dn.chans.chan_buffers;

/**
 * Authors: initkfs
 */

struct InBuffer
{
    ubyte[] buff;

    private
    {
        size_t _readIndex;
        size_t _writeIndex;
    }

    void function(void*) closeFunc;
    bool isMustFree;

    bool incRead(size_t offset = 1) @nogc nothrow @safe
    {
        size_t newIndex = _readIndex + offset;
        if (newIndex >= buff.length)
        {
            return false;
        }
        _readIndex = newIndex;
        return true;
    }

    bool isEmpty() @nogc nothrow @safe => buff.length == 0;

    bool incMaxRead() @nogc nothrow @safe
    {
        if (isEmpty)
        {
            return false;
        }
        _readIndex = buff.length - 1;
        return true;
    }

    bool incWrite(size_t offset = 1) @nogc nothrow @safe
    {
        size_t newIndex = _writeIndex + offset;
        if (newIndex >= buff.length)
        {
            return false;
        }
        _writeIndex = newIndex;
        return true;
    }

    bool incMaxWrite() @nogc nothrow @safe
    {
        if (isEmpty)
        {
            return false;
        }
        _writeIndex = buff.length - 1;
        return true;
    }

    ubyte[] readableBytes()
    {
        if (isEmpty)
        {
            return null;
        }

        if (_readIndex < (buff.length - 1))
        {
            return buff[0 .. _readIndex];
        }
        return buff[0 .. $];
    }

    ubyte[] writableBytes() => buff[_writeIndex .. $];

    void resetBufferRead()
    {
        _readIndex = 0;
    }

    void resetBufferWrite()
    {
        _writeIndex = 0;
    }

    void resetBufferIndices()
    {
        resetBufferRead;
        resetBufferWrite;
    }

    void reset()
    {
        resetBufferIndices;
        //TODO free?
        buff = null;
    }

    size_t readIndex() const @nogc pure nothrow @safe => _readIndex;
    size_t writeIndex() const @nogc pure nothrow @safe => _writeIndex;

    bool dispose()
    {
        if (!isMustFree || buff.length == 0)
        {
            return false;
        }

        if (closeFunc)
        {
            closeFunc(buff.ptr);
        }
        else
        {
            import core.memory : pureFree;

            pureFree(buff.ptr);
        }

        reset;
        return true;
    }
}

struct OutBuffer
{
    ubyte[] buff;
    bool isMustFree;

    void function(void*) closeFunc;

    bool isEmpty() => buff.length == 0;
    size_t length() const => buff.length;

    void resetUnsafe()
    {
        isMustFree = false;
        buff = null;
        closeFunc = null;
    }

    void reset()
    {
        if (isMustFree)
        {
            dispose;
            return;
        }

        resetUnsafe;
    }

    bool dispose()
    {
        if (!isMustFree || buff.length == 0)
        {
            return false;
        }

        if (closeFunc)
        {
            closeFunc(buff.ptr);
        }
        else
        {
            import core.memory : pureFree;

            pureFree(buff.ptr);
        }

        resetUnsafe;
        return true;
    }
}

unittest
{
    InBuffer buff;
    buff.buff = [0, 1, 2, 3, 4];
    assert(!buff.incRead(10));
    assert(!buff.incWrite(10));

    assert(buff.incRead);
    assert(buff.incWrite);

    assert(buff.readableBytes == [0]);
    assert(buff.writableBytes == [1, 2, 3, 4]);

    assert(buff.incRead(2));
    assert(buff.readableBytes == [0, 1, 2]);

    assert(buff.incWrite(1));
    assert(buff.writableBytes == [2, 3, 4]);

    assert(buff.incMaxRead);
    assert(buff.readableBytes == [0, 1, 2, 3, 4]);

    assert(buff.incMaxWrite);
    assert(buff.writableBytes == [4]);
}
