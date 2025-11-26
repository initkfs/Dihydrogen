module api.dn.protocols.http1.handlers.webroot_https_handler;

import api.core.loggers.logging : Logging;

import api.dn.net.sockets.socket_connect : SocketConnectState;
import api.dn.protocols.http1.handlers.webroot_http_handler : WebrootHttpHandler;
import api.dn.protocols.http1.handlers.http_handler : HttpHandler;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.channels.contexts.channel_context : ChannelContext;

import api.dn.protocols.http1.http_common;
import api.dn.protocols.http1.static_http_decoder : StaticHttpDecoder, DecoderState;

import HttpResp = api.dn.protocols.http1.http_responses;

import std.string : fromStringz, toStringz;

import openssl_libs;

import std : writeln;

/**
 * Authors: initkfs
 */
class WebrootHttpsHandler : WebrootHttpHandler
{
    Logging logging;

    this(string root, Logging logging)
    {
        super(root, logging);
        this.logging = logging;
    }

    override void onWriteEnd(ChannelContext ctx)
    {
        sendRead(ctx);
    }

    override void onReadStart(ChannelContext ctx)
    {
        char[256] uri;
        size_t uriLen;

        ubyte[] chanBuff = ctx.inEvent.chan.readableBytes;
        if (chanBuff.length == 0)
        {
            ctx.inEvent.chan.resetBufferIndices;
            ctx.outEvent.setRead;
            ctx.send;
            return;
        }

        int res = BIO_write(ctx.inEvent.chan.sslContext.rbio, chanBuff.ptr, cast(int) chanBuff
                .length);
        if (res < 0)
        {
            logging.logger.error("BIO write error: ", res);
            sendClose(ctx);
            return;
        }

        if (res != chanBuff.length)
        {
            logging.logger.errorf("BIO write error, buffer len: %s, but result %s", chanBuff.length, res);
            sendClose(ctx);
            return;
        }

        if (SSL_get_state(ctx.inEvent.chan.sslContext.ssl) == TLS_ST_EARLY_DATA)
        {
            auto tedStat = SSL_get_early_data_status(ctx.inEvent.chan.sslContext.ssl);
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

        if (!SSL_is_init_finished(ctx.inEvent.chan.sslContext.ssl))
        {
            logging.logger.trace("SSL not finished");

            int hsRet = SSL_do_handshake(ctx.inEvent.chan.sslContext.ssl);
            if (hsRet <= 0)
            {
                int err = SSL_get_error(ctx.inEvent.chan.sslContext.ssl, hsRet);
                if (err != SSL_ERROR_WANT_READ)
                {
                    logging.logger.errorf("Handshake failed %d: %s\n", hsRet, lastSSLError(err));
                    sendClose(ctx);
                    return;
                }
                else
                {
                    logging.logger.trace("SSL_ERROR_WANT_READ");

                    int pending = BIO_pending(ctx.inEvent.chan.sslContext.wbio);
                    if (pending > 0)
                    {
                        char[] buf = new char[pending];
                        int len = BIO_read(ctx.inEvent.chan.sslContext.wbio, buf.ptr, pending);
                        ctx.outEvent.chan.outb.slice = cast(ubyte[]) buf[0 .. len];
                        ctx.outEvent.setWrite;
                        ctx.send;
                        logging.logger.trace("Send data from SSL");

                        ctx.inEvent.chan.resetBufferIndices;
                        return;
                    }
                }

                sendClose(ctx);
                return;
            }
            else if (hsRet == 1)
            {
                ctx.inEvent.chan.sslContext.isInitSSL = true;
                logging.logger.trace("Handshake success");
            }
            else
            {
                logging.logger.trace("SSL continue read: ", hsRet);
                sendRead(ctx);
                return;
            }
        }

        logging.logger.trace("SSL finished");

        int readDataLength = BIO_pending(ctx.inEvent.chan.sslContext.rbio);
        if (readDataLength == 0)
        {
            logging.logger.trace("SSL buffer empty, send read");
            ctx.inEvent.chan.resetBufferIndices;
            sendRead(ctx);
            return;
        }

        import std.array : appender;

        ubyte[1096] readBuff;
        ubyte[4096] copyBuff;
        size_t copyBuffPos;
        size_t readBytes;
        int copyRet;
        while ((copyRet = SSL_read_ex(ctx.inEvent.chan.sslContext.ssl, readBuff.ptr, readBuff.sizeof, &readBytes)) == 1)
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
            sendClose(ctx);
        }

        ubyte[] decrData = copyBuff[0 .. copyBuffPos];
        if (decrData.length == 0)
        {
            logging.logger.trace("No data found");

            // BIO* wbio = ctx.inEvent.chan.sslContext.wbio;
            // int wpending = BIO_pending(wbio);
            // if (wpending > 0)
            // {
            //     char[] buff = new char[wpending];
            //     int encryptLen = BIO_read(wbio, buff.ptr, wpending);
            //     ctx.outEvent.chan.stateNext = SocketConnectState.close;
            //     ctx.outEvent.chan.outb.slice = cast(ubyte[]) buff[0 .. encryptLen];
            //     sendWrite(ctx);
            //     return;
            // }

            sendClose(ctx);
            return;
        }

        decode(decrData);
        if (decoder.state != DecoderState.end && (
                decoder.state != DecoderState
                .errorNoHeadersNoBody))
        {
            logging.logger.trace("HTTPS request not full, read again: ", decoder.state);
            sendRead(ctx);
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

        const char[] rawUriSlice = uri[0 .. uriLen];
        if (rawUriSlice.length == 0)
        {
            logging.logger.error("URI slice is empty");
            return;
        }

        import api.dn.sys.fs : realpath;
        import std.string : fromStringz;

        assert(indexFile.length > 0);
        const uriSlice = rawUriSlice == indexUri ? indexFile : rawUriSlice;

        import std.format : sformat;

        char[256] buffer;
        char[256] buffer2;

        char[] filePath = sformat(buffer, "%s/%s\0", webroot, uriSlice);

        auto result = realpath(filePath.ptr, buffer2.ptr);
        if (result is null)
        {
            import api.core.utils.text : escapeunw;

            logging.logger.error("Realpath error: ", escapeunw(filePath));
            sendClose(ctx);
            return;
        }

        auto path = result.fromStringz;

        auto content = fileContent(path);
        if (content.length == 0)
        {
            content = cast(ubyte[]) HttpResp._404;
        }

        int written = SSL_write(ctx.inEvent.chan.sslContext.ssl, content.ptr, cast(int) content
                .length);
        if (written <= 0)
        {
            int sslErr = SSL_get_error(ctx.inEvent.chan.sslContext.ssl, written);
            if (sslErr == SSL_ERROR_WANT_WRITE)
            {
                logging.logger.trace("SSL want write");
                sendClose(ctx);
                return;
            }
            else if (sslErr == SSL_ERROR_WANT_READ)
            {
                logging.logger.trace("SSL want read");
                sendRead(ctx);
                return;
            }

            logging.logger.error("SSL writing error: ", sslErr);
            sendClose(ctx);
            return;
        }

        BIO* wbio = ctx.inEvent.chan.sslContext.wbio;
        int wpending = BIO_pending(wbio);

        if (wpending > 0)
        {
            char[] buff = new char[wpending];
            int encryptLen = BIO_read(wbio, buff.ptr, wpending);
            assert(encryptLen > 0);
            ctx.outEvent.chan.outb.slice = cast(ubyte[]) buff[0 .. encryptLen];
            ctx.outEvent.chan.stateNext = SocketConnectState.close;
            sendWrite(ctx);
        }
        else
        {
            logging.logger.trace("Unable to write in ssl buffer");
            sendClose(ctx);
        }
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

    string sslState(ChannelContext ctx)
    {
        auto stateStr = SSL_state_string(ctx.inEvent.chan.sslContext.ssl);
        return stateStr.fromStringz.idup;
    }

}
