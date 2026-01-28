module api.dn.sockets.socket_connect;

/**
 * Authors: initkfs
 */
enum SocketConnectState : int
{
    none,
    accept,
    close,
    read,
    write,
    splice,
    cancel,
    timeout
}
