module app.dn.channels.handlers.buffered_channel_handler;

import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import app.dn.channels.contexts.channel_context : ChannelContext;

import app.core.utils.sync : MutexLock, mLock;
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
        shared Mutex bufferMutex;
        shared Mutex outMutex;
    }

    this(size_t bufferInitialLength = 1024)
    {
        assert(bufferInitialLength > 0);

        bufferMutex = new shared Mutex;
        outMutex = new shared Mutex;

        outBuffers = new LinearPool!T(bufferInitialLength);

        outBuffers.create;

        //TODO move from constructor
        foreach (i; 0 .. outBuffers.length)
        {
            outBuffers.set(i, newBuffer);
        }
    }

    abstract T newBuffer();

    T getBuffer(int index)
    {
        if (index < 0)
        {
            throw new Exception("Buffer index must not be negative number");
        }

        with (mLock(bufferMutex))
        {
            while (!outBuffers.hasIndex(index))
            {
                //TODO replace with false
                if (!outBuffers.increase)
                {
                    throw new Exception("Buffer out of memory");
                }

                outBuffers.set(index, newBuffer);
            }

            return outBuffers.get(index);
        }
    }

    void sendSync(ChanOutEvent event)
    {
        assert(onOutEvent);
        with (mLock(outMutex))
        {
            onOutEvent(event);
        }
    }

}
