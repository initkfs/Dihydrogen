module api.dn.protos.http1.servers.http_server;
/**
 * Authors: initkfs
 */
import api.core.controllers.controller : Controller;
import api.core.components.uni_component : UniComponent;

import api.dn.sockets.servers.socket_tcp_server : SocketTcpServer;
import api.dn.io.loops.event_loop : EventLoop;
import api.dn.io.loops.server_loop : ServerLoop;
import api.dn.pipelines.handler_pipeline : HandlerPipeline;
import api.dn.handlers.channel_handler : ChannelHandler;
import api.dn.channels.server_channel : ServerChannel;
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

class HTTPServer : Controller!UniComponent
{
    string webroot;
    bool isStartOnRun = true;

    protected
    {
        static SocketTcpServer serverSocket1;
        static SocketTcpServer serverSocket2;
        static ServerLoop loop;
    }

    ChannelHandler newHandler(string webroot, Logging logging)
    {
        import api.dn.protos.http1.handlers.servers.webroot_http_handler : WebrootHttpHandler;

        return new WebrootHttpHandler(webroot, logging);
    }

    HandlerPipeline createPipeline(string webroot)
    {
        import api.dn.protos.stomp.handlers.stomp_handler : StompHandler;

        auto pipe = new HandlerPipeline;
        pipe.add(newHandler(webroot, logging));
        //pipe.add(new ChannelHandler);
        return pipe;
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

        signal(SIGINT, &sigintHandler);

        serverSocket1 = new SocketTcpServer(logging);
        serverSocket1.initialize;
        serverSocket1.create;
        serverSocket1.run;

        serverSocket2 = new SocketTcpServer(logging);
        serverSocket2.port = "8081";
        serverSocket2.initialize;
        serverSocket2.create;
        serverSocket2.run;

        auto eventRouter = new PipelineRouter(createPipeline(webroot));

        auto monitor = new LogEventMonitor(logging);

        import std.conv: to;

        loop = newServerLoop(logging, [
            ServerChannel(serverSocket1.fd, serverSocket1.port.to!ushort),
            ServerChannel(serverSocket2.fd, serverSocket2.port.to!ushort)
        ], eventRouter, translator:
        null, monitor);

        loop.initialize;
        loop.create;

        import Procs = api.dn.sys.proc;
        import std.format : format;

        logger.infof("Process urid:%s, ueid:%s, grid:%s, geid:%s", Procs.getRealUserId, Procs.getEffectiveUserId, Procs
                .getRealGroupId, Procs.getEffectifeGroupId);

        import Locale = api.dn.sys.locale;
        import Time = api.dn.sys.time;

        char[64] timeBuff = 0;
        size_t buffLen;
        Time.timestampf(timeBuff, buffLen);

        import std.exception : enforce;

        enforce(buffLen <= timeBuff.length, "Time buffer overflow");
        logger.infof("Server time: %s, %s. LC_ALL:%s, LC_CTYPE:%s, LC_COLLATE:%s", timeBuff[0 .. buffLen], Time.timestamp, Locale
                .getLocaleInfo, Locale.getLocaleInfoCtype, Locale.getLocaleInfoCollate);

        import Limit = api.dn.sys.limit;

        logger.infof("Hostname max:%s, page size:%s, max files:%s", Limit.hostNameMax, Limit.pageSize, Limit
                .openFilesProcMax);

        if (isStartOnRun)
        {
            loop.run;
        }
    }

    ServerLoop newServerLoop(Logging logger, ServerChannel[] serverChans, EventRouter router, EventConverter translator = null, EventMonitor monitor = null)
    {
        return new ServerLoop(logger, serverChans, router, translator, monitor);
    }

    static extern (C) void sigintHandler(int signo)
    {
        import std.stdio : writefln;

        writefln("^C pressed. Server socket '%s'", [
            serverSocket1.fd, serverSocket2.fd
        ]);

        if (loop)
        {
            loop.stop;
            loop.dispose;
            loop = null;
        }

        if (serverSocket1)
        {
            serverSocket1.stop;
            serverSocket1.dispose;
            serverSocket1 = null;
        }

        if (serverSocket2)
        {
            serverSocket2.stop;
            serverSocket2.dispose;
            serverSocket2 = null;
        }

        exit(0);
    }

}
