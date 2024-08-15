module app.core.utils.sync;

import core.sync.mutex : Mutex;

/**
 * Authors: initkfs
 */
struct MutexLock(bool isNothrow = false)
{
    private shared
    {
        Mutex mtx;
    }

    static if (isNothrow)
    {
        this(shared Mutex mtx) @nogc nothrow @safe
        {
            assert(mtx);
            this.mtx = mtx;
            mtx.lock_nothrow;
        }

        ~this() @nogc nothrow @safe
        {
            mtx.unlock_nothrow;
        }
    }
    else
    {
        this(shared Mutex mtx) @safe
        {
            assert(mtx);
            this.mtx = mtx;
            mtx.lock;
        }

        ~this() @safe
        {
            mtx.unlock;
        }
    }
}

auto mlock(bool isNothrow = false)(shared Mutex m){
    return MutexLock!isNothrow(m);
}
