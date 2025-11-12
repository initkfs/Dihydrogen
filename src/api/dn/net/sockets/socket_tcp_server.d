module api.dn.net.sockets.socket_tcp_server;

import api.core.components.units.services.loggable_unit : LoggableUnit;

import api.core.loggers.logging : Logging;
import std.string : toStringz;

import socket_libs;
import err_libs;

/**
 * Authors: initkfs
 */
class SocketTcpServer : LoggableUnit
{
    string host = "127.0.0.1";

    ushort port = 8080;
    //TCP_USER_TIMEOUT = TCP_KEEPIDLE + TCP_KEEPINTVL * TCP_KEEPCNT
    int keepAliveSentIfNoActivitySec = 5;
    int keepAliveIntervalSec = 5;
    int keepAliveMaxFail = 3;
    bool isBlocking;

    //http\https: 5-30 sec = 1-5 handshake + 10-30 read\write 
    int sendTimeoutSec = 5;
    int readTimeoutSec = 5;

    int backlog = 10;

    protected
    {
        int _sd;
    }

    this(Logging logging)
    {
        super(logging);
    }

    override void create()
    {
        super.create;

        sockaddr_in addr;

        addr.sin_family = PF_INET;
        addr.sin_port = htons(port);

        //INADDR_ANY
        addr.sin_addr.s_addr = inet_addr(host.toStringz);

        auto socketType = SOCK_STREAM;
        if (!isBlocking)
        {
            socketType |= SOCK_NONBLOCK;
        }

        _sd = socket(PF_INET, socketType, IPPROTO_TCP);
        if (_sd < 0)
        {
            throw new Exception("Socket creating error: " ~ getLastErrorNew);
        }

        int opt = 1;
        setOption(_sd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, opt.sizeof);
        setOption(_sd, SOL_SOCKET, SO_KEEPALIVE, &opt, opt.sizeof);
        setOption(_sd, IPPROTO_TCP, TCP_QUICKACK, &opt, opt.sizeof);

        setOption(_sd, IPPROTO_TCP, TCP_KEEPIDLE, &keepAliveSentIfNoActivitySec, keepAliveSentIfNoActivitySec
                .sizeof);
        setOption(_sd, IPPROTO_TCP, TCP_KEEPINTVL, &keepAliveIntervalSec, keepAliveIntervalSec
                .sizeof);
        setOption(_sd, IPPROTO_TCP, TCP_KEEPCNT, &keepAliveMaxFail, keepAliveMaxFail.sizeof);

        //int synCount = 6;
        //setOption(_sd, IPPROTO_TCP, TCP_SYNCNT, &synCount, synCount.sizeof); //client

        int disable = 0;
        setOption(_sd, IPPROTO_TCP, TCP_NODELAY, &disable, disable.sizeof);

        import time_libs;

        timeval sendTimeout;
        sendTimeout.tv_sec = sendTimeoutSec;

        setOption(_sd, SOL_SOCKET, SO_SNDTIMEO, &sendTimeout, sendTimeout.sizeof);

        timeval readTimeout;
        readTimeout.tv_sec = readTimeoutSec;
        setOption(_sd, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, readTimeout.sizeof);

        if (bind(_sd, cast(sockaddr*)&addr, addr.sizeof) != 0)
        {
            dispose;
            throw new Exception("Socket binding error: " ~ getLastErrorNew);
        }
    }

    bool isBlockingMode()
    {
        import stdio_libs;

        int flags = fcntl(_sd, F_GETFL, 0);
        if (flags == -1)
        {
            return false;
        }

        if (flags & O_NONBLOCK)
        {
            return true;
        }
        return false;
    }

    void setOption(int socket, int level, int optionName,
        const void* optionValue, socklen_t optionLen)
    {
        if (setsockopt(socket, level, optionName, optionValue, optionLen) == -1)
        {
            throw new Exception("Socket option error: ", getLastErrorNew);
        }
    }

    string getLastErrorNew()
    {
        import std.string : fromStringz;

        return strerror(errno).fromStringz.idup;
    }

    override void run()
    {
        super.run;

        if (listen(_sd, backlog) != 0)
        {
            dispose;
            throw new Exception("Socket listen error: " ~ getLastErrorNew);
        }

        logger.infof("Bind server %s:%d", host, port);
    }

    int fd()
    {
        assert(isCreated || isRunning);
        return _sd;
    }

    override void dispose()
    {
        super.dispose;

        if (close(_sd) == -1)
        {
            logger.errorf("Error closing socket %d: %s", _sd, getLastErrorNew);
        }
        else
        {
            logger.trace("Close socket: ", _sd);
        }
    }

}
