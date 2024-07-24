module app.dn.net.sockets.socket_tcp_server;

import app.core.components.units.services.loggable_unit : LoggableUnit;

import std.logger : Logger;
import std.socket;

/**
 * Authors: initkfs
 */
class SocketTcpServer : LoggableUnit
{
    string host = "127.0.0.1";
    ushort port = 8080;
    int keepAliveSentNoActivitySec = 600;
    int keepAliveIntervalSec = 60;
    bool isBlocking;
    int sendTimeoutSec = 10;
    int readTimeoutSec = 10;
    int backlog = 10;

    protected
    {
        TcpSocket _socket;
    }

    this(Logger logger)
    {
        super(logger);
    }

    override void create()
    {
        super.create;
        _socket = new TcpSocket();

        _socket.setKeepAlive(keepAliveSentNoActivitySec, keepAliveIntervalSec);
        _socket.blocking = isBlocking;

        _socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
        _socket.setOption(SocketOptionLevel.TCP, SocketOption.TCP_NODELAY, 1);

        import core.time : dur;

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
