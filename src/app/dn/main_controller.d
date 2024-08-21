module app.dn.main_controller;

import app.core.controllers.controller : Controller;
import app.core.components.uni_component : UniComponent;

import app.dn.net.sockets.socket_tcp_server : SocketTcpServer;
import app.dn.io.loops.event_loop : EventLoop;
import app.dn.io.loops.server_loop : ServerLoop;
import app.dn.channels.handlers.pipelines.handler_pipeline : HandlerPipeline;
import app.dn.channels.handlers.channel_handler : ChannelHandler;
import app.dn.channels.server_channel : ServerChannel;
import core.stdc.stdlib : exit;
import app.dn.channels.events.routes.event_router : EventRouter;
import app.dn.channels.events.routes.pipeline_router : PipelineRouter;
import app.dn.channels.events.translators.event_translator : EventTranslator;
import app.dn.channels.events.monitors.event_monitor : EventMonitor;
import app.dn.channels.events.monitors.log_event_monitor : LogEventMonitor;

debug import std.stdio: writeln, writefln;

import signal_libs;
import app.dn.sys.locale;

/**
 * Authors: initkfs
 */
class MainController : Controller!UniComponent
{
    protected
    {
        static SocketTcpServer serverSocket1;
        static SocketTcpServer serverSocket2;
        static ServerLoop loop;
    }

    static HandlerPipeline createPipeline()
    {
        import app.dn.protocols.stomp.handlers.stomp_handler : StompHandler;
        import app.dn.protocols.http1.handlers.http_handler : HttpHandler;

        auto pipe = new HandlerPipeline;
        //pipe.add(new ChannelHandler);
        pipe.add(new HttpHandler);
        return pipe;
    }

    override void run()
    {
        super.run;

        signal(SIGINT, &sigintHandler);

        serverSocket1 = new SocketTcpServer(logger);
        serverSocket1.initialize;
        serverSocket1.create;
        serverSocket1.run;

        serverSocket2 = new SocketTcpServer(logger);
        serverSocket2.port = 8081;
        serverSocket2.initialize;
        serverSocket2.create;
        serverSocket2.run;

        auto eventRouter = new PipelineRouter(createPipeline);

        auto monitor = new LogEventMonitor(logger);

        loop = new ServerLoop(logger, [
            ServerChannel(serverSocket1.fd, serverSocket1.port),
            ServerChannel(serverSocket2.fd, serverSocket2.port)
        ], eventRouter, translator:
        null, monitor);

        loop.initialize;
        loop.create;

        import Procs = app.dn.sys.proc;
        import std.format: format;
        logger.infof("Process urid:%s, ueid:%s, grid:%s, geid:%s", Procs.getRealUserId, Procs.getEffectiveUserId, Procs.getRealGroupId, Procs.getEffectifeGroupId);

        import Locale = app.dn.sys.locale;
        import Time = app.dn.sys.time;
        char[64] timeBuff = 0;
        size_t buffLen;
        Time.timestampf(timeBuff, buffLen);

        import std.exception: enforce;
        enforce(buffLen <= timeBuff.length, "Time buffer overflow");
        logger.infof("Server time: %s, %s. LC_ALL:%s, LC_CTYPE:%s, LC_COLLATE:%s", timeBuff[0..buffLen], Time.timestamp, Locale.getLocaleInfo, Locale.getLocaleInfoCtype, Locale.getLocaleInfoCollate);

        loop.run;
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
        }

        if (serverSocket1)
        {
            serverSocket1.stop;
            serverSocket1.dispose;
        }

        if (serverSocket2)
        {
            serverSocket2.stop;
            serverSocket2.dispose;
        }

        exit(0);
    }

}
