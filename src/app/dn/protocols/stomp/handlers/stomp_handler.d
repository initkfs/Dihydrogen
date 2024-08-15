module app.dn.protocols.stomp.handlers.stomp_handler;

import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.handlers.buffered_channel_handler : BufferedChannelHandler;
import app.dn.channels.handlers.channel_handler : ChannelHandler;
import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import app.dn.channels.contexts.channel_context : ChannelContext;

import app.dn.pools.linear_pool : LinearPool;
import app.core.mem.buffers.static_buffer : StaticBuffer;

import app.core.utils.sync : MutexLock, mlock;

import app.dn.protocols.stomp.stomp_common;
import app.dn.protocols.stomp.stomp_decoder : StompDecoder, DecoderState;
import app.dn.protocols.stomp.stomp_encoder : StompEncoder;

debug import std.stdio : writeln, writefln;

import core.thread : Thread;
import core.sync.mutex;

class Timer : Thread
{
    shared void delegate() onRun;

    this(shared void delegate() onRun)
    {
        super(&run);
        this.onRun = onRun;
    }

    void run()
    {
        while (true)
        {
            import core.time : dur;

            sleep(5.dur!"seconds");
            if (onRun)
            {
                onRun();
            }
        }
    }
}

enum bufferInitialLength = 1024;
enum frameBufferLength = 1024;

alias FrameStaticBuffer = StaticBuffer!(char, frameBufferLength, true);

struct OutBufferData
{
    StompCommand state = StompCommand.CONNECT;
    FdChannel* chan;
    FrameStaticBuffer buffer;
    long lastReadTimestamp;
    long lastWriteTimestamp;
    long lastAckTimestamp;
    long lastNackTimestamp;
}

/**
 * Authors: initkfs
 */
class StompHandler : BufferedChannelHandler!(OutBufferData*)
{
    Thread timer;

    StompDecoder decoder;
    StompEncoder!(10, 256, 256, 256) encoder;

    this()
    {
        super(bufferInitialLength);

        decoder = new StompDecoder;
        encoder = new StompEncoder!(10, 256, 256, 256);

        timer = new Timer(() {
            with (mlock(outBufferMutex))
            {
                auto currTimestamp = timestamp;
                foreach (i; 0 .. outBuffers.length)
                {
                    auto buffData = outBuffers.get(i);
                    if (buffData.state == StompCommand.CONNECT)
                    {
                        continue;
                    }
                }
            }
        });

        timer.start;
    }

    override protected OutBufferData* newOutBuffer()
    {
        import core.stdc.stdlib : malloc, realloc, free;

        auto newBuff = malloc(OutBufferData.sizeof);
        if (!newBuff)
        {
            return null;
        }
        auto frame = cast(OutBufferData*) newBuff;
        *frame = OutBufferData.init;
        return frame;
    }

    override void onAccepted(ChannelContext ctx)
    {
        OutBufferData* buffData;
        if(!getOutBuffer(ctx.inEvent.chan.fd, buffData)){
            //TODO logging;
            return;
        }
        buffData.chan = ctx.inEvent.chan;

        ctx.outEvent.setRead;
        sendSync(ctx.outEvent);
    }

    override void onReadStart(ChannelContext ctx)
    {
        outBufferMutex.lock;
        scope (exit)
        {
            outBufferMutex.unlock;
        }

        ubyte[] chanBuff = ctx.inEvent.chan.readableBytes;
        if (chanBuff.length > 0 || chanBuff[0] == '\0')
        {
            decoder.decode(chanBuff);

            OutBufferData* outBuffer;
            if(!getOutBuffer(ctx.inEvent.chan.fd, outBuffer)){
                //TODO logging
                return;
            }

            outBuffer.buffer.reset;
            outBuffer.lastReadTimestamp = timestamp;

            if (decoder.state != DecoderState.endFrame)
            {
                sendError(outBuffer, ctx, "Invalid STOMP frame");
                return;
            }

            switch (decoder.command) with (StompCommand)
            {
                case CONNECT:
                    if (outBuffer.state == CONNECT)
                    {
                        sendConnected(outBuffer, ctx);
                    }
                    else
                    {
                        sendError(outBuffer, ctx, "Invalid state on connect");
                    }
                    break;
                case SUBSCRIBE:
                    if (outBuffer.state == CONNECTED)
                    {
                        sendMessage(outBuffer, ctx);
                    }
                    else
                    {
                        sendError(outBuffer, ctx, "Invalid state for subscribe");
                    }
                    break;
                default:
                    sendError(outBuffer, ctx, "Unsupported command");
                    break;
            }
        }
        else
        {
            //writeln("Continue reading");
            ctx.outEvent.setRead;
            sendSync(ctx.outEvent);
        }
    }

