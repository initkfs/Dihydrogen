module app.dn.protocols.stomp.handlers.stomp_handler;

import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.handlers.channel_handler : ChannelHandler;
import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import app.dn.channels.contexts.channel_context : ChannelContext;

import app.dn.pools.linear_pool : LinearPool;
import app.core.mem.buffers.static_buffer : StaticBuffer;

import app.dn.protocols.stomp.stomp_common;
import app.dn.protocols.stomp.stomp_decoder : StompDecoder, DecoderState;
import app.dn.protocols.stomp.stomp_encoder : StompEncoder;

debug import std.stdio : writeln, writefln;

/**
 * Authors: initkfs
 */
class StompHandler : ChannelHandler
{
    enum bufferInitialLength = 1024;
    enum frameBufferLength = 1024;

    alias FrameStaticBuffer = StaticBuffer!(char, frameBufferLength, true);

    struct StompOutCommand
    {
        StompCommand command = StompCommand.CONNECT;
        FrameStaticBuffer buffer;
    }

    LinearPool!(StompOutCommand*) outBuffers;

    StompDecoder decoder;
    StompEncoder!(10, 256, 256, 256) encoder;

    this()
    {
        decoder = new StompDecoder;
        encoder = new StompEncoder!(10, 256, 256, 256);

        outBuffers = new LinearPool!(StompOutCommand*)(bufferInitialLength);

        outBuffers.create;

        //TODO move from constructor
        foreach (i; 0 .. outBuffers.length)
        {
            auto newBuf = newBuffer;
            if (!newBuf)
            {
                import std.conv : to;

                throw new Exception(
                    "Output buffers initialization error, buffer not found with index: " ~ i
                        .to!string);
            }
            outBuffers.set(i, newBuffer);
        }
    }

    protected StompOutCommand* newBuffer()
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

    StompOutCommand* getBuffer(int fd)
    {
        if (fd < 0)
        {
            return null;
        }

        while (!outBuffers.hasIndex(fd))
        {
            if (!outBuffers.increase)
            {
                return null;
            }
        }
        return outBuffers.get(fd);
    }

    override void onAccepted(ChannelContext ctx)
    {
        ctx.outEvent.setRead;
        ctx.send;
    }

    override void onReadStart(ChannelContext ctx)
    {
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

            if (decoder.state != DecoderState.endFrame)
            {
                sendError(outBuffer, ctx, "Invalid STOMP frame");
                return;
            }

            switch (decoder.command) with (StompCommand)
            {
                case CONNECT:
                    if(outBuffer.command == CONNECT){
                        sendConnected(outBuffer, ctx);
                    }else {
                        sendError(outBuffer, ctx, "Invalid state on connect");
                    }
                    break;
                case SUBSCRIBE:
                     if(outBuffer.command == CONNECTED){
                        sendMessage(outBuffer, ctx);
                     }else {
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
            ctx.send;
        }
    }

    protected void sendFrame(StompOutCommand* cmd, ChannelContext ctx)
    {
        ctx.inEvent.chan.resetBufferIndices;

        ctx.outEvent.setWrite;
        ctx.outEvent.buffer = cast(ubyte[])( * cmd).buffer[];
        ctx.send;
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

    protected void sendMessage(StompOutCommand* cmd, ChannelContext ctx, const(char)[] message = "Message", const(char)[] dest = "/", const(char)[] messageId = "0", const(char)[] subscription = "0")
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
        auto buffer = getBuffer(ctx.inEvent.chan.fd);
        assert(buffer);

        if (buffer.command == StompCommand.DISCONNECT || buffer.command == StompCommand.ERROR)
        {
            ctx.outEvent.setClose;
            ctx.send;
            return;
        }

        //TODO read?
        if(buffer.command == StompCommand.MESSAGE){
            return;
        }

        ctx.inEvent.chan.resetBufferIndices;
        ctx.outEvent.setRead;
        ctx.send;
    }

    override void onClosed(ChannelContext ctx)
    {
        auto buffer = getBuffer(ctx.inEvent.chan.fd);
        assert(buffer);
        //TODO separate state?
        buffer.command = StompCommand.CONNECT;
    }

}
