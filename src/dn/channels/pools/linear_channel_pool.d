module dn.channels.pools.linear_channel_pool;

import core.stdc.stdlib : malloc, realloc, free;
import core.stdc.string : memset;

debug
{
    import std.stdio;
}
/**
 * Authors: initkfs
 */
class LinearChannelPool(V)
{
    size_t growFactor = 2;

    private
    {
        size_t _count;
        size_t _size;
        V* poolPtr;

    }

    V* ptr()
    {
        return poolPtr;
    }

    this(size_t initCount = 1024)
    {
        assert(initCount > 0);
        _count = initCount;
        _size = _count * V.sizeof;
    }

    bool create()
    {
        assert(!poolPtr);
        auto mustBePtr = malloc(_size);
        if (!mustBePtr)
        {
            return false;
        }

        poolPtr = cast(V*) mustBePtr;

        memset(poolPtr, 0, _size);

        return true;
    }

    bool hasIndex(size_t index)
    {
        return index < _count;
    }

    V get(size_t index)
    {
        assert(poolPtr);
        assert(index < _count);

        return poolPtr[index];
    }

    bool increase()
    {
        import core.checkedint;

        bool isOverflow;
        auto newSize = mulu(_size, growFactor, isOverflow);
        if (isOverflow)
        {
            return false;
        }
        auto mustBePtr = realloc(cast(void*) poolPtr, newSize);
        if (!mustBePtr)
        {
            return false;
        }
        poolPtr = cast(V*) mustBePtr;

        auto lastIndexPtr = poolPtr + _count;
        memset(lastIndexPtr, 0, newSize - _size);
        _size = newSize;
        _count = newSize / V.sizeof;
        return true;
    }

    bool set(size_t index, V ptr)
    {
        assert(poolPtr);
        assert(index < _count);
        poolPtr[index] = ptr;
        return true;
    }

    bool removeLast(size_t lastValues, scope bool delegate(V) onRemoveIsContinue = null)
    {
        assert(poolPtr);
        assert(lastValues < _count);

        auto removeSize = lastValues * V.sizeof;
        assert(removeSize < _size);

        auto newSize = _size - removeSize;

        if (onRemoveIsContinue)
        {
            auto lastSlice = poolPtr[(_count - lastValues) .. _count];
            foreach (v; lastSlice)
            {
                if (!onRemoveIsContinue(v))
                {
                    break;
                }
            }
        }

        poolPtr = cast(V*) realloc(cast(void*) poolPtr, newSize);
        assert(poolPtr);
        _size = newSize;
        _count = newSize / V.sizeof;
        return true;
    }

    bool destroy()
    {
        if (poolPtr)
        {
            free(cast(void*) poolPtr);
            return true;
        }
        return false;
    }

    V[] slice()
    {
        assert(poolPtr);
        assert(_count > 0);
        return poolPtr[0 .. _count];
    }

    size_t count()
    {
        return _count;
    }

    size_t sizeBytes()
    {
        return _size;
    }

}

unittest
{
    enum v1Count = 2;
    enum growFactor = 2;
    auto poolPtr1 = new ConnectionpoolPtr!(int)(v1Count);
    scope (exit)
    {
        poolPtr1.destroy;
    }
    poolPtr1.growFactor = growFactor;

    assert(poolPtr1.create);
    assert(poolPtr1.count == 2);
    assert(poolPtr1.sizeBytes == int.sizeof * 2);
    assert(poolPtr1.hasIndex(0));
    assert(poolPtr1.hasIndex(1));
    assert(!poolPtr1.hasIndex(2));

    int v1 = 3;
    int v2 = 4;
    int v3 = 5;
    int v4 = 6;

    poolPtr1.set(0, v1);
    poolPtr1.set(1, v2);
    assert(poolPtr1.get(0) == v1);
    assert(poolPtr1.get(1) == v2);

    assert(poolPtr1.set(2, v3));
    assert(poolPtr1.get(2) == v3);
    assert(poolPtr1.set(3, v4));
    assert(poolPtr1.get(3) == v4);

    auto newCount = v1Count * poolPtr1.growFactor;

    assert(poolPtr1.count == newCount);
    assert((poolPtr1.sizeBytes / poolPtr1.growFactor) == v1Count * int.sizeof);

    int counter;
    assert(poolPtr1.removeLast(2, (v) {
            switch (counter)
            {
                case 0:
                    assert(v == v3);
                    break;
                case 1:
                    assert(v == v4);
                    break;
                default:
                    break;
            }
            counter++;
            return true;
        }));
    assert(counter == 2);

    assert(poolPtr1.count == newCount - 2);
    assert(poolPtr1.sizeBytes == (newCount - 2) * int.sizeof);
}
