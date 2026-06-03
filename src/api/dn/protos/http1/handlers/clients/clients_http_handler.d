module api.dn.protos.http1.handlers.clients.clients_http_handler;

import api.dn.channels.fd_channel : FdChannel, FdChannelType;

import api.core.loggers.logging : Logging;

import api.dn.handlers.channel_handler : ChannelHandler;
import api.dn.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.channel_context : ChannelContext;

import api.dn.protos.http1.http_common;
import api.dn.protos.http1.static_http_resp_decoder : StaticHttpRespDecoder, DecoderState;

debug import std.stdio : writeln, writefln;

/**
 * Authors: initkfs
 */
class ClientHttpHandler : ChannelHandler
{
    Logging logging;

    StaticHttpRespDecoder decoder;

    this(Logging logging)
    {
        this.logging = logging;
        decoder = new StaticHttpRespDecoder;
    }

    override void onConnect(ChannelContext ctx)
    {
        import HTTPReq = api.dn.protos.http1.http_requests;

        ctx.outEvent.chan.outb.buff = cast(ubyte[]) HTTPReq.get("localhost");
        sendWrite(ctx);
    }

    override void onReadStart(ChannelContext ctx)
    {
        ubyte[] chanBuff = ctx.inEvent.chan.readableBytes;
        if (chanBuff.length > 0)
        {
            decoder.decode(chanBuff);
            if (decoder.state != DecoderState.end && decoder.state != DecoderState.errorNoBody)
            {
                debug writeln("HTTP decoder error: ", decoder.state);
                return;
            }
        }
    }

    override void onReadEnd(ChannelContext ctx)
    {
        
    }

    override void onWriteEnd(ChannelContext ctx)
    {
        ctx.outEvent.setRead;
        ctx.send;
    }

    void sendRead(ref ChannelContext ctx)
    {
        ctx.outEvent.setRead;
        ctx.send;
    }

    void sendWrite(ref ChannelContext ctx)
    {
        ctx.outEvent.setWrite;
        ctx.send;
    }

    void sendClose(ref ChannelContext ctx)
    {
        ctx.outEvent.setClose;
        ctx.send;
    }

}
