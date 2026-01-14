module api.dn.clients.udp_client;
/**
 * Authors: initkfs
 */
import api.core.controllers.controller : Controller;
import api.core.components.uni_component : UniComponent;

import api.dn.net.sockets.socket_udp_client : SocketUdpClient;
import api.dn.protocols.dns.handlers.clients.clients_udp_handler : ClientUdpHandler;
import api.dn.io.loops.event_loop : EventLoop;
import api.dn.io.loops.client_loop : ClientLoop;
import api.dn.channels.handlers.pipelines.handler_pipeline : HandlerPipeline;
import api.dn.channels.handlers.channel_handler : ChannelHandler;
import api.dn.channels.server_channel : ServerChannel;
import api.dn.channels.events.routes.event_router : EventRouter;
import api.dn.channels.events.routes.pipeline_router : PipelineRouter;
import api.dn.channels.events.converters.event_converter : EventConverter;
import api.dn.channels.events.monitors.event_monitor : EventMonitor;
import api.dn.channels.events.monitors.log_event_monitor : LogEventMonitor;
import api.core.loggers.logging : Logging;

import core.stdc.stdlib : exit;

debug import std.stdio : writeln, writefln;

import signal_libs;
import api.dn.sys.locale;

class UDPClient : Controller!UniComponent
{
    string host = "8.8.8.8";
    ushort port = 53;
    string path;

    protected
    {
        static SocketUdpClient clientSocket;
        static ClientLoop loop;
    }

    ChannelHandler newHandler(Logging logging)
    {
        return new ClientUdpHandler(logging);
    }

    HandlerPipeline createPipeline()
    {
        auto pipe = new HandlerPipeline;
        pipe.add(newHandler(logging));
        return pipe;
    }

    override void run()
    {
        super.run;

        clientSocket = new SocketUdpClient(logging);
        clientSocket.host = host;
        clientSocket.port = port;
        clientSocket.initialize;
        clientSocket.create;
        clientSocket.run;

        auto eventRouter = new PipelineRouter(createPipeline);

        auto monitor = new LogEventMonitor(logging);

        loop = newClientLoop(logging, ServerChannel(clientSocket.fd), eventRouter, translator:
            null, monitor);

        loop.initialize;
        loop.create;
        loop.run;
    }

    ClientLoop newClientLoop(Logging logger, ServerChannel serverChan, EventRouter router, EventConverter translator = null, EventMonitor monitor = null)
    {
        return new ClientLoop(logger, serverChan, router, translator, monitor);
    }

    static extern (C) void sigintHandler(int signo)
    {
        import std.stdio : writefln;

        writefln("^C pressed. Client socket '%s'", [
            clientSocket.fd
        ]);

        if (loop)
        {
            loop.stop;
            loop.dispose;
            loop = null;
        }

        if (clientSocket)
        {
            clientSocket.stop;
            clientSocket.dispose;
            clientSocket = null;
        }

        exit(0);
    }

}
