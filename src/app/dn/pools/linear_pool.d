module app.dn.pools.linear_pool;

import core.stdc.stdlib : malloc, realloc, free;
import core.stdc.string : memset;

debug
{
    import std.stdio;
}
/**
 * Authors: initkfs
 */
class LinearPool(V)
{
    size_t growFactor = 2;

    private
    {
        V[] pool;
        size_t _size;
    }

    inout(V*) ptr() inout return @safe
    {
        return &pool[0];
    }

    this(size_t initCount = 1024) pure @safe
    {
        assert(initCount > 0);
        _size = initCount * V.sizeof;
    }

    bool create()
    {
        assert(!pool);
        assert(_size > 0);

        auto mustBePtr = malloc(_size);
        if (!mustBePtr)
        {
            return false;
        }

        //memset(mustBePtr, 0, _size);

        pool = cast(V[]) mustBePtr[0 .. _size];

        pool[] = V.init;

        return true;
    }

    bool hasIndex(size_t index)
    {
        return index < pool.length;
    }

    V get(size_t index)
    {
        assert(pool);
        assert(index < pool.length);

        return pool[index];
    }

    bool increase()
    {
        import core.checkedint;

        assert(growFactor > 0);
        assert(_size > 0);
        assert(pool);

        bool isOverflow;
        auto newSize = mulu(_size, growFactor, isOverflow);
        if (isOverflow)
        {
            return false;
        }
        auto mustBePtr = realloc(cast(void*) pool.ptr, newSize);
        if (!mustBePtr)
        {
            return false;
        }

        auto newPool = cast(V[]) mustBePtr[0 .. newSize];
        newPool[pool.length .. $] = V.init;

        pool = newPool;
        _size = newSize;
        return true;
    }

    bool set(size_t index, V ptr)
    {
        assert(pool);
        assert(index < pool.length);
        pool[index] = ptr;
        return true;
    }

    bool removeLast(size_t lastValues, scope bool delegate(V) onRemoveIsContinue = null)
    {
        assert(pool);
        assert(lastValues < pool.length);

        auto removeSize = lastValues * V.sizeof;
        assert(removeSize < _size);

        auto newSize = _size - removeSize;

        if (onRemoveIsContinue)
        {
            auto lastSlice = pool[((pool.length) - lastValues) .. $];
            foreach (v; lastSlice)
            {
                if (!onRemoveIsContinue(v))
                {
                    break;
                }
            }
        }

        auto mustBePoolPtr = realloc(cast(void*) pool.ptr, newSize);
        if (!mustBePoolPtr)
        {
            return false;
        }
        pool = cast(V[]) mustBePoolPtr[0 .. newSize];
        _size = newSize;
        return true;
    }

    bool destroy()
    {
        if (pool)
        {
            free(cast(void*) pool.ptr);
            return true;
        }
        return false;
    }

    inout(V[]) slice() inout return @safe
    {
        assert(pool);
        assert(pool.length > 0);
        return pool;
    }

    size_t length()
    {
        return pool.length;
    }

    size_t sizeBytes()
    {
        return pool.length * V.sizeof;
    }

}

unittest
{
    enum v1Count = 2;
    enum growFactor = 2;
    auto poolPtr1 = new LinearPool!(int)(v1Count);
    scope (exit)
    {
        poolPtr1.destroy;
    }
    poolPtr1.growFactor = growFactor;

    assert(poolPtr1.create);
    assert(poolPtr1.length == 2);
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

    assert(poolPtr1.increase);

    assert(poolPtr1.set(2, v3));
    assert(poolPtr1.get(2) == v3);
    assert(poolPtr1.set(3, v4));
    assert(poolPtr1.get(3) == v4);

    auto newCount = v1Count * poolPtr1.growFactor;

    assert(poolPtr1.length == newCount);
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

    assert(poolPtr1.length == newCount - 2);
    assert(poolPtr1.sizeBytes == (newCount - 2) * int.sizeof);
}

unittest
{
    enum v1Count = 2;
    auto poolPtr1 = new LinearPool!(int*)(v1Count);
    scope (exit)
    {
        poolPtr1.destroy;
    }
    poolPtr1.growFactor = 2;

    assert(poolPtr1.create);
    assert(poolPtr1.length == 2);
    assert(poolPtr1.sizeBytes == (int*).sizeof * 2);
    assert(poolPtr1.hasIndex(0));
    assert(poolPtr1.hasIndex(1));
    assert(!poolPtr1.hasIndex(2));

    int v1 = 3;
    int v2 = 4;
    int v3 = 5;
    int v4 = 6;

    poolPtr1.set(0, &v1);
    poolPtr1.set(1, &v2);
    assert(poolPtr1.get(0) == &v1);
    assert(poolPtr1.get(1) == &v2);

    poolPtr1.increase;

    assert(poolPtr1.set(2, &v3));
    assert(poolPtr1.get(2) == &v3);
    assert(poolPtr1.set(3, &v4));
    assert(poolPtr1.get(3) == &v4);

    auto newCount = v1Count * poolPtr1.growFactor;

    assert(poolPtr1.length == newCount);
    assert((poolPtr1.sizeBytes / poolPtr1.growFactor) == v1Count * (int*).sizeof);
}
