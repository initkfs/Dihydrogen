module api.dn.protocols.http1.handlers.webroot_http_handler;

import api.core.loggers.logging : Logging;

import api.dn.protocols.http1.handlers.http_handler : HttpHandler;

import api.dn.channels.handlers.channel_handler : ChannelHandler;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.contexts.channel_context : ChannelContext;

import api.dn.protocols.http1.http_common;
import api.dn.protocols.http1.static_http_decoder : StaticHttpDecoder, DecoderState;

/**
 * Authors: initkfs
 */
class WebrootHttpHandler : HttpHandler
{
    string webroot;

    char[256] uri;
    size_t uriLen;

    char[256] buffer;
    char[256] buffer2;
    char[] targetFile;

    ubyte[][string] fileMap;

    string indexFile = "index.html";
    string indexUri = "/";

    this(string root, Logging logging)
    {
        super(logging);
        assert(root.length > 0);

        import std.path : isAbsolute, absolutePath;

        this.webroot = root.isAbsolute ? root : root.absolutePath;
    }

    override void onReadStart(ChannelContext ctx)
    {
        ubyte[] chanBuff = ctx.inEvent.chan.readableBytes;
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
                //ctx.outEvent.setWrite;
                //ctx.outEvent.buffer = cast(ubyte[]) responseErr;
                //ctx.send;
                //ctx.outEvent.setClose;
                //ctx.send;
                return;
            }

            if (decoder.uriSlice.length > 0 && decoder.uriSlice.length <= uri.length)
            {
                uri[0 .. decoder.uriSlice.length] = decoder.uriSlice;
                uriLen = decoder.uriSlice.length;
            }
            else
            {
                uriLen = 0;
            }
        }

        import std.algorithm.searching : startsWith;
        import api.dn.sys.fs : realpath;
        import std.string : fromStringz;
        import std.stdio : writeln;

        const char[] rawUriSlice = uri[0 .. uriLen];
        if (rawUriSlice.length == 0)
        {
            logging.logger.error("URI slice is empty");
            return;
        }

        assert(indexFile.length > 0);
        const uriSlice = rawUriSlice == indexUri ? indexFile : rawUriSlice; 

        import std.format : sformat;

        char[] filePath = sformat(buffer, "%s/%s\0", webroot, uriSlice);

        auto result = realpath(filePath.ptr, buffer2.ptr);
        if (result is null)
        {
            import api.core.utils.text : escapeunw;

            logging.logger.error("Realpath error: ", escapeunw(filePath));
            return;
        }

        auto path = result.fromStringz;

        import std;
        writeln("Path: |", path, "|", "web root: |", webroot, "|");

        if (!path.startsWith(webroot))
        {
            import api.core.utils.text : escapeunw;

            logging.logger.error("URI path is not in webroot: ", escapeunw(path));
            return;
        }

        targetFile = path;

        ubyte[] fileContent;

        if (auto filePtr = path in fileMap)
        {
            fileContent = *filePtr;
        }
        else
        {
            import std.file : read;
            import std.conv : to;

            import std.algorithm.searching : endsWith;

            auto content = cast(ubyte[]) path.read;
            string contentLen = content.length.to!string;

            string mimeType;
            if (path.endsWith(".png"))
            {
                mimeType = "image/png";
            }
            else if (path.endsWith(".js"))
            {
                mimeType = "text/javascript";
            }
            else if (path.endsWith(".ico"))
            {
                mimeType = "image/vnd.microsoft.icon";
            }
            else if (path.endsWith(".css"))
            {
                mimeType = "text/css";
            }
            else if (path.endsWith(".html"))
            {
                mimeType = "text/html";
            }
            else
            {
                mimeType = "text/plain";
            }

            string headerLine = "HTTP/1.1 200 OK\r\n" ~ mimeType ~"\r\nContent-Length: " ~ contentLen ~ "\r\nConnection: close\r\n\r\n";

            content = (cast(ubyte[]) headerLine.dup) ~ content;

            fileMap[path.idup] = content;
            fileContent = content;
        }

        ctx.outEvent.setWrite;
        ctx.outEvent.buffer = cast(ubyte[]) fileContent;
        ctx.send;

        //ctx.outEvent.setWrite;
        //ctx.outEvent.buffer = cast(ubyte[]) response;
        //ctx.send;
    }

    override void onReadEnd(ChannelContext ctx)
    {

        if (next)
        {
            next.onReadEnd(ctx);
        }
    }

}
