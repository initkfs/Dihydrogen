module dn.io.loops.event_loop;

import std.stdio : writeln, writefln;
import std.string : toStringz, fromStringz;

import io_uring_libs;
import socket_libs;

import core.stdc.stdlib: malloc, exit;
import  core.stdc.string: memset, strerror;

import dn.io.natives.iouring.io_uring;
import dn.io.natives.iouring.io_uring_types;

import std.conv : to;
import std.string : toStringz, fromStringz;
import std.logger;

import core.components.units.services.loggable_unit: LoggableUnit;
import dn.net.connects.pools.linear_connect_pool : LinearConnectPool;
import dn.net.connects.fd_connect : FdConnect, FdConnectType;
import dn.net.sockets.socket_connect: SocketConnectState;

class EventLoop: LoggableUnit
{
    enum backlog = 512;
    enum maxMessageLen = 2048;
    enum iourintFeatFastPollFlag = (1U << 5);

    int serverSocket;

    FdConnect!maxMessageLen* socketConnect;

    this(Logger logger, int serverSocket)
    {
        super(logger);
        this.serverSocket = serverSocket;
    }

    override void run()
    {
        super.run;

        logger.infof("Liburing version: %d.%d", io_uring_major_version, io_uring_minor_version);

        auto connPoolSize = 100;

        LinearConnectPool!(FdConnect!maxMessageLen*) connPool = new LinearConnectPool!(
            FdConnect!maxMessageLen*)(
            connPoolSize);
        connPool.create;

        foreach (i; 0 .. connPool.count)
        {
            connPool.set(i, newConnection);
        }

        // signal(SIGINT, &sigintHandler);

        ushort portno = 8080;
        sockaddr_in client_addr;
        socklen_t client_len = (client_addr).sizeof;

        logger.infof("Listen: 127.0.0.1:%d", portno);

        io_uring_params params;
        io_uring ring;
        memset(&params, 0, params.sizeof);

        auto initRet = io_uring_queue_init_params(4096, &ring, &params);
        if (initRet < 0)
        {
            logger.errorf("Init uring queue error: %s", strerror(-initRet).fromStringz);
            exit(1);
        }

        if (!(params.features & iourintFeatFastPollFlag))
        {
            logger.error("io_urint fast poll not available in the kernel, quiting...\n");
            return;
        }

        socketConnect = newConnection;
        socketConnect.fd = serverSocket;
        addSocketAccept(&ring, socketConnect, cast(sockaddr*)&client_addr, &client_len);

        while (true)
        {
            io_uring_cqe* cqe;
            int ret;

            io_uring_submit(&ring);

            ret = io_uring_wait_cqe(&ring, &cqe);
            if (ret < 0)
            {
                logger.error("io_uring_wait_cqe error");
                io_uring_cqe_seen(&ring, cqe);
                continue;
            }

            if (cqe.res < 0)
            {
                auto errorConn = cast(FdConnect!maxMessageLen*) io_uring_cqe_get_data(cqe);
                assert(errorConn);
                logger.errorf("Async request failed with fd %s, state '%s': %s", errorConn.fd, errorConn.state, strerror(
                        -cqe.res).fromStringz);
                io_uring_cqe_seen(&ring, cqe);
                continue;
            }

            io_uring_cqe*[backlog] cqes;

            int cqe_count = io_uring_peek_batch_cqe(&ring, cqes.ptr, cqes.length);

            for (int i = 0; i < cqe_count; ++i)
            {
                cqe = cqes[i];

                auto connection = cast(FdConnect!maxMessageLen*) io_uring_cqe_get_data(cqe);

                unsigned type = connection.state;
                final switch (type) with (SocketConnectState)
                {
                    case accept:
                        int acceptSocketFd = cqe.res;

                        if (!connPool.hasIndex(acceptSocketFd))
                        {
                            if (!connPool.increase)
                            {
                                logger.error("Error change buffer size");
                                exit(1);
                            }
                        }

                        auto conn = connPool.get(acceptSocketFd);
                        if (!conn)
                        {
                            auto newConnect = newConnection(acceptSocketFd);
                            connPool.set(acceptSocketFd, newConnect);
                            conn = newConnect;
                        }
                        else
                        {
                            if (conn.fd == -1)
                            {
                                conn.fd = acceptSocketFd;
                            }
                            conn.state = SocketConnectState.none;
                            conn.availableBytes = 0;
                        }

                        assert(conn);

                        addSocketReadv(&ring, conn);
                        addSocketAccept(&ring, socketConnect, cast(sockaddr*)&client_addr, &client_len);
                        break;
                    case read:
                        int bytes_read = cqe.res;

                        if (bytes_read <= 0)
                        {
                            logger.trace("End read, close connection");
                            connPool.set(connection.fd, null);
                            addSocketClose(&ring, connection);
                            //free(connection);
                            //shutdown(connection.fd, SHUT_RDWR);
                        }
                        else
                        {
                            auto buffSize = bytes_read;
                            if (buffSize > connection.buff.sizeof)
                            {
                                connection.availableBytes = connection.buff.sizeof;
                            }
                            else
                            {
                                connection.availableBytes = buffSize;
                            }

                            //writefln("Recieved fd %s: [%s]", connection.fd, bufs[connection.fd][0..bytes_read]);
                            addSocketWrite(&ring, connection);
                        }
                        break;
                    case write:
                        logger.trace("End write, close connection");
                        connPool.set(connection.fd, null);
                        addSocketClose(&ring, connection);
                        //close(connection.fd);
                        //free(connection);
                        //shutdown(connection.fd, SHUT_RDWR);
                        // addSocketReadv(&ring, connection.fd, maxMessageLen);
                        break;
                    case close:
                        break;
                }
            }

            io_uring_cq_advance(&ring, cqe_count);
        }

        logger.info("Exit");
    }

