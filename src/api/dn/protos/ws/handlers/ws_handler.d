module api.dn.protos.ws.handlers.ws_handler;

import api.dn.protos.http1.handlers.http_handler : HttpHandler;
import api.core.loggers.logging : Logging;
import api.dn.channels.channel_context : ChannelContext;
import api.dn.protos.http1.http_common;
import api.dn.protos.http1.static_http_req_decoder : StaticHttpReqDecoder, DecoderState;

import std.digest.sha;
import api.dn.protos.ws.ws_common;
import WsCodec = api.dn.protos.ws.ws_codec;

/*
 * Authors: initkfs
 */

class WSHandler : HttpHandler
{
    SHA1Digest sha;

    bool isOpen;

    this(Logging logging)
    {
        super(logging);
        decoder.isStrictHeaders = false;
        sha = new SHA1Digest;
    }

    override void onReadStart(ChannelContext ctx)
    {
        ubyte[] chanBuff = ctx.inEvent.chan.readableBytes;

        if (isOpen)
        {
            auto wsFrame = WsCodec.decode(chanBuff);

            auto text = cast(string) wsFrame.payload.dup;

            auto frame = WsCodec.encode(WsCodec.createTextFrame(text));
            ctx.inEvent.chan.resetBufferIndices;
            ctx.outEvent.setWrite;
            ctx.outEvent.chan.outb.buff = frame;
            ctx.send;

            return;
        }

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
                return;
            }
        }

        auto headers = decoder.parseHeadersKeyValues;

        if (headerSecWebSocketVersion !in headers)
        {
            return;
        }

        if (headerSecWebSocketKey !in headers)
        {
            return;
        }

        //Upgrade: websocket
        //Connection: Upgrade
        auto wsKey = headers[headerSecWebSocketKey];
        //check is  13
        auto wsVersion = headers[headerSecWebSocketVersion];

        if (wsKey.length != secWebSocketKeyLength)
        {
            return;
        }

        auto acceptKey = calcAcceptKey(wsKey);

        import std.format : format;

        string response = format("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n", acceptKey);

        isOpen = true;
        ctx.inEvent.chan.resetBufferIndices;
        ctx.outEvent.setWrite;
        ctx.outEvent.chan.outb.buff = cast(ubyte[]) response;
        ctx.send;
    }

    override void onReadEnd(ChannelContext ctx)
    {

    }

    override void onWriteEnd(ChannelContext ctx)
    {
        if (isOpen)
        {
            ctx.outEvent.setRead;
            ctx.send;
        }
    }

    char[] calcAcceptKey(string wsKey)
    {
        import std.base64;
        import std.string : representation;

        ubyte[secWebSocketKeyLength + guid.length] keyunion;
        keyunion[0 .. wsKey.length] = wsKey.representation;
        keyunion[wsKey.length .. $] = guid.representation;

        ubyte[] digest = sha.digest(keyunion);
        return Base64.encode(digest);
    }
}
