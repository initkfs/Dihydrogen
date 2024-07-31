module app.dn.io.loops.event_loop;

import std.stdio : writeln, writefln;
import std.string : toStringz, fromStringz;

import socket_libs;

import core.stdc.stdlib : malloc, exit;
import core.stdc.string : memset, strerror;

import io_uring_libs;
import app.dn.io.natives.iouring.io_uring;
import app.dn.io.natives.iouring.io_uring_types;

import std.conv : to;
import std.string : toStringz, fromStringz;
import std.logger;

import app.core.components.units.services.loggable_unit : LoggableUnit;
import app.dn.pools.linear_pool : LinearPool;
import app.dn.channels.fd_channel : FdChannel, FdChannelType;
import app.dn.net.sockets.socket_connect : SocketConnectState;
import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

import app.dn.channels.server_channel : ServerChannel;

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

    io_uring ring;

    this(Logger logger)
    {
        super(logger);
    }

    void delegate(ChanInEvent) onInEvent;

    void delegate() onBatchQueueEnd;
    bool delegate(io_uring_cqe*[]) onBatchIsContinue;

    void addServerAccept(int fd)
    {
        throw new Exception("Not supported");
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
    }

    int getEventsWait(io_uring* ring, io_uring_cqe** cqes, out bool isError)
    {
        auto ret = io_uring_wait_cqe(ring, cqes);
        if (ret != 0)
        {
            isError = true;
        }
        return ret;
    }

    int getEventsPeek(io_uring* ring, io_uring_cqe** cqes, out bool isError)
    {
        import core.stdc.errno;

        auto ret = io_uring_peek_cqe(ring, cqes);
        if (ret != 0)
        {
            if (ret == -EAGAIN)
            {
                return ret;
            }
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
        assert(onInEvent);

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

        import core.stdc.errno : EAGAIN;

        if (ret == -EAGAIN)
        {
            return true;
        }

        if (cqe.res < 0)
        {
            auto errorConn = cast(FdChannel*) io_uring_cqe_get_data(cqe);
            assert(errorConn);
            logger.errorf("Async request failed with fd %s, state '%s': %s", errorConn.fd, errorConn.state, strerror(
                    -cqe.res).fromStringz);
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

            unsigned type = connection.state;
            final switch (type) with (SocketConnectState)
            {
                case accept:
                    int acceptSocketFd = cqe.res;
                    assert(acceptSocketFd >= 0);

                    auto conn = getChannel(connection.fd, acceptSocketFd);

                    assert(conn);

                    onInEvent(ChanInEvent(conn, ChanInEvent.ChanInEventType.accepted));

                    addServerAccept(connection.fd);
                    break;
                case read:
                    int bytes_read = cqe.res;

                    if (bytes_read <= 0)
                    {
                        if (isTraceEvents)
                        {
                            logger.trace("End read, close connection");
                        }

                        onInEvent(ChanInEvent(connection, ChanInEvent.ChanInEventType.readedAll));
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

                        onInEvent(ChanInEvent(connection, ChanInEvent.ChanInEventType.readed));
                    }
                    break;
                case write:
                    if (isTraceEvents)
                    {
                        logger.trace("End write, close connection");
                    }

                    onInEvent(ChanInEvent(connection, ChanInEvent.ChanInEventType.writed));
                    break;
                case close:
                    onInEvent(ChanInEvent(connection, ChanInEvent.ChanInEventType.closed));
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

    FdChannel* getChannel(int serverFd, int activeChannelFd)
    {
        throw new Exception("Not supported pool");
    }

    void sendEvent(ChanOutEvent event)
    {
        if (event.isConsumed)
        {
            return;
        }

        switch (event.type) with (ChanOutEvent.ChanOutEventType)
        {
            case read:
                addSocketReadv(&ring, event.chan);
                break;
            case write:
                addSocketWrite(&ring, event.chan, event.buff, event.buffLen);
                break;
            case close:
                addSocketClose(&ring, event.chan);
                break;
            default:
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
