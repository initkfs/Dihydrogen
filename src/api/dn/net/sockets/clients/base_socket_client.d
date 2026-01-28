module api.dn.net.sockets.clients.base_socket_client;

import api.core.components.units.services.loggable_unit : LoggableUnit;
import api.core.loggers.logging : Logging;

import socket_libs;
import err_libs;

/**
 * Authors: initkfs
 */

class BaseSocketClient : LoggableUnit
{
    string host;
    string port;
    string addrtype;

    //http\https: 5-30 sec = 1-5 handshake + 10-30 read\write 
    int sendTimeoutSec = 5;
    int readTimeoutSec = 5;

    sockaddr_in addr;

    bool isBlocking;

    addrinfo* addrInfo;

    protected
    {
        int _fd;
    }

    this(Logging logging, string host, string port, string addrtype)
    {
        super(logging);

        this.host = host;
        this.port = port;
        this.addrtype = addrtype;
    }

    override void run()
    {
        super.run;

        int res = connect(_fd, addrInfo.ai_addr, addrInfo.ai_addrlen);
        if (res < 0 && errno != EINPROGRESS)
        {
            throw new Exception("Connection failed: " ~ getLastErrorNew);
        }

        logger.infof("Connect socket %s:%s", host, port);
    }

    void createSocket(addrinfo* addr)
    {
        checkAddrinfo(addr);

        auto socketType = addrInfo.ai_socktype;
        if (!isBlocking)
        {
            socketType |= SOCK_NONBLOCK;
        }

        _fd = socket(addrInfo.ai_family, socketType, addrInfo.ai_protocol);
        if (_fd < 0)
        {
            throw new Exception("Socket creating error: " ~ getLastErrorNew);
        }

        int opt = 1;
        setOption(_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, opt.sizeof);

        import time_libs;

        timeval sendTimeout;
        sendTimeout.tv_sec = sendTimeoutSec;

        setOption(_fd, SOL_SOCKET, SO_SNDTIMEO, &sendTimeout, sendTimeout.sizeof);

        timeval readTimeout;
        readTimeout.tv_sec = readTimeoutSec;
        setOption(_fd, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, readTimeout.sizeof);

        //int recvBufSize = 1024 * 1024; // 1 MB
        //setOption(_fd, SOL_SOCKET, SO_RCVBUF, &recvBufSize, recvBufSize.sizeof);

        //int sendBufSize = 1024 * 1024; // 1 MB
        //setOption(_fd, SOL_SOCKET, SO_SNDBUF, &sendBufSize, sendBufSize.sizeof);
    }

    void checkAddrinfo(addrinfo* hints)
    {
        addrInfo = checkAddrinfo(host, addrtype, hints);
        assert(addrInfo);

        //writeln(addrInfo.ai_family, " ", addrInfo.ai_socktype, " ", addrInfo.ai_addr, " ", addrInfo.ai_addrlen);
    }

    addrinfo* checkAddrinfo(string host, string addrtype, addrinfo* hints)
    {
        addrinfo* servinfo;

        import std.string: toStringz, fromStringz;

        int rv;
        if ((rv = getaddrinfo(host.toStringz, addrtype.toStringz, hints, &servinfo)) != 0)
        {
            import std.format : format;

            throw new Exception(format("getaddrinfo, %s, port %s: %s", host, port, gai_strerror(rv)
                    .fromStringz.idup));
        }

        if (!servinfo)
        {
            throw new Exception("First address empty");
        }

        return servinfo;
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

    int fd()
    {
        assert(isCreated || isRunning);
        return _fd;
    }

    override void dispose()
    {
        super.dispose;

        if (addrInfo)
        {
            freeaddrinfo(addrInfo);
        }

        if (close(_fd) == -1)
        {
            logger.errorf("Error closing socket %d: %s", _fd, getLastErrorNew);
        }
        else
        {
            logger.trace("Close socket: ", _fd);
        }
    }
}
