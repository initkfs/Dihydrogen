module api.dn.servers.https_server;

import api.dn.servers.http_server : HTTPServer;

import api.core.controllers.controller : Controller;
import api.core.components.uni_component : UniComponent;

import api.core.loggers.logging : Logging;
import api.dn.net.sockets.servers.socket_tcp_server : SocketTcpServer;
import api.dn.io.loops.event_loop : EventLoop;
import api.dn.io.loops.server_loop : ServerLoop;
import api.dn.io.loops.ssl_server_loop : SSLServerLoop;
import api.dn.channels.handlers.pipelines.handler_pipeline : HandlerPipeline;
import api.dn.channels.handlers.channel_handler : ChannelHandler;
import api.dn.channels.server_channel : ServerChannel;
import api.dn.channels.events.routes.event_router : EventRouter;
import api.dn.channels.events.routes.pipeline_router : PipelineRouter;
import api.dn.channels.events.converters.event_converter : EventConverter;
import api.dn.channels.events.monitors.event_monitor : EventMonitor;
import api.dn.channels.events.monitors.log_event_monitor : LogEventMonitor;

import core.stdc.stdlib : exit;

debug import std.stdio : writeln, writefln;

import signal_libs;
import api.dn.sys.locale;
import openssl_libs;

immutable string privateKeyPathConfigKey = "privateKeyPath";
immutable string certPathConfigKey = "certPath";

class HTTPSServer : HTTPServer
{
    string privateKeyPath;
    string certPath;

    SSL_CTX* ctx;

    this()
    {
        isStartOnRun = false;
    }

    override ChannelHandler newHandler(string webroot, Logging logging)
    {
        import api.dn.protocols.http1.handlers.webroot_https_handler : WebrootHttpsHandler;

        return new WebrootHttpsHandler(webroot, logging);
    }

    override void run()
    {
        if (privateKeyPath.length == 0)
        {
            if (!config.hasKey(privateKeyPathConfigKey))
            {
                throw new Exception(
                    "Private key not found in config with key: " ~ privateKeyPathConfigKey);
            }

            privateKeyPath = config.getNotEmptyString(privateKeyPathConfigKey);
            logger.trace("Found private key path in config: ", webroot);
        }

        if (certPath.length == 0)
        {
            if (!config.hasKey(certPathConfigKey))
            {
                throw new Exception(
                    "Сertificate file found in config with key: " ~ certPathConfigKey);
            }

            certPath = config.getNotEmptyString(certPathConfigKey);
            logger.trace("Found certificate file in config: ", certPath);
        }

        import openssl_libs;

        SSL_library_init();
        OpenSSL_add_all_algorithms();
        SSL_load_error_strings();

        ctx = SSL_CTX_new(TLS_server_method());
        if (!ctx)
        {
            logger.error(lastSSLError);
            return;
        }

        //SSL_CTX_set_msg_callback(ctx, &SSL_trace);

        //import std.stdio: stdout;

        //SSL_set_msg_callback_arg(ctx, BIO_new_fp(cast(_IO_FILE*) stdout.getFP,0));

        SSL_CTX_set_options(ctx, SSL_OP_BIT(3));
        SSL_CTX_set_cipher_list(ctx, "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-GCM-SHA384");
        SSL_CTX_set_ciphersuites(ctx, "TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384");

        import std.string : toStringz;

        if (SSL_CTX_use_certificate_file(ctx, certPath.toStringz, X509_FILETYPE_PEM) <= 0)
        {
            logger.error(lastSSLError);
            return;
        }
        if (SSL_CTX_use_PrivateKey_file(ctx, privateKeyPath.toStringz, X509_FILETYPE_PEM) <= 0)
        {
            logger.error(lastSSLError);
            return;
        }

        if (!SSL_CTX_check_private_key(ctx))
        {
            logger.error("Private key does not match the certificate public keyn");
            return;
        }

        super.run;

        loop.run;
    }

    override ServerLoop newServerLoop(Logging logger, ServerChannel[] serverChans, EventRouter router, EventConverter translator = null, EventMonitor monitor = null)
    {
        return new SSLServerLoop(logger, ctx, serverChans, router, translator, monitor);
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

    override void dispose()
    {
        super.dispose;

        if (ctx)
        {
            SSL_CTX_free(ctx);
            ctx = null;
        }
    }

}
