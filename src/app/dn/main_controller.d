module app.dn.main_controller;

import app.core.controllers.controller : Controller;
import app.core.components.uni_component : UniComponent;

import app.dn.net.sockets.socket_tcp_server : SocketTcpServer;
import app.dn.io.loops.event_loop : EventLoop;
import app.dn.io.loops.pool_pipeline_event_loop : PoolPipelineEventLoop;
import app.dn.io.loops.multi_event_loop : MultiEventLoop;
import app.dn.io.loops.one_pipeline_event_loop: OnePipelineEventLoop;
import app.dn.channels.pipes.pipeline : Pipeline;
import app.dn.channels.handlers.channel_handler : ChannelHandler;
import app.dn.channels.server_channel : ServerChannel;
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
        static OnePipelineEventLoop loop;
    }

    static Pipeline createPipeline()
    {
        auto pipe = new Pipeline;
        pipe.add(new ChannelHandler);
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

        loop = new OnePipelineEventLoop(logger, [
            ServerChannel(serverSocket1.fd, serverSocket1.port),
            ServerChannel(serverSocket2.fd, serverSocket2.port)
        ], createPipeline);

        // loop = new PoolPipelineEventLoop(logger, [
        //     ServerChannel(serverSocket1.fd, serverSocket1.port), 
        //     ServerChannel(serverSocket2.fd, serverSocket2.port)
        //     ], () {

        //     import app.core.stdc.stdlib : malloc;
        //     import app.core.lifetime: emplace;

        //     auto pipelineSize = __traits(classInstanceSize, Pipeline);
        //     auto pipelinePtr = malloc(pipelineSize)[0..pipelineSize];
        //     auto pipeline = emplace!(Pipeline)(pipelinePtr);

        //     auto handlerSize = __traits(classInstanceSize, ChannelHandler);
        //     auto handlerPtr = malloc(handlerSize)[0..handlerSize];
        //     auto handler = emplace!(ChannelHandler)(handlerPtr);

        //     pipeline.add(handler);
        //     return pipeline;
        // }, (pipeline){
        //     auto currHandler = pipeline.first;
        //     while(currHandler){
        //         import app.core.stdc.stdlib : free;
        //         auto curr = currHandler;
        //         currHandler = currHandler.next;
        //         destroy(curr);
        //         free(cast(void*) curr);

        //         free(cast(void*) pipeline);
        //     }
        // });
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

        writefln("^C pressed. Server socket '%s'", [
            serverSocket1.fd, serverSocket2.fd
        ]);

        loop.stop;
        loop.dispose;

        serverSocket1.stop;
        serverSocket1.dispose;

        serverSocket2.stop;
        serverSocket2.dispose;

        exit(0);
    }

}