    FdConnect!maxMessageLen* newConnection(int fd = -1, SocketConnectState state = SocketConnectState.none)
    {
        auto mustBePtr = malloc(FdConnect!maxMessageLen.sizeof);
        if (!mustBePtr)
        {
            logger.error("Allocate connection error");
            exit(1);
        }
        auto newConn = cast(FdConnect!maxMessageLen*) mustBePtr;
        newConn.type = FdConnectType.socket;
        newConn.fd = fd;
        newConn.state = state;
        newConn.availableBytes = 0;
        //newConn.buff = 0;
        return newConn;
    }

    void addSocketClose(io_uring* ring, FdConnect!maxMessageLen* conn)
    {
        conn.state = SocketConnectState.close;
        io_uring_sqe* sqe = io_uring_get_sqe(ring);
        io_uring_prep_close(sqe, conn.fd);
        io_uring_sqe_set_data(sqe, conn);
    }

    void addSocketAccept(io_uring* ring, FdConnect!maxMessageLen* conn, sockaddr* client_addr, socklen_t* client_len)
    {
        conn.state = SocketConnectState.accept;
        io_uring_sqe* sqe = io_uring_get_sqe(ring);
        io_uring_prep_accept(sqe, conn.fd, client_addr, client_len, 0);
        io_uring_sqe_set_data(sqe, conn);
    }

    void addSocketReadv(io_uring* ring, FdConnect!maxMessageLen* conn)
    {
        io_uring_sqe* sqe = io_uring_get_sqe(ring);
        io_uring_prep_recv(sqe, conn.fd, &conn.buff, conn.buff.sizeof, 0);
        conn.state = SocketConnectState.read;
        io_uring_sqe_set_data(sqe, conn);
    }

    enum response = "HTTP/1.1 200 OK\r\nContent-Length: 13\r\nConnection: close\r\n\r\nHello, world!";

    void addSocketWrite(io_uring* ring, FdConnect!maxMessageLen* conn)
    {
        conn.state = SocketConnectState.write;
        io_uring_sqe* sqe = io_uring_get_sqe(ring);
        io_uring_prep_send(sqe, conn.fd, cast(const(void*)) response.ptr, response.length, 0);
        io_uring_sqe_set_data(sqe, conn);
    }

}
