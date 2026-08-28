module api.dn.protos.http1.servers.http_server;
/**
 * Authors: initkfs
 */
import api.dn.protos.http1.servers.base_http_server: BaseHTTPServer;

import api.dn.sockets.servers.socket_tcp_server : SocketTcpServer;
import api.dn.io.loops.event_loop : EventLoop;
import api.dn.io.loops.server_loop : ServerLoop;
import api.dn.pipelines.handler_pipeline : HandlerPipeline;
import api.dn.handlers.chan_handler : ChanHandler;
import api.dn.chans.server_chan : ServerChan;
import api.dn.events.routes.event_router : EventRouter;
import api.dn.events.routes.pipeline_router : PipelineRouter;
import api.dn.events.converters.event_converter : EventConverter;
import api.dn.events.monitors.event_monitor : EventMonitor;
import api.dn.events.monitors.log_event_monitor : LogEventMonitor;
import api.core.loggers.logging : Logging;

import core.stdc.stdlib : exit;

debug import std.stdio : writeln, writefln;

import signal_libs;
import api.dn.sys.locale;

immutable string webrootConfigKey = "webroot";

class HTTPServer : BaseHTTPServer
{
    string webroot;
    bool isStartOnRun = true;

    override ChanHandler newHandler(Logging logging)
    {
        import api.dn.protos.http1.handlers.servers.webroot_http_handler : WebrootHttpHandler;

        return new WebrootHttpHandler(webroot, logging);
    }

    override void run()
    {
        super.run;

        if (webroot.length == 0)
        {
            if (!config.hasKey(webrootConfigKey))
            {
                throw new Exception(
                    "Webroot directory not found in config with key: " ~ webrootConfigKey);
            }

            webroot = config.getNotEmptyString(webrootConfigKey);
            logger.trace("Found webroot in config: ", webroot);
        }

        import std.file : exists, isDir;

        if (!webroot.exists || !webroot.isDir)
        {
            throw new Exception("Webroot not exists or not a directory: " ~ webroot);
        }

        import api.dn.sys.fs : getAtrrStr;

        logger.tracef("Web webroot (%s): %s", webroot.getAtrrStr, webroot);

        //signal(SIGINT, &sigintHandler);

        auto serverSocket1 = new SocketTcpServer(logging);
        serverSocket1.initialize;
        serverSocket1.create;
        serverSocket1.run;

        auto serverSocket2 = new SocketTcpServer(logging);
        serverSocket2.port = "8081";
        serverSocket2.initialize;
        serverSocket2.create;
        serverSocket2.run;

        serverSockets ~= serverSocket1;
        serverSockets ~= serverSocket2;

        import std.conv : to;

        createLoop([
            ServerChan(serverSocket1.fd, serverSocket1.port.to!ushort),
            ServerChan(serverSocket2.fd, serverSocket2.port.to!ushort)
        ]);

        logServerInfo;

        if (isStartOnRun)
        {
            loop.run;
        }
    }
}
