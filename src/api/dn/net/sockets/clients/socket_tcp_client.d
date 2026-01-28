module api.dn.net.sockets.clients.socket_tcp_client;

import api.dn.net.sockets.clients.base_socket_client : BaseSocketClient;

import api.core.loggers.logging : Logging;
import std.string : toStringz, fromStringz;

import std.stdio : writeln, writefln;

import socket_libs;
import err_libs;

/**
 * Authors: initkfs
 */
class SocketTcpClient : BaseSocketClient
{
    //TCP_USER_TIMEOUT = TCP_KEEPIDLE + TCP_KEEPINTVL * TCP_KEEPCNT
    int keepAliveSentIfNoActivitySec = 5;
    int keepAliveIntervalSec = 5;
    int keepAliveMaxFail = 3;

    int backlog = 10;

    this(Logging logging, string host = "127.0.0.1", string port = "80", string addrtype = "http")
    {
        super(logging, host, port, addrtype);
    }

    override void create()
    {
        super.create;

        addrinfo hints;
        hints.ai_family = PF_UNSPEC;
        hints.ai_socktype = SOCK_STREAM;
        //hints.ai_flags = AI_NUMERICSERV;

        createSocket(&hints);

        int opt = 1;
        setOption(_fd, SOL_SOCKET, SO_KEEPALIVE, &opt, opt.sizeof);
        setOption(_fd, IPPROTO_TCP, TCP_QUICKACK, &opt, opt.sizeof);
        setOption(_fd, IPPROTO_TCP, TCP_KEEPIDLE, &keepAliveSentIfNoActivitySec, keepAliveSentIfNoActivitySec
                .sizeof);
        setOption(_fd, IPPROTO_TCP, TCP_KEEPINTVL, &keepAliveIntervalSec, keepAliveIntervalSec
                .sizeof);
        setOption(_fd, IPPROTO_TCP, TCP_KEEPCNT, &keepAliveMaxFail, keepAliveMaxFail.sizeof);

        //int synCount = 6;
        //setOption(_fd, IPPROTO_TCP, TCP_SYNCNT, &synCount, synCount.sizeof); //client

        int disable = 0;
        setOption(_fd, IPPROTO_TCP, TCP_NODELAY, &disable, disable.sizeof);
    }
}
