module app.dn.protocols.stomp.handlers.stomp_handler;

import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.handlers.buffered_channel_handler : BufferedChannelHandler;
import app.dn.channels.handlers.channel_handler : ChannelHandler;
import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import app.dn.channels.contexts.channel_context : ChannelContext;

import app.dn.pools.linear_pool : LinearPool;
import app.core.mem.buffers.static_buffer : StaticBuffer;

import app.core.utils.sync : MutexLock, mLock;

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

struct StompOutCommand
{
    StompCommand command = StompCommand.CONNECT;
    FdChannel* chan;
    FrameStaticBuffer buffer;
    long lastReadTimestamp;
    long lastWriteTimestamp;
}

/**
 * Authors: initkfs
 */
class StompHandler : BufferedChannelHandler!(StompOutCommand*)
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
            with (mLock(bufferMutex))
            {
                auto currTimestamp = timestamp;
                foreach (i; 0 .. outBuffers.length)
                {
                    auto cmd = outBuffers.get(i);
                    if (cmd.command == StompCommand.CONNECT)
                    {
                        continue;
                    }

                    if (currTimestamp > cmd.lastWriteTimestamp)
                    {
                        auto writeDt = currTimestamp - cmd.lastWriteTimestamp;
                        if (writeDt > 10)
                        {
                            writeln("Write timeout");
                            //TODO unsafe
                            cmd.command = StompCommand.CONNECT;
                            ChanOutEvent outEvent;
                            outEvent.chan = cmd.chan;
                            outEvent.setClose;
                            sendSync(outEvent);
                        }
                    }

                }
            }
        });

        timer.start;
    }

    override protected StompOutCommand* newBuffer()
    {
        import core.stdc.stdlib : malloc, realloc, free;

        auto newBuff = malloc(StompOutCommand.sizeof);
        if (!newBuff)
        {
            return null;
        }
        auto frame = cast(StompOutCommand*) newBuff;
        *frame = StompOutCommand.init;
        return frame;
    }

    override void onAccepted(ChannelContext ctx)
    {
        auto cmd = getBuffer(ctx.inEvent.chan.fd);
        cmd.chan = ctx.inEvent.chan;

        ctx.outEvent.setRead;
        sendSync(ctx.outEvent);
    }

    override void onReadStart(ChannelContext ctx)
    {
        bufferMutex.lock;
        scope (exit)
        {
            bufferMutex.unlock;
        }

        ubyte[] chanBuff = ctx.inEvent.chan.readableBytes;
        if (chanBuff.length > 0 || chanBuff[0] == '\0')
        {
            decoder.decode(chanBuff);

            auto outBuffer = getBuffer(ctx.inEvent.chan.fd);
            if (!outBuffer)
            {
                //TODO disconnect
                throw new Exception("Buffer not found");
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
                    if (outBuffer.command == CONNECT)
                    {
                        sendConnected(outBuffer, ctx);
                    }
                    else
                    {
                        sendError(outBuffer, ctx, "Invalid state on connect");
                    }
                    break;
                case SUBSCRIBE:
                    if (outBuffer.command == CONNECTED)
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
            writeln("Continue reading");
            ctx.outEvent.setRead;
            sendSync(ctx.outEvent);
        }
    }

    protected void sendFrame(StompOutCommand* cmd, ChannelContext ctx)
    {
        cmd.lastWriteTimestamp = timestamp;

        ctx.inEvent.chan.resetBufferIndices;

        ctx.outEvent.setWrite;
        ctx.outEvent.buffer = cast(ubyte[])(*cmd).buffer[];
        sendSync(ctx.outEvent);
    }

    protected void sendConnected(StompOutCommand* cmd, ChannelContext ctx)
    {
        auto errorFrame = encoder.connected;
        cmd.command = StompCommand.CONNECTED;
        encoder.decode!(frameBufferLength)(errorFrame, (*cmd).buffer);
        sendFrame(cmd, ctx);
    }

    protected void sendError(StompOutCommand* cmd, ChannelContext ctx, const(char)[] message = "Unknown error")
    {
        auto errorFrame = encoder.error(message);
        cmd.command = StompCommand.ERROR;
        encoder.decode!(frameBufferLength)(errorFrame, (*cmd).buffer);

        sendFrame(cmd, ctx);
    }

    protected void sendMessage(StompOutCommand* cmd, ChannelContext ctx, const(char)[] message = "Message", const(
            char)[] dest = "/", const(char)[] messageId = "0", const(char)[] subscription = "0")
    {
        auto frame = encoder.message(message, dest, messageId, subscription);
        cmd.command = StompCommand.MESSAGE;
        encoder.decode!(frameBufferLength)(frame, (*cmd).buffer);

        sendFrame(cmd, ctx);
    }

    protected void sendDisconnect(StompOutCommand* cmd, ChannelContext ctx)
    {
        auto frame = encoder.disconnect;
        cmd.command = StompCommand.DISCONNECT;
        encoder.decode!(frameBufferLength)(frame, (*cmd).buffer);

        sendFrame(cmd, ctx);
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
        bufferMutex.lock;
        scope (exit)
        {
            bufferMutex.unlock;
        }

        auto buffer = getBuffer(ctx.inEvent.chan.fd);
        assert(buffer);

        if (buffer.command == StompCommand.DISCONNECT || buffer.command == StompCommand.ERROR)
        {
            ctx.outEvent.setClose;
            ctx.send;
            return;
        }

        //TODO read?
        if (buffer.command == StompCommand.MESSAGE)
        {
            return;
        }

        ctx.inEvent.chan.resetBufferIndices;
        ctx.outEvent.setRead;
        sendSync(ctx.outEvent);
    }

    override void onClosed(ChannelContext ctx)
    {
        bufferMutex.lock;
        scope (exit)
        {
            bufferMutex.unlock;
        }

        auto buffer = getBuffer(ctx.inEvent.chan.fd);
        assert(buffer);
        //TODO separate state?
        buffer.command = StompCommand.CONNECT;
    }

}
