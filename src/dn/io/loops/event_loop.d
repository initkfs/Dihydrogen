module dn.io.loops.event_loop;

import std.stdio : writeln, writefln;
import std.string : toStringz, fromStringz;

import io_uring_libs;
import socket_libs;

import core.stdc.stdlib : malloc, exit;
import core.stdc.string : memset, strerror;

import dn.io.natives.iouring.io_uring;
import dn.io.natives.iouring.io_uring_types;

import std.conv : to;
import std.string : toStringz, fromStringz;
import std.logger;

import core.components.units.services.loggable_unit : LoggableUnit;
import dn.pools.linear_pool : LinearPool;
import dn.channels.fd_channel : FdChannel, FdChannelType;
import dn.net.sockets.socket_connect : SocketConnectState;
import dn.channels.contexts.channel_context : ChannelContext, ChannelContextType;

import dn.channels.server_channel : ServerChannel;

/**
 * Authors: initkfs
 */
class EventLoop : LoggableUnit
{
    enum backlog = 512;
    enum maxMessageLen = 2048;
    enum iourintFeatFastPollFlag = (1U << 5);

    bool isTraceEvents;

    int channelsPoolSize = 100;

    ServerChannelData[int] channelsMap;

    io_uring ring;

    this(Logger logger, ServerChannel[] serverChannels)
    {
        super(logger);
        //TODO move to create()
        foreach (serverChannel; serverChannels)
        {
            assert(serverChannel.fd >= 0);
            auto serverSocket = newChannel(serverChannel.fd);
            auto pool = new LinearPool!(FdChannel*)(channelsPoolSize);

            channelsMap[serverSocket.fd] = ServerChannelData(serverSocket, pool, serverChannel.port);
        }
    }

    ChannelContext delegate(FdChannel*) onAccept;
    ChannelContext delegate(FdChannel*) onRead;
    ChannelContext delegate(FdChannel*) onReadEnd;
    ChannelContext delegate(FdChannel*) onWrite;
    void delegate(FdChannel*) onClose;

    struct ServerChannelData
    {
        FdChannel* chan;
        LinearPool!(FdChannel*) pool;
        ushort port;
        sockaddr_in client_addr;
        socklen_t client_len = (client_addr).sizeof;
    }

    override void create()
    {
        super.create;

        logger.infof("Liburing version: %d.%d", io_uring_major_version, io_uring_minor_version);

        io_uring_params params;

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

        foreach (int fd, ServerChannelData serverData; channelsMap)
        {
            assert(serverData.chan);
            assert(fd == serverData.chan.fd);
            auto pool = serverData.pool;
            pool.create;
            foreach (i; 0 .. pool.count)
            {
                pool.set(i, newChannel);
            }

            auto socket = serverData.chan;
            assert(socket);

            logger.infof("Listen: 127.0.0.1:%d fd: %d", serverData.port, fd);
            addSocketAccept(&ring, socket, cast(sockaddr*)&(serverData.client_addr), &(
                    serverData.client_len));
        }

    }

    override void run()
    {
        super.run;

        assert(onAccept);
        assert(onRead);
        assert(onReadEnd);
        assert(onClose);

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
                auto errorConn = cast(FdChannel*) io_uring_cqe_get_data(cqe);
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

                auto connection = cast(FdChannel*) io_uring_cqe_get_data(cqe);

                unsigned type = connection.state;
                final switch (type) with (SocketConnectState)
                {
                    case accept:
                        int acceptSocketFd = cqe.res;

                        auto channelsPool = channelsMap[connection.fd].pool;

                        while (!channelsPool.hasIndex(acceptSocketFd))
                        {
                            if (!channelsPool.increase)
                            {
                                logger.error("Error change buffer size");
                                exit(1);
                            }
                        }

                        auto conn = channelsPool.get(acceptSocketFd);
                        if (!conn)
                        {
                            auto newConnect = newChannel(acceptSocketFd);
                            channelsPool.set(acceptSocketFd, newConnect);
                            conn = newConnect;
                        }
                        else
                        {
                            conn.fd = acceptSocketFd;
                            conn.state = SocketConnectState.none;
                            conn.availableBytes = 0;
                        }

                        assert(conn);

                        auto ctx = onAccept(conn);
                        runContext(ctx);

                        auto chanData = channelsMap[connection.fd];
                        addSocketAccept(&ring, chanData.chan, cast(sockaddr*)&(chanData.client_addr), &(
                                chanData.client_len));
                        break;
                    case read:
                        int bytes_read = cqe.res;

                        if (bytes_read <= 0)
                        {
                            if (isTraceEvents)
                            {
                                logger.trace("End read, close connection");
                            }

                            auto ctx = onReadEnd(connection);
                            runContext(ctx);
                        }
                        else
                        {
                            auto buffSize = bytes_read;
                            if (buffSize > connection.buffLength)
                            {
                                connection.availableBytes = connection.buffLength;
                            }
                            else
                            {
                                connection.availableBytes = buffSize;
                            }

                            auto ctx = onRead(connection);
                            runContext(ctx);
                        }
                        break;
                    case write:
                        if (isTraceEvents)
                        {
                            logger.trace("End write, close connection");
                        }

                        auto ctx = onWrite(connection);
                        runContext(ctx);
                        break;
                    case close:
                        onClose(connection);
                        break;
                }
            }

