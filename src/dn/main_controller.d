module dn.main_controller;

import core.controllers.controller : Controller;
import core.components.uni_component : UniComponent;

import dn.net.sockets.socket_tcp_server : SocketTcpServer;
import dn.io.loops.event_loop : EventLoop;
import dn.io.loops.pool_pipeline_event_loop : PoolPipelineEventLoop;
import dn.channels.pipes.pipleline : Pipeline;
import dn.channels.handlers.channel_handler : ChannelHandler;

import core.stdc.stdlib : exit;

import signal_libs;

/**
 * Authors: initkfs
 */
class MainController : Controller!UniComponent
{
    protected
    {
        static SocketTcpServer serverSocket;
        static PoolPipelineEventLoop loop;
    }

    override void run()
    {
        super.run;

        signal(SIGINT, &sigintHandler);

        serverSocket = new SocketTcpServer(logger);
        serverSocket.initialize;
        serverSocket.create;
        serverSocket.run;

        loop = new PoolPipelineEventLoop(logger, serverSocket.fd, () {
            
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
        assert(serverSocket);

        writefln("^C pressed. Server socket '%s'", serverSocket.fd);

        loop.stop;
        loop.dispose;

        serverSocket.stop;
        serverSocket.dispose;

        exit(0);
    }

}
