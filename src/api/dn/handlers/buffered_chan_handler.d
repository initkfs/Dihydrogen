module api.dn.handlers.buffered_chan_handler;

import api.dn.chans.fd_chan : FdChan, FdChanType;

import api.dn.events.chan_events : ChanInEvent, ChanOutEvent;
import api.dn.chans.chan_context : ChanContext;

import api.dn.handlers.chan_handler : ChanHandler;
import api.dn.utils.pools.linear_pool : LinearPool;

import core.sync.mutex : Mutex;

/**
 * Authors: initkfs
 */
class BufferedChanHandler(T) : ChanHandler
{
    protected
    {
        LinearPool!T outBuffers;
    }

    this(size_t bufferInitialLength = 1024)
    {
        assert(bufferInitialLength > 0);

        outBuffers = new LinearPool!T(bufferInitialLength);
        outBuffers.create;

        //TODO move from constructor
        foreach (i; 0 .. outBuffers.length)
        {
            outBuffers.set(i, newOutBuffer);
        }
    }

    abstract T newOutBuffer();

    void onOutBuffers(scope bool delegate(T) onBufferIsContinue)
    {
        synchronized (outBuffers)
        {
            foreach (i; 0 .. outBuffers.length)
            {
                T buff;
                //TODO unsafe cast to int;
                if (!getOutBuffer(cast(int) i, buff))
                {
                    //TODO return false?
                    import std.conv : to;

                    throw new Exception("Buffer not found with index: " ~ i.to!string);
                }
                if (!onBufferIsContinue(buff))
                {
                    break;
                }
            }
        }
    }

    bool getOutBuffer(int index, out T buffer)
    {
        if (index < 0)
        {
            //throw new Exception("Buffer index must not be negative number");
            return false;
        }

        while (!outBuffers.hasIndex(index))
        {
            if (!outBuffers.increase)
            {
                //TODO logging
                //throw new Exception("Buffer out of memory");
                return false;
            }

            outBuffers.set(index, newOutBuffer);
        }

        buffer = outBuffers.get(index);
        return true;
    }
}
