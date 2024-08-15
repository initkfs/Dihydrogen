module app.dn.channels.handlers.buffered_channel_handler;

import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import app.dn.channels.contexts.channel_context : ChannelContext;

import app.core.utils.sync : MutexLock, mlock;
import app.dn.channels.handlers.channel_handler : ChannelHandler;
import app.dn.pools.linear_pool : LinearPool;
import app.core.mem.buffers.static_buffer : StaticBuffer;

import core.sync.mutex : Mutex;

/**
 * Authors: initkfs
 */
class BufferedChannelHandler(T) : ChannelHandler
{
    protected
    {
        LinearPool!T outBuffers;
        shared Mutex outBufferMutex;

        shared Mutex outEventMutex;
    }

    this(size_t bufferInitialLength = 1024)
    {
        assert(bufferInitialLength > 0);

        outBufferMutex = new shared Mutex;
        outEventMutex = new shared Mutex;

        outBuffers = new LinearPool!T(bufferInitialLength);

        outBuffers.create;

        //TODO move from constructor
        foreach (i; 0 .. outBuffers.length)
        {
            outBuffers.set(i, newOutBuffer);
        }
    }

    abstract T newOutBuffer();

    bool getOutBuffer(int index, out T buffer)
    {
        if (index < 0)
        {
            //throw new Exception("Buffer index must not be negative number");
            return false;
        }

        with (mlock(outBufferMutex))
        {
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

    void lockOutBuffer(scope void delegate() onLock)
    {
        with (mlock(outBufferMutex))
        {
            onLock();
        }
    }

    void sendSync(ChanOutEvent event)
    {
        assert(onOutEvent);
        with (mlock(outEventMutex))
        {
            onOutEvent(event);
        }
    }

}
