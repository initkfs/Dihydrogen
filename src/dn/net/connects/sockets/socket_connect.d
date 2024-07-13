module dn.net.connects.sockets.socket_connect;

/**
 * Authors: initkfs
 */
enum SocketConnectState : int
{
    none,
    accept,
    close,
    read,
    write
}
