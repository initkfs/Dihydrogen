module app.dn.channels.handlers.channel_handler;

import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.commands.channel_context : ChannelCommand;
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

    void onAccept(ChannelContext ctx)
    {
        ctx.inCmd.setRead;
        ctx.run;
    }

    void onRead(ChannelContext ctx)
    {
        ctx.inCmd.setWrite;
        ctx.inCmd.buff = cast(ubyte*) response.ptr;
        ctx.inCmd.buffLen = response.length;
        ctx.run;
    }

    void onReadEnd(ChannelContext ctx)
    {
        ctx.inCmd.setWrite;
        ctx.inCmd.buff = cast(ubyte*) response.ptr;
        ctx.inCmd.buffLen = response.length;
        ctx.run;
    }

    void onWrite(ChannelContext ctx)
    {
        ctx.inCmd.setClose;
        ctx.run;
    }

    void onClose(ChannelContext ctx)
    {
        //import std.stdio;
        //writefln("Close: %s", ctx.channel.fd);
    }

}
