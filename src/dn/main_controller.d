module dn.main_controller;

import core.controllers.controller : Controller;
import core.components.uni_component : UniComponent;

import dn.net.sockets.socket_tcp_server : SocketTcpServer;
import dn.io.loops.event_loop : EventLoop;

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
        static EventLoop loop;
    }

    override void run()
    {
        super.run;

        signal(SIGINT, &sigintHandler);

        serverSocket = new SocketTcpServer(logger);
        serverSocket.initialize;
        serverSocket.create;
        serverSocket.run;

        loop = new EventLoop(logger, serverSocket.fd);
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
