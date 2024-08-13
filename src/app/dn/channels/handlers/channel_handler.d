module app.dn.channels.handlers.channel_handler;

import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import app.dn.channels.contexts.channel_context : ChannelContext;

/**
 * Authors: initkfs
 */
class ChannelHandler
{
    ChannelHandler prev;
    ChannelHandler next;

    ubyte[2048] buff;

    static response = "HTTP/1.1 200 OK\r\nContent-Length: 13\r\nConnection: close\r\n\r\nHello, world!";

    void onAccepted(ChannelContext ctx)
    {
        ctx.outEvent.setRead;
        ctx.send;
    }

    void onReadStart(ChannelContext ctx)
    {
        ctx.outEvent.setWrite;
        ctx.outEvent.buff = cast(ubyte*) response.ptr;
        ctx.outEvent.buffLen = response.length;
        ctx.send;
    }

    void onReadEnd(ChannelContext ctx)
    {
        ctx.outEvent.setWrite;
        ctx.outEvent.buff = cast(ubyte*) response.ptr;
        ctx.outEvent.buffLen = response.length;
        ctx.send;
    }

    void onWrote(ChannelContext ctx)
    {
        ctx.outEvent.setClose;
        ctx.send;
    }

    void onClosed(ChannelContext ctx)
    {
        //import std.stdio;
        //writefln("Close: %s", ctx.channel.fd);
    }

}
