module api.dn.protocols.http1.handlers.http_handler;

import api.dn.channels.fd_channel : FdChannel, FdChannelType;

import api.dn.channels.handlers.channel_handler : ChannelHandler;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.contexts.channel_context : ChannelContext;

import api.dn.protocols.http1.http_common;
import api.dn.protocols.http1.static_http_decoder : StaticHttpDecoder, DecoderState;

debug import std.stdio : writeln, writefln;

/**
 * Authors: initkfs
 */
class HttpHandler : ChannelHandler
{
    ubyte[2048] buff;

    char[] response = "HTTP/1.1 200 OK\r\nContent-Length: 13\r\nConnection: close\r\n\r\nHello, world!"
        .dup;

    StaticHttpDecoder decoder;

    this()
    {
        decoder = new StaticHttpDecoder;
    }

    override void onAccepted(ChannelContext ctx)
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
            if(decoder.state != DecoderState.end){
                ctx.outEvent.setClose;
                ctx.send;
                return;
            }
        }

        ctx.outEvent.setWrite;
        ctx.outEvent.buffer = cast(ubyte[]) response;
        ctx.send;
    }

    override void onReadEnd(ChannelContext ctx)
    {
        writeln("Read end");
        ctx.outEvent.setWrite;
        ctx.outEvent.buffer = cast(ubyte[]) response;
        ctx.send;
    }

    override void onWrote(ChannelContext ctx)
    {
        ctx.outEvent.setClose;
        ctx.send;
    }

    override void onClosed(ChannelContext ctx)
    {
        //import std.stdio;
        //writefln("Close: %s", ctx.channel.fd);
    }

}

// unittest {
//     auto httpHandler = new HttpHandler;
//     ubyte[] buffer = cast(ubyte[]) "GET /hello/world HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\nmessage\0".dup;
//     httpHandler.decode(buffer);
// }
