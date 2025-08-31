module api.dn.channels.fd_file;

import api.dn.net.sockets.socket_connect : SocketConnectState;

/**
 * Authors: initkfs
 */

struct FdFile
{
    int fd;
    long size;
    int[2] pipes;
    ubyte[] buff;
}
