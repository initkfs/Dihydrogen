module api.dn.protocols.http1.handlers.http_handler;

import api.dn.channels.fd_channel : FdChannel, FdChannelType;

import api.core.loggers.logging : Logging;

import api.dn.channels.handlers.channel_handler : ChannelHandler;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.contexts.channel_context : ChannelContext;

import api.dn.protocols.http1.http_common;
import api.dn.protocols.http1.static_http_req_decoder : StaticHttpReqDecoder, DecoderState;

debug import std.stdio : writeln, writefln;

/**
 * Authors: initkfs
 */
class HttpHandler : ChannelHandler
{
    Logging logging;

    StaticHttpReqDecoder decoder;

    this(Logging logging)
    {
        this.logging = logging;
        decoder = new StaticHttpReqDecoder;
    }

    override void onAcceptEnd(ChannelContext ctx)
    {
        ctx.outEvent.setRead;
        ctx.send;
    }

    protected void decode(ubyte[] buff)
    {
        decoder.decode(buff);
    }

    override void onReadStart(ChannelContext ctx)
    {
        ubyte[] chanBuff = ctx.inEvent.chan.readableBytes;
        if (chanBuff.length > 0 || chanBuff[0] == '\0')
        {
            decode(chanBuff);
            if (decoder.state != DecoderState.end && decoder.state != DecoderState
                .errorNoHeadersNoBody)
            {
                import std;

                debug writeln("HTTP decoder error: ", decoder.state);
                ctx.outEvent.setRead;
                ctx.send;
                //ctx.outEvent.setWrite;
                //ctx.outEvent.buffer = cast(ubyte[]) responseErr;
                //ctx.send;
                //ctx.outEvent.setClose;
                //ctx.send;
                return;
            }
        }

        ctx.outEvent.setRead;
        ctx.send;

        //ctx.outEvent.setWrite;
        //ctx.outEvent.buffer = cast(ubyte[]) response;
        //ctx.send;
    }

    override void onReadEnd(ChannelContext ctx)
    {
        //loop
        //ctx.outEvent.setRead;
        //ctx.send;

        //ubyte[] res = ctx.inEvent.chan.readableBytes;

        import HttpResp = api.dn.protocols.http1.http_responses;

        ctx.outEvent.setWrite;
        ctx.outEvent.chan.outb.slice = cast(ubyte[]) HttpResp._html;
        ctx.send;
    }

    override void onReadError(ChannelContext ctx)
    {
        import std;

        writeln("Read error");
        //loop
        //ctx.outEvent.setRead;
        //ctx.send;

        //ctx.outEvent.setWrite;
        //ctx.outEvent.buffer = cast(ubyte[]) response;
        //ctx.send;
    }

    override void onWriteEnd(ChannelContext ctx)
    {
        ctx.outEvent.setClose;
        ctx.send;
    }

    override void onCloseEnd(ChannelContext ctx)
    {
        //import std.stdio;
        //writefln("Close: %s", ctx.channel.fd);
    }

    void sendRead(ref ChannelContext ctx)
    {
        ctx.outEvent.setRead;
        ctx.send;
    }

    void sendWrite(ref ChannelContext ctx){
        ctx.outEvent.setWrite;
        ctx.send;
    }
    
    void sendClose(ref ChannelContext ctx)
    {
        ctx.outEvent.setClose;
        ctx.send;
    }

}
