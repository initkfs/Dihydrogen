module api.dn.protocols.stomp.handlers.stomp_handler;

import api.dn.channels.fd_channel : FdChannel, FdChannelType;

import api.dn.channels.handlers.buffered_channel_handler : BufferedChannelHandler;
import api.dn.channels.handlers.channel_handler : ChannelHandler;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.contexts.channel_context : ChannelContext;

import api.dn.pools.linear_pool : LinearPool;
import api.core.mem.buffers.static_buffer : StaticBuffer;

import api.core.utils.sync : MutexLock;

import api.dn.protocols.stomp.stomp_common;
import api.dn.protocols.stomp.static_stomp_decoder : StaticStompDecoder, DecoderState;
import api.dn.protocols.stomp.static_stomp_encoder : StaticStompEncoder;

debug import std.stdio : writeln, writefln;

import core.thread : Thread;
import core.sync.mutex;

class Timer : Thread
{
    private {
        void delegate() onRun;
    }

    this(void delegate() onRun)
    {
        import core.atomic : atomicStore;

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

    StaticStompDecoder decoder;
    StaticStompEncoder!(10, 256, 256, 256) encoder;

    this()
    {
        super(bufferInitialLength);

        decoder = new StaticStompDecoder;
        encoder = new StaticStompEncoder!(10, 256, 256, 256);

        timer = new Timer(() {
            auto currTimestamp = timestamp;
            onOutBuffers((OutBufferData* data) {

                return true;
            });
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
        synchronized (outBuffers)
        {
            OutBufferData* buffData;
            if (!getOutBuffer(ctx.inEvent.chan.fd, buffData))
            {
                //TODO logging;
                return;
            }
            buffData.chan = ctx.inEvent.chan;

            ctx.outEvent.setRead;
            ctx.send;
        }
    }

    override void onReadStart(ChannelContext ctx)
    {
        synchronized (outBuffers)
        {
            ubyte[] chanBuff = ctx.inEvent.chan.readableBytes;
            if (chanBuff.length > 0 || chanBuff[0] == '\0')
            {
                decoder.decode(chanBuff);

                OutBufferData* outBuffer;
                if (!getOutBuffer(ctx.inEvent.chan.fd, outBuffer))
                {
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
                            outBuffer.state = CONNECTED;
                            sendConnected(outBuffer, ctx);
                        }
                        else
                        {
                            outBuffer.state = ERROR;
                            sendError(outBuffer, ctx, "Invalid state on connect");
                        }
                        break;
                    case SUBSCRIBE:
                        if (outBuffer.state == CONNECTED)
                        {
                            auto mustBeReceiptHeader = decoder.hasHeader(
                                StompDefaultHeader.receipt);
                            if (mustBeReceiptHeader)
                            {
                                if (mustBeReceiptHeader.value.length <= encoder.headerValueLength)
                                {
                                    auto receiptFrame = encoder.receipt(
                                        mustBeReceiptHeader.value[]);
                                    encoder.decode!(frameBufferLength)(receiptFrame, (*outBuffer)
                                            .buffer);
                                    sendFrame(outBuffer, ctx);
                                }
                            }
                        }
                        else
                        {
                            outBuffer.state = ERROR;
                            sendError(outBuffer, ctx, "Invalid state for subscribe");
                        }
                        break;
                    case SEND:
                        sendMessage(outBuffer, ctx, "SEND received");
                        break;
                    case DISCONNECT:
                        auto mustBeReceiptHeader = decoder.hasHeader(StompDefaultHeader.receipt);
                        if (!mustBeReceiptHeader)
                        {
                            //TODO error?
                        }
                        else
                        {
                            //TODO validate?
                            size_t headerValueLen = mustBeReceiptHeader.value.length;
                            if (headerValueLen > encoder.headerValueLength)
                            {
                                //TODO error;
                            }
                            else
                            {
                                auto receiptFrame = encoder.receipt(mustBeReceiptHeader.value[]);
                                encoder.decode!(frameBufferLength)(receiptFrame, (*outBuffer)
                                        .buffer);
                                sendFrame(outBuffer, ctx);

                                outBuffer.state = DISCONNECT;

                                ctx.outEvent.setClose;
                                ctx.send;
                            }

                        }
                        break;
                    default:
                        outBuffer.state = ERROR;
                        sendError(outBuffer, ctx, "Unsupported command");
                        break;
                }
            }
            else
            {
                //writeln("Continue reading");
                ctx.outEvent.setRead;
                ctx.send;
            }
        }
    }

    protected void sendFrame(OutBufferData* bufferData, ChannelContext ctx)
    {
        bufferData.lastWriteTimestamp = timestamp;

        ctx.inEvent.chan.resetBufferIndices;

        ctx.outEvent.setWrite;
        ctx.outEvent.buffer = cast(ubyte[])(*bufferData).buffer[];
        ctx.send;
    }

    protected void sendConnected(OutBufferData* bufferData, ChannelContext ctx)
    {
        auto errorFrame = encoder.connected;
        encoder.decode!(frameBufferLength)(errorFrame, (*bufferData).buffer);
        sendFrame(bufferData, ctx);
    }

    protected void sendError(OutBufferData* bufferData, ChannelContext ctx, const(char)[] message = "Unknown error")
    {
        auto errorFrame = encoder.error(message);
        encoder.decode!(frameBufferLength)(errorFrame, (*bufferData).buffer);

        sendFrame(bufferData, ctx);
        ctx.outEvent.setClose;
        ctx.send;
    }

    protected void sendMessage(OutBufferData* bufferData, ChannelContext ctx, const(char)[] message = "Message", const(
            char)[] dest = "/", const(char)[] messageId = "0", const(char)[] subscription = "0")
    {
        auto frame = encoder.message(message, dest, messageId, subscription);
        encoder.decode!(frameBufferLength)(frame, (*bufferData).buffer);

        sendFrame(bufferData, ctx);
    }

    protected void sendDisconnect(OutBufferData* bufferData, ChannelContext ctx)
    {
        auto frame = encoder.disconnect;
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
        synchronized (outBuffers)
        {
            OutBufferData* buffer;
            if (!getOutBuffer(ctx.inEvent.chan.fd, buffer))
            {
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
            // if (buffer.state == StompCommand.MESSAGE)
            // {
            //     return;
            // }

            ctx.inEvent.chan.resetBufferIndices;
            ctx.outEvent.setRead;
            ctx.send;
        }

    }

    override void onClosed(ChannelContext ctx)
    {
        synchronized (outBuffers)
        {
            OutBufferData* bufferData;
            if (!getOutBuffer(ctx.inEvent.chan.fd, bufferData))
            {
                //TODO logging
                return;
            }
            //TODO separate state?
            bufferData.state = StompCommand.CONNECT;
        }
    }

}
