module app.dn.protocols.http.handlers.http_handler;

import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.handlers.channel_handler: ChannelHandler;
import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import app.dn.channels.contexts.channel_context : ChannelContext;

/**
 * Authors: initkfs
 */
class HttpHandler : ChannelHandler
{
    ubyte[2048] buff;

    char[] response = "HTTP/1.1 200 OK\r\nContent-Length: 13\r\nConnection: close\r\n\r\nHello, world!".dup;

    override void onAccepted(ChannelContext ctx)
    {
        ctx.outEvent.setRead;
        ctx.send;
    }

    override void onReadStart(ChannelContext ctx)
    {
        ctx.outEvent.setWrite;
        ctx.outEvent.buffer = cast(ubyte[]) response;
        ctx.send;
    }

    override void onReadEnd(ChannelContext ctx)
    {
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