    protected void sendFrame(OutBufferData* bufferData, ChannelContext ctx)
    {
        bufferData.lastWriteTimestamp = timestamp;

        ctx.inEvent.chan.resetBufferIndices;

        ctx.outEvent.setWrite;
        ctx.outEvent.buffer = cast(ubyte[])(*bufferData).buffer[];
        sendSync(ctx.outEvent);
    }

    protected void sendConnected(OutBufferData* bufferData, ChannelContext ctx)
    {
        auto errorFrame = encoder.connected;
        bufferData.state = StompCommand.CONNECTED;
        encoder.decode!(frameBufferLength)(errorFrame, (*bufferData).buffer);
        sendFrame(bufferData, ctx);
    }

    protected void sendError(OutBufferData* bufferData, ChannelContext ctx, const(char)[] message = "Unknown error")
    {
        auto errorFrame = encoder.error(message);
        bufferData.state = StompCommand.ERROR;
        encoder.decode!(frameBufferLength)(errorFrame, (*bufferData).buffer);

        sendFrame(bufferData, ctx);
    }

    protected void sendMessage(OutBufferData* bufferData, ChannelContext ctx, const(char)[] message = "Message", const(
            char)[] dest = "/", const(char)[] messageId = "0", const(char)[] subscription = "0")
    {
        auto frame = encoder.message(message, dest, messageId, subscription);
        bufferData.state = StompCommand.MESSAGE;
        encoder.decode!(frameBufferLength)(frame, (*bufferData).buffer);

        sendFrame(bufferData, ctx);
    }

    protected void sendDisconnect(OutBufferData* bufferData, ChannelContext ctx)
    {
        auto frame = encoder.disconnect;
        bufferData.state = StompCommand.DISCONNECT;
        encoder.decode!(frameBufferLength)(frame, (*bufferData).buffer);

        sendFrame(bufferData, ctx);
    }

    override void onReadEnd(ChannelContext ctx)
    {
        // ctx.outEvent.setWrite;
        // ctx.outEvent.buff = cast(ubyte*) response.ptr;
        // ctx.outEvent.buffLen = response.length;
        // ctx.send;
    }

    override void onWrote(ChannelContext ctx)
    {
        outBufferMutex.lock;
        scope (exit)
        {
            outBufferMutex.unlock;
        }

        OutBufferData* buffer;
        if(!getOutBuffer(ctx.inEvent.chan.fd, buffer)){
            //TODO logging
            return;
        }

        if (buffer.state == StompCommand.DISCONNECT || buffer.state == StompCommand.ERROR)
        {
            ctx.outEvent.setClose;
            ctx.send;
            return;
        }

        //TODO read?
        if (buffer.state == StompCommand.MESSAGE)
        {
            return;
        }

        ctx.inEvent.chan.resetBufferIndices;
        ctx.outEvent.setRead;
        sendSync(ctx.outEvent);
    }

    override void onClosed(ChannelContext ctx)
    {
        outBufferMutex.lock;
        scope (exit)
        {
            outBufferMutex.unlock;
        }

        OutBufferData* bufferData;
        if(!getOutBuffer(ctx.inEvent.chan.fd, bufferData)){
            //TODO logging
            return;
        }
        //TODO separate state?
        bufferData.state = StompCommand.CONNECT;
    }

}
