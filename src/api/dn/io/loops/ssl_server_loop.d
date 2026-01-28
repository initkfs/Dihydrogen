module api.dn.io.loops.ssl_server_loop;

import std.stdio : writeln, writefln;
import std.string : toStringz, fromStringz;

import io_uring_libs;
import socket_libs;

import core.stdc.stdlib : malloc, exit;
import core.stdc.string : memset, strerror;

import api.dn.io.natives.iouring.io_uring;
import api.dn.io.natives.iouring.io_uring_types;

import std.conv : to;
import std.string : toStringz, fromStringz;
import api.core.loggers.logging;

import api.dn.io.loops.server_loop : ServerLoop;
import api.core.components.units.services.loggable_unit : LoggableUnit;
import api.dn.utils.pools.linear_pool : LinearPool;
import api.dn.channels.fd_channel : FdChannel, FdChannelType;
import api.dn.sockets.socket_connect : SocketConnectState;

import api.dn.io.loops.endpointable_event_loop : EndpointableEventLoop;

import api.dn.channels.server_channel : ServerChannel;
import api.dn.events.routes.event_router : EventRouter;
import api.dn.events.converters.event_converter : EventConverter;
import api.dn.events.monitors.event_monitor : EventMonitor;
import api.dn.events.channel_events : ChanInEvent, ChanOutEvent;

import std.string : fromStringz;

import openssl_libs;

/**
 * Authors: initkfs
 */
class SSLServerLoop : ServerLoop
{
    SSL_CTX* ctx;

    this(Logging logger, SSL_CTX* ctx, ServerChannel[] serverChans, EventRouter router, EventConverter translator = null, EventMonitor monitor = null)
    {
        super(logger, serverChans, router, translator, monitor);

        assert(ctx);
        this.ctx = ctx;
    }

    override void create()
    {
        super.create;

        onAcceptEnd = (conn) {
            //TODO reuse
            //https://docs.openssl.org/3.5/man3/SSL_clear/#notes
            //SSL_get_session; SSL_new; SSL_set_session; SSL_free
            if (conn.sslContext.ssl)
            {
                //https://docs.openssl.org/3.5/man3/SSL_set_bio/#synopsis
                //BIO will be automatically freed using BIO_free_all(3) when the ssl is freed.
                conn.sslContext.freeSSL;
            }

            auto ssl = SSL_new(ctx);
            if (!ssl)
            {
                logger.error(lastSSLError);
                sendNewInEvent(conn, ChanInEvent.ChanInEventState.closed);
                return;
            }

            // SSL_MODE_AUTO_RETRY
            //SSL_set_mode(ssl,
            //    SSL_MODE_ENABLE_PARTIAL_WRITE | SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER);

            //SSL_set_blocking_mode(ssl, 0); //non-blocking
            conn.sslContext.ssl = ssl;
            conn.sslContext.rbio = BIO_new(BIO_s_mem());
            conn.sslContext.wbio = BIO_new(BIO_s_mem());

            //SSL_set_read_ahead(conn.ssl, 1);
            //SSL_set_early_data_enabled(conn.ssl, false);

            SSL_set_bio(conn.sslContext.ssl, conn.sslContext.rbio, conn.sslContext.wbio);
            SSL_set_accept_state(conn.sslContext.ssl);

            // if (!SSL_is_init_finished(conn.ssl))
            // {
            //     int hsRet = SSL_do_handshake(conn.ssl);
            //     if (hsRet <= 0)
            //     {
            //         int err = SSL_get_error(ssl, hsRet);
            //         if (err != SSL_ERROR_WANT_READ)
            //         {
            //             logger.error("Handshake failed: %d\n", err);
            //             return;
            //         }
            //     }
            //     logger.trace("Handshake completed");
            // }else {
            //     logger.trace("Handshake init finished");
            // }

            //addSocketReadv(&ring, conn);

            // int pending = BIO_pending(conn.wbio);
            // import std;
            // writeln("PEND:", pending, " hand: ", handRes);
            // if (pending > 0)
            // {
            //     char[] buf = new char[pending];
            //     BIO_read(conn.wbio, buf.ptr, pending);
            //     //send(socket, buf, pending, 0); // Отправляем через сокет
            //     //free(buf);
            //     import std;
            //     writeln("BUFF:" , buf);
            // }

            // if (SSL_accept(conn.ssl) <= 0)
            // {
            //     logger.error(lastSSLError);
            //     addSocketClose(&ring, conn);
            //     return;
            // }

            // long BIO_get_ktls_send(bio_st* b)
            // {
            //     return BIO_ctrl(b, BIO_CTRL_GET_KTLS_SEND, 0, null);
            // }

            // long BIO_get_ktls_recv(bio_st* b)
            // {
            //     return BIO_ctrl(b, BIO_CTRL_GET_KTLS_RECV, 0, null);
            // }

            // auto ktls_send_enabled = BIO_get_ktls_send(SSL_get_wbio(conn.ssl));
            // auto ktls_recv_enabled = BIO_get_ktls_recv(SSL_get_rbio(conn.ssl));
            // logger.tracef("KTLS TX enabled: %d\n", ktls_send_enabled);
            // logger.tracef("KTLS RX enabled: %d\n", ktls_recv_enabled);

            // auto serverCert = SSL_get1_peer_certificate(conn.ssl);
            // if (serverCert)
            // {
            //     scope (exit)
            //     {
            //         X509_free(serverCert);
            //     }

            //     logger.trace("Server certificate:");

            //     void OPENSSL_free(void* ptr)
            //     {
            //         CRYPTO_free(ptr, __FILE__, __LINE__);
            //     }

            //     auto subjStr = X509_NAME_oneline(X509_get_subject_name(serverCert), null, 0);
            //     assert(subjStr);
            //     scope (exit)
            //     {
            //         OPENSSL_free(subjStr);
            //     }
            //     logger.trace("\t subject: %s \n", subjStr.fromStringz);

            //     auto issuerStr = X509_NAME_oneline(X509_get_issuer_name(serverCert), null, 0);
            //     assert(issuerStr);
            //     scope (exit)
            //     {
            //         OPENSSL_free(issuerStr);
            //     }
            //     logger.trace("\t issuer: %s \n", issuerStr.fromStringz);
            // }
            // else
            // {
            //     logger.error("Not found cert in ssl connection");
            // }

            // string resp = "HTTP/1.1 200 OK\r\n\r\nConnection: close\r\n\r\n";

            // int ret = SSL_write(conn.ssl, resp.ptr, cast(int) resp.length);
            // if (ret < 0)
            // {
            //     logger.error("SSL writing error: ", lastSSLError);
            //     addSocketClose(&ring, conn);
            //     return;
            // }

            // BIO_flush(SSL_get_wbio(conn.ssl));

            // char[1024] buf;
            // int bytes = SSL_read(conn.ssl, buf.ptr, buf.sizeof);
            // if (bytes > 0)
            // {
            //     import std.string : toStringz;

            // }

            sendNewInEvent(conn, ChanInEvent.ChanInEventState.accepted);
        };

        // onReadEnd = (conn) {

        //     import std;

        //     writeln("END");

        //     sendNewInEvent(conn, ChanInEvent.ChanInEventState.readEnd);
        // };

        // onCloseEnd = (conn) {

        //     // if (conn.ssl)
        //     // {
        //     //     SSL_shutdown(conn.ssl);
        //     //     SSL_free(conn.ssl);
        //     //     conn.ssl = null;
        //     // }

        //     sendNewInEvent(conn, ChanInEvent.ChanInEventState.closed);
        // };
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
