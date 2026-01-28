module api.dn.clients.udp_client;
/**
 * Authors: initkfs
 */
import api.dn.clients.base_handler_client : BaseHandlerClient;

import api.dn.net.sockets.clients.socket_udp_client : SocketUdpClient;
import api.dn.protocols.dns.handlers.clients.clients_udp_handler : ClientUdpHandler;
import api.dn.io.loops.event_loop : EventLoop;

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

class UDPClient : BaseHandlerClient
{
    this()
    {
        host = "8.8.8.8";
        port = "53";
    }

    protected
    {
        static SocketUdpClient clientSocket;
    }

    override ChannelHandler newHandler(Logging logging) => new ClientUdpHandler(logging);

    override void run()
    {
        super.run;

        clientSocket = new SocketUdpClient(logging, host, port);
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

    // static extern (C) void sigintHandler(int signo)
    // {
    //     import std.stdio : writefln;

    //     writefln("^C pressed. Client socket '%s'", [
    //             clientSocket.fd
    //         ]);

    //     if (loop)
    //     {
    //         loop.stop;
    //         loop.dispose;
    //         loop = null;
    //     }

    //     if (clientSocket)
    //     {
    //         clientSocket.stop;
    //         clientSocket.dispose;
    //         clientSocket = null;
    //     }

    //     exit(0);
    // }

}
