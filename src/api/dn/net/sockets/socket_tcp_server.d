module api.dn.net.sockets.socket_tcp_server;

import api.core.components.units.services.loggable_unit : LoggableUnit;

import api.core.loggers.logging : Logging;
import std.socket;

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
        TcpSocket _socket;
    }

    this(Logging logging)
    {
        super(logging);
    }

    override void create()
    {
        super.create;
        _socket = new TcpSocket();

        _socket.setKeepAlive(keepAliveSentIfNoActivitySec, keepAliveIntervalSec);
        _socket.blocking = isBlocking;

        _socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
        _socket.setOption(SocketOptionLevel.TCP, SocketOption.TCP_NODELAY, 1);

        import core.time : dur;

        //setsockopt(sd, IPPROTO_TCP, TCP_SYNCNT, 6);

        _socket.setOption(SocketOptionLevel.SOCKET, SocketOption.SNDTIMEO, sendTimeoutSec
                .dur!"seconds");
        _socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, readTimeoutSec
                .dur!"seconds");

        version (linux)
        {
            assert(_socket.handle);

            import socket_libs;

            int optValue = 1;
            if (setsockopt(_socket.handle, IPPROTO_TCP, TCP_QUICKACK, &optValue, optValue
                    .sizeof) == -1)
            {
                throw new Exception("TCP_QUICKACK");
            }

            optValue = keepAliveMaxFail;
            if (setsockopt(_socket.handle, IPPROTO_TCP, TCP_KEEPCNT, &optValue, optValue
                    .sizeof) == -1)
            {
                throw new Exception("TCP_KEEPCNT");
            }

        }

    }

    override void run()
    {
        super.run;
        assert(_socket);
        _socket.bind(new InternetAddress(host, port));
        _socket.listen(backlog);

        logger.infof("Bind server %s:%d", host, port);
    }

    int fd()
    {
        assert(_socket);
        return _socket.handle;
    }

    void close()
    {
        assert(_socket);
        _socket.close;
        _socket = null;
    }

}
