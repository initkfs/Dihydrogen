module api.dn.io.loops.event_loop;

import std.stdio : writeln, writefln;
import std.string : toStringz, fromStringz;

import socket_libs;

import core.stdc.stdlib : malloc, exit;
import core.stdc.string : memset, strerror;

import io_uring_libs;
import api.dn.io.natives.iouring.io_uring;
import api.dn.io.natives.iouring.io_uring_types;

import std.conv : to;
import std.string : toStringz, fromStringz;
import api.core.loggers.logging;

import api.core.components.units.services.loggable_unit : LoggableUnit;
import api.dn.pools.linear_pool : LinearPool;
import api.dn.channels.fd_channel : FdChannel, FdChannelType;
import api.dn.net.sockets.socket_connect : SocketConnectState;

import api.dn.channels.server_channel : ServerChannel;

import core.stdc.errno;

/**
 * Authors: initkfs
 */
class EventLoop : LoggableUnit
{
    uint ringEntries = 4096;
    size_t maxMessageLen = 2048;

    enum backlog = 512;
    enum ringFeatFastPollFlag = (1U << 5);

    bool isTraceEvents;

    int channelsPoolSize = 100;

    io_uring ring;

    this(Logging logging)
    {
        super(logging);
    }

    void delegate(FdChannel*) onAcceptEnd;
    void delegate(FdChannel*) onReadStart;
    void delegate(FdChannel*) onReadEnd;
    void delegate(FdChannel*) onWriteEnd;
    void delegate(FdChannel*) onCloseEnd;

    void delegate() onBatchQueueEnd;
    bool delegate(io_uring_cqe*[]) onBatchIsContinue;

    void addServerAccept(int fd)
    {
        throw new Exception("Not supported");
    }

    override void create()
    {
        super.create;

        assert(onAcceptEnd, "On accept end listener must not be null");
        assert(onReadStart, "On read start listener must not be null");
        assert(onReadEnd, "On read end listener must not be null");
        assert(onWriteEnd, "On write end listener must not be null");
        assert(onCloseEnd, "On close end listener must not be null");

        logger.infof("Liburing version: %d.%d", io_uring_major_version, io_uring_minor_version);

        io_uring_params params;
        //memset(&params, 0, params.sizeof);

        assert(ringEntries > 0);
        auto initRet = io_uring_queue_init_params(ringEntries, &ring, &params);
        if (initRet < 0)
        {
            logger.errorf("Init uring queue error: %s", strerror(-initRet).fromStringz);
            exit(1);
        }

        if (!(params.features & ringFeatFastPollFlag))
        {
            logger.error("io_urint fast poll not available in the kernel, quiting...\n");
            return;
        }
    }

    int getEventsWait(io_uring* ring, io_uring_cqe** cqes, out bool isError)
    {
        auto ret = io_uring_wait_cqe(ring, cqes);
        if (ret != 0 && (ret != (-EAGAIN)))
        {
            isError = true;
        }
        return ret;
    }

    int getEventsPeek(io_uring* ring, io_uring_cqe** cqes, out bool isError)
    {
        auto ret = io_uring_peek_cqe(ring, cqes);
        if (ret != 0 && (ret != (-EAGAIN)))
        {
            isError = true;
        }
        return ret;
    }

    int getEvents(io_uring* ring, io_uring_cqe** cqes, out bool isError)
    {
        return getEventsWait(ring, cqes, isError);
    }

    FdChannel* channelFromCQE(io_uring_cqe* cqe)
    {
        auto connection = cast(FdChannel*) io_uring_cqe_get_data(cqe);
        assert(connection);
        return connection;
    }

    bool runStepIsContinue()
    {
        io_uring_cqe* cqe;
        int ret;

        io_uring_submit(&ring);

        bool isErrorEvents;
        ret = getEvents(&ring, &cqe, isErrorEvents);
        if (isErrorEvents)
        {
            logger.error("Events receiver error: %d", ret);
            io_uring_cqe_seen(&ring, cqe);
            return true;
        }

        if (ret == -EAGAIN)
        {
            io_uring_cqe_seen(&ring, cqe);
            return true;
        }

        if (cqe.res < 0)
        {
            auto errorConn = channelFromCQE(cqe);
            logger.errorf("Async request failed with fd %s, state '%s': %s", errorConn.fd, errorConn.state, strerror(
                    -cqe.res).fromStringz.idup);
            io_uring_cqe_seen(&ring, cqe);
            return true;
        }

        io_uring_cqe*[backlog] cqes;

        int cqe_count = io_uring_peek_batch_cqe(&ring, cqes.ptr, cqes.length);

        if (onBatchIsContinue && !onBatchIsContinue(cqes[0 .. cqe_count]))
        {
            auto connection = cast(FdChannel*) io_uring_cqe_get_data(cqe);

            if (connection.state == SocketConnectState.accept)
            {
                addServerAccept(connection.fd);
            }

            io_uring_cq_advance(&ring, cqe_count);
            return true;
        }

        for (int i = 0; i < cqe_count; ++i)
        {
            cqe = cqes[i];

            auto connection = cast(FdChannel*) io_uring_cqe_get_data(cqe);
            
            int type = connection.state;
            final switch (type) with (SocketConnectState)
            {
                case accept:
                    int acceptSocketFd = cqe.res;
                    assert(acceptSocketFd >= 0);

                    auto newConnect = getChannel(connection.fd, acceptSocketFd);

                    //TODO or onClose?
                    newConnect.resetBufferIndices;

                    assert(newConnect);

                    onAcceptEnd(newConnect);

                    addServerAccept(connection.fd);
                    break;
                case read:
                    int bytesRead = cqe.res;

                    //TODO onErrorRead, < 0
                    if (bytesRead <= 0)
                    {
                        onReadEnd(connection);
                    }
                    else
                    {
                        auto buffSize = bytesRead;
                        if (!connection.incRead(buffSize))
                        {
                            connection.incMaxRead;
                        }

                        if (!connection.incWrite(buffSize))
                        {
                            connection.incMaxWrite;
                        }

                        onReadStart(connection);
                    }
                    break;
                case write:
                    onWriteEnd(connection);
                    break;
                case close:
                    // auto res = cqe.res;
                    // if(res < 0){
                    //     //TODO onError?
                    // }
                    onCloseEnd(connection);
                    break;
            }
        }

        io_uring_cq_advance(&ring, cqe_count);

        return true;
    }

    override void run()
    {
        super.run;

        while (true)
        {
            if (!runStepIsContinue)
            {
                break;
            }
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
        newChan.readIndex = 0;
        newChan.writeIndex = 0;

        if (maxMessageLen > 0)
        {
            auto mustBeBuffPtr = malloc(maxMessageLen);
            if (!mustBeBuffPtr)
            {
                logger.error("Allocate channel buffer error");
                exit(1);
            }

            newChan.buff = cast(ubyte[]) mustBeBuffPtr[0 .. maxMessageLen];
        }
        else
        {
            newChan.buff = null;
        }

        return newChan;
    }

    FdChannel* getChannel(int serverFd, int activeChannelFd)
    {
        throw new Exception("Not supported pool");
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
        if (conn.writableBytes.length == 0)
        {
            return;
        }
        io_uring_sqe* sqe = io_uring_get_sqe(ring);
        io_uring_prep_recv(sqe, conn.fd, conn.writableBytes.ptr, conn.writableBytes.length, 0);
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
