module api.dn.protos.http1.servers.base_http_server;
/**
 * Authors: initkfs
 */
import api.dn.servers.base_server: BaseServer;

import api.dn.sockets.servers.socket_tcp_server : SocketTcpServer;

import api.core.loggers.logging : Logging;

abstract class BaseHTTPServer : BaseServer
{
    protected
    {
        SocketTcpServer[] serverSockets;
    }
}
