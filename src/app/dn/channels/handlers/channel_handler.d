module app.dn.channels.handlers.channel_handler;

import app.dn.channels.fd_channel : FdChannel, FdChannelType;

import app.dn.channels.commands.channel_context : ChannelCommand;

/**
 * Authors: initkfs
 */
class ChannelHandler
{
    ChannelHandler prev;
    ChannelHandler next;

    ubyte[2048] buff;

    static response = "HTTP/1.1 200 OK\r\nContent-Length: 13\r\nConnection: close\r\n\r\nHello, world!";

    void onAccept(ChannelCommand inCmd, void delegate(ChannelCommand) onOutCmd)
    {
        inCmd.setRead;
        onOutCmd(inCmd);
    }

    void onRead(ChannelCommand inCmd, void delegate(ChannelCommand) onOutCmd)
    {
        inCmd.setWrite;
        inCmd.buff = cast(ubyte*) response.ptr;
        inCmd.buffLen = response.length;
        onOutCmd(inCmd);
    }

    void onReadEnd(ChannelCommand inCmd, void delegate(ChannelCommand) onOutCmd)
    {
        inCmd.setWrite;
        inCmd.buff = cast(ubyte*) response.ptr;
        inCmd.buffLen = response.length;
        onOutCmd(inCmd);
    }

    void onWrite(ChannelCommand inCmd, void delegate(ChannelCommand) onOutCmd)
    {
        inCmd.setClose;
        onOutCmd(inCmd);
    }

    void onClose(ChannelCommand inCmd, void delegate(ChannelCommand) onOutCmd)
    {
        //import std.stdio;
        //writefln("Close: %s", ctx.channel.fd);
    }

}
