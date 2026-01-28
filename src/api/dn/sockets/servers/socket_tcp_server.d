module api.dn.sockets.servers.socket_tcp_server;

import api.dn.sockets.base_socket_wrapper : BaseSocketWrapper;

import api.core.loggers.logging : Logging;
import std.string : toStringz;

import socket_libs;
import err_libs;

/**
 * Authors: initkfs
 */
class SocketTcpServer : BaseSocketWrapper
{
    //TCP_USER_TIMEOUT = TCP_KEEPIDLE + TCP_KEEPINTVL * TCP_KEEPCNT
    int keepAliveSentIfNoActivitySec = 5;
    int keepAliveIntervalSec = 5;
    int keepAliveMaxFail = 3;

    int backlog = 10;

    this(Logging logging, string host = "127.0.0.1", string port = "8080")
    {
        super(logging, host, port);
    }

    override void create()
    {
        super.create;

        sockaddr_in addr;

        addr.sin_family = PF_INET;

        import std.conv: to;

        addr.sin_port = htons(port.to!ushort);

        //INADDR_ANY
        addr.sin_addr.s_addr = inet_addr(host.toStringz);

        auto socketType = SOCK_STREAM;
        if (!isBlocking)
        {
            socketType |= SOCK_NONBLOCK;
        }

        _fd = socket(PF_INET, socketType, IPPROTO_TCP);
        if (_fd < 0)
        {
            throw new Exception("Socket creating error: " ~ getLastErrorNew);
        }

        setCommonOptions;

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

        if (bind(_fd, cast(sockaddr*)&addr, addr.sizeof) != 0)
        {
            dispose;
            throw new Exception("Socket binding error: " ~ getLastErrorNew);
        }
    }
    

    override void run()
    {
        super.run;

        if (listen(_fd, backlog) != 0)
        {
            dispose;
            throw new Exception("Socket listen error: " ~ getLastErrorNew);
        }

        logger.infof("Bind server %s:%d", host, port);
    }
}
