module api.dn.channels.handlers.buffered_channel_handler;

import api.dn.channels.fd_channel : FdChannel, FdChannelType;

import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.contexts.channel_context : ChannelContext;

import api.core.utils.sync : MutexLock;
import api.dn.channels.handlers.channel_handler : ChannelHandler;
import api.dn.pools.linear_pool : LinearPool;
import api.core.mem.buffers.static_buffer : StaticBuffer;

import core.sync.mutex : Mutex;

/**
 * Authors: initkfs
 */
class BufferedChannelHandler(T) : ChannelHandler
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
