module dn.channels.handlers.channel_handler;

import dn.channels.fd_channel : FdChannel, FdChannelType;

import dn.channels.contexts.channel_context : ChannelContext;

/**
 * Authors: initkfs
 */
class ChannelHandler
{
    ChannelHandler prev;
    ChannelHandler next;

    ubyte[2048] buff;

    static response = "HTTP/1.1 200 OK\r\nContent-Length: 13\r\nConnection: close\r\n\r\nHello, world!";

    void onAccept(ref ChannelContext ctx)
    {
        ctx.read;
    }

    void onRead(ref ChannelContext ctx)
    {
        //ctx.read
        ctx.buff = cast(ubyte*) response.ptr;
        ctx.buffLen = response.length;
        ctx.write;
    }

    void onReadComplete(ref ChannelContext ctx)
    {
        ctx.buff = cast(ubyte*) response.ptr;
        ctx.buffLen = response.length;
        ctx.write;
    }

    void onWrite(ref ChannelContext ctx)
    {
        ctx.close;
    }

    void onClose(ref ChannelContext ctx)
    {

    }

}
