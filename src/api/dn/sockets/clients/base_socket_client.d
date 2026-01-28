module api.dn.sockets.clients.base_socket_client;

import api.dn.sockets.base_socket_wrapper : BaseSocketWrapper;
import api.core.components.units.services.loggable_unit : LoggableUnit;
import api.core.loggers.logging : Logging;

import socket_libs;
import err_libs;

/**
 * Authors: initkfs
 */

class BaseSocketClient : BaseSocketWrapper
{
    string addrtype;

    sockaddr_in addr;

    addrinfo* addrInfo;

    this(Logging logging, string host, string port, string addrtype)
    {
        super(logging, host, port);
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

        setCommonOptions;
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

        import std.string : toStringz, fromStringz;

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

    override void dispose()
    {
        super.dispose;

        if (addrInfo)
        {
            freeaddrinfo(addrInfo);
        }
    }
}
