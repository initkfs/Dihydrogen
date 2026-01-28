module api.dn.protos.http1.clients.http_client;
/**
 * Authors: initkfs
 */
import api.dn.handlers.clients.base_handler_client: BaseHandlerClient;

import api.dn.sockets.clients.socket_tcp_client : SocketTcpClient;
import api.dn.protos.http1.handlers.clients.clients_http_handler : ClientHttpHandler;
import api.dn.io.loops.event_loop : EventLoop;
import api.dn.io.loops.client_loop : ClientLoop;
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

class HTTPClient : BaseHandlerClient
{
    this()
    {
        host = "127.0.0.1";
        port = "80";
    }

    protected
    {
        static SocketTcpClient clientSocket;
        
    }

    override ChannelHandler newHandler(Logging logging)
    {
        return new ClientHttpHandler(logging);
    }

    override void run()
    {
        super.run;

        clientSocket = new SocketTcpClient(logging, host, port);
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
    //         clientSocket.fd
    //     ]);

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
