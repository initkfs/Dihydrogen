module api.dn.net.sockets.socket_udp_client;

import api.core.components.units.services.loggable_unit : LoggableUnit;

import api.core.loggers.logging : Logging;
import std.string : toStringz, fromStringz;

import std.stdio : writeln, writefln;

import socket_libs;
import err_libs;

/**
 * Authors: initkfs
 */
class SocketUdpClient : LoggableUnit
{
    string host = "127.0.0.1";
    ushort port = 80;
    char* strport;
    string addrtype = "domain";

    //http\https: 5-30 sec = 1-5 handshake + 10-30 read\write 
    int sendTimeoutSec = 5;
    int readTimeoutSec = 5;

    sockaddr_in addr;

    bool isBlocking;

    addrinfo* p;

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

        addrinfo hints;
        hints.ai_family = PF_UNSPEC;
        hints.ai_socktype = SOCK_DGRAM;

        addrinfo* servinfo;

        import std.conv : to;

        strport = port.to!(char[]).ptr;

        int rv;
        if ((rv = getaddrinfo(host.toStringz, addrtype.toStringz, &hints, &servinfo)) != 0)
        {
            import std.format : format;

            throw new Exception(format("getaddrinfo, %s, port %s: %s", host, port, gai_strerror(rv)
                    .fromStringz.idup));
        }

        p = servinfo;
        if (!p)
        {
            throw new Exception("First address empty");
        }

        // writeln(p.ai_family, " ", p.ai_socktype, " ", p.ai_addr, " ", p.ai_addrlen);

        auto socketType = p.ai_socktype;
        if (!isBlocking)
        {
            socketType |= SOCK_NONBLOCK;
        }

        _sd = socket(p.ai_family, socketType, p.ai_protocol);
        if (_sd < 0)
        {
            throw new Exception("Socket creating error: " ~ getLastErrorNew);
        }

        int opt = 1;
        setOption(_sd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, opt.sizeof);

        import time_libs;

        timeval sendTimeout;
        sendTimeout.tv_sec = sendTimeoutSec;

        setOption(_sd, SOL_SOCKET, SO_SNDTIMEO, &sendTimeout, sendTimeout.sizeof);

        timeval readTimeout;
        readTimeout.tv_sec = readTimeoutSec;
        setOption(_sd, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, readTimeout.sizeof);

        //int recvBufSize = 1024 * 1024; // 1 MB
        //setOption(_sd, SOL_SOCKET, SO_RCVBUF, &recvBufSize, recvBufSize.sizeof);

        //int sendBufSize = 1024 * 1024; // 1 MB
        //setOption(_sd, SOL_SOCKET, SO_SNDBUF, &sendBufSize, sendBufSize.sizeof);
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

        int res = connect(_sd, p.ai_addr, p.ai_addrlen);
        if (res < 0 && errno != EINPROGRESS)
        {
            throw new Exception("Connection failed: " ~ getLastErrorNew);
        }

        logger.infof("Connect server %s:%d", host, port);
    }

    void sendUDP(const(void)[] data)
    {
        if (sendto(_sd, data.ptr, data.length, 0,
                p.ai_addr, cast(socklen_t) p.ai_addrlen) == -1)
        {
            throw new Exception("UDP send error: " ~ getLastErrorNew);
        }
    }

    ubyte[] receiveUDP(size_t maxSize = 65507)
    {
        auto buffer = new ubyte[maxSize];
        sockaddr_in senderAddr;
        socklen_t addrLen = senderAddr.sizeof;

        auto received = recvfrom(_sd, buffer.ptr, maxSize, 0,
            cast(sockaddr*)&senderAddr, &addrLen);

        if (received == -1)
        {
            throw new Exception("UDP receive error: " ~ getLastErrorNew);
        }

        return buffer[0 .. received];
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