            io_uring_cq_advance(&ring, cqe_count);
        }

        logger.info("Exit");
    }

    FdChannel* newChannel(int fd = -1, SocketConnectState state = SocketConnectState
            .none)
    {

        auto mustBeChanPtr = malloc(FdChannel.sizeof);
        if (!mustBeChanPtr)
        {
            logger.error("Allocate channel error");
            exit(1);
        }

        auto newChan = cast(FdChannel*) mustBeChanPtr;
        newChan.type = FdChannelType.socket;
        newChan.fd = fd;
        newChan.state = state;
        newChan.buffLength = maxMessageLen;
        newChan.availableBytes = 0;

        if (newChan.buffLength > 0)
        {
            auto mustBeBuffPtr = malloc(newChan.buffLength);
            if (!mustBeBuffPtr)
            {
                logger.error("Allocate channel buffer error");
                exit(1);
            }

            newChan.buff = cast(ubyte*) mustBeBuffPtr;
        }
        else
        {
            newChan.buff = null;
        }

        return newChan;
    }

    void runContext(ref ChannelContext ctx)
    {
        final switch (ctx.type) with (ChannelContextType)
        {
            case read:
                addSocketReadv(&ring, ctx.channel);
                break;
            case write:
                addSocketWrite(&ring, ctx.channel, ctx.buff, ctx.buffLen);
                break;
            case close:
                addSocketClose(&ring, ctx.channel);
                break;
            case none:
                break;
        }
    }

    void addSocketClose(io_uring* ring, FdChannel* conn)
    {
        conn.state = SocketConnectState.close;
        io_uring_sqe* sqe = io_uring_get_sqe(ring);
        io_uring_prep_close(sqe, conn.fd);
        io_uring_sqe_set_data(sqe, conn);
    }

    void addSocketAccept(io_uring* ring, FdChannel* conn, sockaddr* client_addr, socklen_t* client_len)
    {
        conn.state = SocketConnectState.accept;
        io_uring_sqe* sqe = io_uring_get_sqe(ring);
        io_uring_prep_accept(sqe, conn.fd, client_addr, client_len, 0);
        io_uring_sqe_set_data(sqe, conn);
    }

    void addSocketReadv(io_uring* ring, FdChannel* conn)
    {
        io_uring_sqe* sqe = io_uring_get_sqe(ring);
        io_uring_prep_recv(sqe, conn.fd, conn.buff, conn.buffLength, 0);
        conn.state = SocketConnectState.read;
        io_uring_sqe_set_data(sqe, conn);
    }

    void addSocketWrite(io_uring* ring, FdChannel* conn, const(void*) buff, size_t len)
    {
        assert(buff);
        assert(len >= 0);
        conn.state = SocketConnectState.write;
        io_uring_sqe* sqe = io_uring_get_sqe(ring);
        io_uring_prep_send(sqe, conn.fd, buff, len, 0);
        io_uring_sqe_set_data(sqe, conn);
    }

    override void stop()
    {
        super.stop;

        io_uring_queue_exit(&ring);
        io_uring_close_ring_fd(&ring);
    }

}
