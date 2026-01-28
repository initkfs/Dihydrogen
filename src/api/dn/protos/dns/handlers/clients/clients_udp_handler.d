module api.dn.protos.dns.handlers.clients.clients_udp_handler;

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
class ClientUdpHandler : ChannelHandler
{
    Logging logging;

    this(Logging logging)
    {
        this.logging = logging;
    }

    override void onConnect(ChannelContext ctx)
    {
        ctx.outEvent.chan.outb.slice = simpleDNSQuery;
        ctx.outEvent.setWrite;
        ctx.send;
    }

    ubyte[] simpleDNSQuery()
    {
        // ID = 0x1234
        //  A
        ubyte[31] packet = [
            // Header
            0x12, 0x34, // ID = 0x1234
            0x01, 0x00, // Flags: RD=1
            0x00, 0x01, // Questions = 1
            0x00, 0x00, // Answer RRs = 0
            0x00, 0x00, // Authority RRs = 0
            0x00, 0x00, // Additional RRs = 0

            // Question: google.com
             0x09, // "length"
            'w', 'i', 'k', 'i', 'p', 'e', 'd', 'i', 'a',
            0x03, // "com length"
            'o', 'r', 'g',
            0x00, //

            // QTYPE и QCLASS
            0x00, 0x01, // QTYPE = A (1)
            0x00,
            0x01 // QCLASS = IN (1)
        ];

        return packet.dup;
    }

    override void onReadStart(ChannelContext ctx)
    {
        ubyte[] chanBuff = ctx.inEvent.chan.readableBytes;
        if (chanBuff.length > 0)
        {
            import std;
            writeln(chanBuff);
        }
    }

    void decodeDNS(ubyte[]){

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
