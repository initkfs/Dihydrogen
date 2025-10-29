module api.dn.protocols.http1.handlers.webroot_https_handler;

import api.core.loggers.logging : Logging;

import api.dn.protocols.http1.handlers.http_handler : HttpHandler;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.contexts.channel_context : ChannelContext;

import api.dn.protocols.http1.http_common;
import api.dn.protocols.http1.static_http_decoder : StaticHttpDecoder, DecoderState;

import std.string : fromStringz, toStringz;

import openssl_libs;

import std : writeln;

/**
 * Authors: initkfs
 */
class WebrootHttpsHandler : HttpHandler
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

    Logging logging;

    this(string root, Logging logging)
    {
        super(logging);
        this.logging = logging;
        assert(root.length > 0);

        import std.path : isAbsolute, absolutePath;

        this.webroot = root.isAbsolute ? root : root.absolutePath;
    }

    override void onAcceptEnd(ChannelContext ctx)
    {
        logging.logger.trace("Accept connection: ", sslState(ctx));
        ctx.outEvent.setRead;
        ctx.send;
    }

    string sslState(ChannelContext ctx)
    {
        auto stateStr = SSL_state_string(ctx.inEvent.chan.ssl);
        return stateStr.fromStringz.idup;
    }

    override void onReadStart(ChannelContext ctx)
    {
        ubyte[] chanBuff = ctx.inEvent.chan.readableBytes;
        if (chanBuff.length > 0)
        {
            int res = BIO_write(ctx.inEvent.chan.rbio, chanBuff.ptr, cast(int) chanBuff.length);
            assert(res > 0);
            assert(res == chanBuff.length);

            if (SSL_get_state(ctx.inEvent.chan.ssl) == TLS_ST_EARLY_DATA)
            {
                auto tedStat = SSL_get_early_data_status(ctx.inEvent.chan.ssl);
                switch (tedStat)
                {
                    case SSL_EARLY_DATA_ACCEPTED:
                        logging.logger.trace("SSL_EARLY_DATA_ACCEPTED");
                        break;
                    case SSL_EARLY_DATA_REJECTED:
                        logging.logger.trace("SSL_EARLY_DATA_REJECTED");
                        break;
                    case SSL_EARLY_DATA_NOT_SENT:
                        logging.logger.trace("SSL_EARLY_DATA_NOT_SENT");
                        break;
                    default:
                        logging.logger.trace("Unknown ED status: ", tedStat);
                        break;
                }
            }

            if (!SSL_is_init_finished(ctx.inEvent.chan.ssl))
            {
                int hsRet = SSL_do_handshake(ctx.inEvent.chan.ssl);
                if (hsRet <= 0)
                {
                    int err = SSL_get_error(ctx.inEvent.chan.ssl, hsRet);
                    if (err != SSL_ERROR_WANT_READ)
                    {
                        logging.logger.errorf("Handshake failed %d: %s\n", hsRet, lastSSLError(err));
                        ctx.outEvent.setClose;
                        ctx.send;
                        SSL_shutdown(ctx.inEvent.chan.ssl);
                        return;
                    }
                    else
                    {
                        logging.logger.trace("SSL_ERROR_WANT_READ");

                        int pending = BIO_pending(ctx.inEvent.chan.wbio);
                        if (pending > 0)
                        {
                            char[] buf = new char[pending];
                            int len = BIO_read(ctx.inEvent.chan.wbio, buf.ptr, pending);
                            ctx.outEvent.buffer = cast(ubyte[]) buf[0 .. len];
                            ctx.outEvent.setWrite;
                            ctx.send;
                            logging.logger.trace("Send data from SSL");

                            ctx.inEvent.chan.resetBufferIndices;
                        }
                    }

                    return;
                }
                else if (hsRet == 1)
                {
                    ctx.inEvent.chan.isInitSSL = true;
                    logging.logger.trace("Handshake success");
                    //ctx.inEvent.chan.resetBufferIndices;
                    //ctx.outEvent.setRead;
                    //ctx.send;
                }
                else
                {
                    ctx.outEvent.setRead;
                    ctx.send;
                    return;
                }
            }

            int readDataLength = BIO_pending(ctx.inEvent.chan.rbio);
            if (readDataLength == 0)
            {
                logging.logger.trace("SSL buffer empty, send read");
                ctx.inEvent.chan.resetBufferIndices;
                ctx.outEvent.setRead;
                ctx.send;
                return;
            }

            import std.array : appender;

            ubyte[1096] readBuff;
            ubyte[4096] copyBuff;
            size_t copyBuffPos;
            size_t readBytes;
            int copyRet;
            while ((copyRet = SSL_read_ex(ctx.inEvent.chan.ssl, readBuff.ptr, readBuff.sizeof, &readBytes)) == 1)
            {
                if (readBytes == 0)
                {
                    break;
                }
                copyBuff[copyBuffPos .. copyBuffPos + readBytes] = readBuff[0 .. readBytes];
                copyBuffPos += readBytes;
            }

            if (copyRet != 0)
            {
                logging.logger.error("SSL read fail: ", copyRet);
                return;
            }

            ubyte[] decrData = copyBuff[0 .. copyBuffPos];

            decode(decrData);
            if (decoder.state != DecoderState.end && (
                    decoder.state != DecoderState
                    .errorNoHeadersNoBody))
            {
                debug writeln("HTTPS request not full, read again: ", decoder.state);
                ctx.outEvent.setRead;
                ctx.send;
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
                import std.file : read, exists, isDir;
                import std.conv : to;

                if (!path.exists)
                {
                    logging.logger.error("Server file not found: ", path);
                    return;
                }

                if (path.isDir)
                {
                    logging.logger.error("Sever file not a file, directory: ", path);
                    return;
                }

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

                string headerLine = "HTTP/1.1 200 OK\r\n" ~ mimeType ~ "\r\nContent-Length: " ~ contentLen ~ "\r\nConnection: close\r\n\r\n";

                content = (cast(ubyte[]) headerLine.dup) ~ content;

                fileMap[path.idup] = content;
                fileContent = content;
            }

            auto content = cast(ubyte[]) fileContent;

            int written = SSL_write(ctx.inEvent.chan.ssl, content.ptr, cast(int) content.length);
            if (written <= 0)
            {
                int sslErr = SSL_get_error(ctx.inEvent.chan.ssl, written);
                if (sslErr == SSL_ERROR_WANT_WRITE || sslErr == SSL_ERROR_WANT_READ)
                {
                    logging.logger.trace("WANT");
                    return;
                }
                logging.logger.error("Writing error");
                return;
            }

            BIO* wbio = ctx.inEvent.chan.wbio;
            int wpending = BIO_pending(wbio);

            if (wpending > 0)
            {
                char[] buff = new char[wpending];
                int encryptLen = BIO_read(wbio, buff.ptr, wpending);
                assert(encryptLen > 0);
                ctx.outEvent.buffer = cast(ubyte[]) buff[0 .. encryptLen];
                ctx.outEvent.setWrite;
                ctx.send;
            }

        }

        ctx.inEvent.chan.resetBufferIndices;
        ctx.outEvent.setRead;
        ctx.send;
    }

    override void onReadEnd(ChannelContext ctx)
    {
        import std;

        writeln("Read end: ", sslState(ctx));
    }

    override void onWriteEnd(ChannelContext ctx)
    {
        import std;

        writeln("WROTE END: ", sslState(ctx));

        ctx.outEvent.setRead;
        ctx.send;
    }

    string lastSSLError(int errCode)
    {
        auto buffPtr = ERR_error_string(errCode, null);
        if (!buffPtr)
        {
            return null;
        }
        return buffPtr.fromStringz.idup;
    }

    string lastSSLError()
    {
        import std.string : fromStringz;

        import openssl_libs;

        auto errCode = ERR_peek_error();
        if (errCode == 0)
        {
            return null;
        }

        auto buffPtr = ERR_error_string(errCode, null);
        if (!buffPtr)
        {
            return null;
        }
        return buffPtr.fromStringz.idup;
    }

}
