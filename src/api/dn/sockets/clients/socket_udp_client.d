module api.dn.sockets.clients.socket_udp_client;

import api.dn.sockets.clients.base_socket_client : BaseSocketClient;
import api.core.loggers.logging : Logging;
import socket_libs;
import err_libs;

/**
 * Authors: initkfs
 */
class SocketUdpClient : BaseSocketClient
{
    this(Logging logging, string host, string port, string addrtype = "domain")
    {
        super(logging, host, port, addrtype);
    }

    override void create()
    {
        super.create;

        addrinfo hints;
        hints.ai_family = PF_UNSPEC;
        hints.ai_socktype = SOCK_DGRAM;

        createSocket(&hints);
    }

    void sendUDP(const(void)[] data)
    {
        if (sendto(_fd, data.ptr, data.length, 0,
                addrInfo.ai_addr, cast(socklen_t) addrInfo.ai_addrlen) == -1)
        {
            throw new Exception("UDP send error: " ~ getLastErrorNew);
        }
    }

    ubyte[] receiveUDPNew(size_t maxSize = 65507)
    {
        auto buffer = new ubyte[maxSize];
        sockaddr_in senderAddr;
        socklen_t addrLen = senderAddr.sizeof;

        auto received = recvfrom(_fd, buffer.ptr, maxSize, 0,
            cast(sockaddr*)&senderAddr, &addrLen);

        if (received == -1)
        {
            throw new Exception("UDP receive error: " ~ getLastErrorNew);
        }

        return buffer[0 .. received];
    }
}
