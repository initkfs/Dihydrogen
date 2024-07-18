module dn.main_controller;

import core.controllers.controller : Controller;
import core.components.uni_component : UniComponent;

import dn.net.sockets.socket_tcp_server : SocketTcpServer;
import dn.io.loops.event_loop : EventLoop;
import dn.io.loops.pool_pipeline_event_loop : PoolPipelineEventLoop;
import dn.channels.pipes.pipleline : Pipeline;
import dn.channels.handlers.channel_handler : ChannelHandler;
import dn.channels.server_channel: ServerChannel;
import core.stdc.stdlib : exit;

import signal_libs;

/**
 * Authors: initkfs
 */
class MainController : Controller!UniComponent
{
    protected
    {
        static SocketTcpServer serverSocket1;
        static SocketTcpServer serverSocket2;
        static PoolPipelineEventLoop loop;
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

        loop = new PoolPipelineEventLoop(logger, [
            ServerChannel(serverSocket1.fd, serverSocket1.port), 
            ServerChannel(serverSocket2.fd, serverSocket2.port)
            ], () {
            
            import core.stdc.stdlib : malloc;
            import core.lifetime: emplace;

            auto pipelineSize = __traits(classInstanceSize, Pipeline);
            auto pipelinePtr = malloc(pipelineSize)[0..pipelineSize];
            auto pipeline = emplace!(Pipeline)(pipelinePtr);

            auto handlerSize = __traits(classInstanceSize, ChannelHandler);
            auto handlerPtr = malloc(handlerSize)[0..handlerSize];
            auto handler = emplace!(ChannelHandler)(handlerPtr);

            pipeline.add(handler);
            return pipeline;
        }, (pipeline){
            auto currHandler = pipeline.first;
            while(currHandler){
                import core.stdc.stdlib : free;
                auto curr = currHandler;
                currHandler = currHandler.next;
                destroy(curr);
                free(cast(void*) curr);

                free(cast(void*) pipeline);
            }
        });
        loop.initialize;
        loop.create;
        loop.run;
    }

    static extern (C) void sigintHandler(int signo)
    {
        import std.stdio : writefln;

        assert(loop);
        assert(serverSocket1);
        assert(serverSocket2);

        writefln("^C pressed. Server socket '%s'", [serverSocket1.fd, serverSocket2.fd]);

        loop.stop;
        loop.dispose;

        serverSocket1.stop;
        serverSocket1.dispose;

        serverSocket2.stop;
        serverSocket2.dispose;

        exit(0);
    }

}
