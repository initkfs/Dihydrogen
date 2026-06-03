module api.dn.protos.http1.handlers.clients.clients_http_handler;

import api.dn.chans.fd_chan : FdChan, FdChanType;

import api.core.loggers.logging : Logging;

import api.dn.handlers.channel_handler : ChannelHandler;
import api.dn.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.chans.chan_context : ChanContext;

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

    override void onConnect(ChanContext ctx)
    {
        import HTTPReq = api.dn.protos.http1.http_requests;

        ctx.outEvent.chan.outb.buff = cast(ubyte[]) HTTPReq.get("localhost");
        sendWrite(ctx);
    }

    override void onReadStart(ChanContext ctx)
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

    override void onReadEnd(ChanContext ctx)
    {
        
    }

    override void onWriteEnd(ChanContext ctx)
    {
        ctx.outEvent.setRead;
        ctx.send;
    }

    void sendRead(ref ChanContext ctx)
    {
        ctx.outEvent.setRead;
        ctx.send;
    }

    void sendWrite(ref ChanContext ctx)
    {
        ctx.outEvent.setWrite;
        ctx.send;
    }

    void sendClose(ref ChanContext ctx)
    {
        ctx.outEvent.setClose;
        ctx.send;
    }

}
