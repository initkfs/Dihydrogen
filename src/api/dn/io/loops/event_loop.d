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
import api.dn.utils.pools.linear_pool : LinearPool;
import api.dn.channels.fd_channel : FdChannel, FdChannelType;
import api.dn.sockets.socket_connect : SocketConnectState;

import api.dn.channels.server_channel : ServerChannel;

import core.stdc.errno;

/**
 * Authors: initkfs
 */
class EventLoop : LoggableUnit
{
    uint ringEntries = 4096;
    size_t maxMessageLen = 2048;

    bool isClient;

    enum backlog = 512;
    enum ringFeatFastPollFlag = (1U << 5);

    bool isTraceEvents;

    int channelsPoolSize = 100;

    io_uring ring;

    this(Logging logging)
    {
        super(logging);
    }

    void delegate() onStartLoop;
    void delegate() onEndLoop;

    void delegate(FdChannel*) onAcceptEnd;
    void delegate(FdChannel*) onReadStart;
    void delegate(FdChannel*) onReadEnd;
    void delegate(FdChannel*) onReadError;
    void delegate(FdChannel*) onWriteEnd;
    void delegate(FdChannel*) onSpliceEnd;
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
        assert(onReadError, "On read error listener must not be null");
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

        //addTimer(&ring, 5);
    }

    int getEventsWait(io_uring* ring, io_uring_cqe** cqes)
    {
        return io_uring_wait_cqe(ring, cqes);
    }

    int getEventsPeek(io_uring* ring, io_uring_cqe** cqes)
    {
        //EAGAIN
        return io_uring_peek_cqe(ring, cqes);
    }

    int getEvents(io_uring* ring, io_uring_cqe** cqes)
    {
        return getEventsWait(ring, cqes);
    }

    FdChannel* hasChannelFromCQE(io_uring_cqe* cqe)
    {
        auto connection = cast(FdChannel*) io_uring_cqe_get_data(cqe);
        return connection;
    }

    FdChannel* channelFromCQE(io_uring_cqe* cqe)
    {
        auto connection = hasChannelFromCQE(cqe);
        assert(connection);
        return connection;
    }

    bool runStepIsContinue()
    {
        io_uring_cqe* cqe;

        const submitRet = io_uring_submit(&ring);
        if (submitRet < 0)
        {
            logger.error("Error events submitting: ", submitRet);
            return true;
        }

        io_uring_cqe*[backlog] cqes;

        int cqeСount = io_uring_peek_batch_cqe(&ring, cqes.ptr, cqes.length);
        if (cqeСount < 0)
        {
            //EAGAIN
            logger.error("Batching error code: ", cqeСount);
            return true;
        }

        if (onBatchIsContinue && !onBatchIsContinue(cqes[0 .. cqeСount]))
        {
            auto connection = cast(FdChannel*) io_uring_cqe_get_data(cqe);

            if (connection.type == FdChannelType.socket && connection.state == SocketConnectState
                .accept)
            {
                addServerAccept(connection.fd);
            }

            io_uring_cq_advance(&ring, cqeСount);
            return true;
        }

        for (int i = 0; i < cqeСount; ++i)
        {
            cqe = cqes[i];

            auto connectionPtr = io_uring_cqe_get_data(cqe);
            if (!connectionPtr)
            {
                logger.error("Connection not found: ", cqe.res);
                continue;
            }

            auto connection = cast(FdChannel*) connectionPtr;

            final switch (connection.type) with (FdChannelType)
            {
                case socket:
                    applySocketChannel(connection, cqe);
                    break;
                case timer:
                    applyTimerChannel(connection, cqe);
                    break;
                case file:
                    applyFileChannel(connection, cqe);
                    break;
                case none:
                    logger.error("Non initialized channel: ", connection);
                    break;
            }
        }

        if (cqeСount > 0)
        {
            io_uring_cq_advance(&ring, cqeСount);
        }

        return true;
    }

    void applySocketChannel(FdChannel* connection, io_uring_cqe* cqe)
    {
        assert(connection.type == FdChannelType.socket);

        int ret = cqe.res;

        if (ret < 0)
        {
            switch (ret)
            {
                case -EAGAIN:
                    logger.trace("Connection reagain fd %s, state '%s'", connection.fd, connection
                            .state);
                    return;
                    break;
                case -ECONNRESET:
                    logger.errorf("Connection reset fd %s, state '%s'", connection.fd, connection
                            .state);
                    onCloseEnd(connection);
                    return;
                    break;
                case -EPIPE:
                    logger.errorf("Connection broken pipe fd %s, state '%s'", connection.fd, connection
                            .state);
                    onCloseEnd(connection);
                    return;
                    break;
                case -ENOTCONN:
                    logger.errorf("Transport endpoint is not connected fd %s, state '%s'", connection.fd, connection
                            .state);
                    onCloseEnd(connection);
                    return;
                    break;
                case -ENOBUFS:
                    logger.errorf("No buffer space available fd %s, state '%s'", connection.fd, connection
                            .state);
                    return;
                    break;
                case -ETIMEDOUT, -ETIME:
                    logger.tracef("Connection timeout fd %s, state '%s'", connection.fd, connection
                            .state);
                    addSocketClose(&ring, connection);
                    return;
                    break;
                case -ECANCELED:
                    logger.tracef("Operation canceled, fd %s, state '%s'", connection.fd, connection
                            .state);
                    break;
                default:
                    logger.errorf("Connection error fd %s, state '%s': %s", connection.fd, connection.state, strerror(

                            -ret).fromStringz.idup);
                    //onCloseEnd(connection);
            }

            return;
        }

        int type = connection.state;
        final switch (type) with (SocketConnectState)
        {
            case accept:
                int acceptSocketFd = cqe.res;
                if (acceptSocketFd < 0)
                {
                    logger.errorf("Error accepting, descriptor not positive: %s, %s", acceptSocketFd, connection
                            .toSimpleString);
                }
                else
                {
                    auto newConnect = getChannel(connection.fd, acceptSocketFd);
                    assert(newConnect);

                    //TODO or onClose?
                    newConnect.resetPart;
                    newConnect.start;

                    if (newConnect.outb.isMustClose)
                    {
                        newConnect.outb.dispose;
                    }

                    //addTimer(&ring, newConnect, 10, 1);

                    onAcceptEnd(newConnect);
                }

                addServerAccept(connection.fd);
                break;
            case read:
                int bytesRead = cqe.res;

                if (bytesRead < 0)
                {
                    onReadError(connection);
                }
                else if (bytesRead == 0)
                {
                    onReadEnd(connection);
                }
                else
                {
                    auto buffSize = bytesRead;
                    if (!connection.inb.incRead(buffSize))
                    {
                        connection.inb.incMaxRead;
                    }

                    if (!connection.inb.incWrite(buffSize))
                    {
                        connection.inb.incMaxWrite;
                    }

                    onReadStart(connection);
                }
                break;
            case write:
                onWriteEnd(connection);
                break;
            case splice:
                onSpliceEnd(connection);
                break;
            case close: // auto res = cqe.res;
                // if(res < 0){
                //     //TODO onError?
                // }
                onCloseEnd(connection);
                break;
            case timeout:
                import std;

                writeln("TIMEOUT");
                //addSocketClose(&ring, connection);
                break;
        }
    }

    void applyTimerChannel(FdChannel* chan, io_uring_cqe* cqe)
    {
        int ret = cqe.res;

        if (ret < 0)
        {
            switch (ret)
            {
                case -ETIME:
                    logger.trace("Timer end");
                    import core.stdc.stdlib : free;

                    free(chan);
                    break;
                case -ECANCELED:
                    logger.trace("Timer canceled");
                    break;
                default:
                    logger.error("Unknown error without connection: ", ret);
                    break;
            }
        }
    }

    void applyFileChannel(FdChannel* chan, io_uring_cqe* cqe)
    {

    }

    override void run()
    {
        super.run;

        if (onStartLoop)
        {
            onStartLoop();
        }

        while (true)
        {
            if (!runStepIsContinue)
            {
                break;
            }
        }

        if (onEndLoop)
        {
            onEndLoop();
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

        newChan.clear;

        newChan.type = FdChannelType.socket;
        newChan.fd = fd;
        newChan.state = state;
        newChan.isChain = false;

        newChan.inb.reset;

        newChan.outb.resetUnsafe;

        if (maxMessageLen > 0)
        {
            auto mustBeBuffPtr = malloc(maxMessageLen);
            if (!mustBeBuffPtr)
            {
                logger.error("Allocate channel buffer error");
                exit(1);
            }

            newChan.inb.buff = cast(ubyte[]) mustBeBuffPtr[0 .. maxMessageLen];
        }
        else
        {
            newChan.inb.buff = null;
        }

        return newChan;
    }

    FdChannel* getChannel(int serverFd, int activeChannelFd)
    {
        throw new Exception("Not supported pool");
    }

    bool getSqe(io_uring* ring, out io_uring_sqe* sqe)
    {
        io_uring_sqe* sqePtr = io_uring_get_sqe(ring);
        if (!sqePtr)
        {
            logger.error("Error. SQE is null");
            return false;
        }

        sqe = sqePtr;
        return true;
    }

    bool getSqe(io_uring* ring, FdChannel* conn, out io_uring_sqe* sqe)
    {
        io_uring_sqe* sqePtr = io_uring_get_sqe(ring);
        if (!sqePtr)
        {
            logger.error("Error. SQE is null on connection: %s", conn ? (*conn)
                    .toSimpleString : "null");
            return false;
        }

        sqe = sqePtr;
        return true;
    }

    void applySQE(io_uring_sqe* sqe, FdChannel* conn)
    {
        if (conn.isChain)
        {
            sqe.flags |= IOSQE_IO_LINK;
        }
    }

    void addSocketClose(io_uring* ring, FdChannel* conn)
    {
        conn.state = SocketConnectState.close;
        io_uring_sqe* sqe;
        if (!getSqe(ring, conn, sqe))
        {
            return;
        }

        applySQE(sqe, conn);

        io_uring_prep_close(sqe, conn.fd);
        io_uring_sqe_set_data(sqe, conn);
    }

    void addSocketShutdown(io_uring* ring, FdChannel* conn, int how)
    {
        conn.state = SocketConnectState.close;
        io_uring_sqe* sqe;
        if (!getSqe(ring, conn, sqe))
        {
            return;
        }

        applySQE(sqe, conn);

        io_uring_prep_shutdown(sqe, conn.fd, how);
        io_uring_sqe_set_data(sqe, conn);
    }

    void addSocketAccept(io_uring* ring, FdChannel* conn, sockaddr* client_addr, socklen_t* client_len)
    {
        conn.state = SocketConnectState.accept;
        io_uring_sqe* sqe;
        if (!getSqe(ring, conn, sqe))
        {
            return;
        }

        applySQE(sqe, conn);

        io_uring_prep_accept(sqe, conn.fd, client_addr, client_len, 0);
        io_uring_sqe_set_data(sqe, conn);
    }

    void addSocketReadv(io_uring* ring, FdChannel* conn)
    {
        io_uring_sqe* sqe;
        if (!getSqe(ring, conn, sqe))
        {
            return;
        }

        applySQE(sqe, conn);

        io_uring_prep_recv(sqe, conn.fd, conn.writableBytes.ptr, conn.writableBytes.length, 0);
        conn.state = SocketConnectState.read;
        io_uring_sqe_set_data(sqe, conn);
    }

    void addSocketWrite(io_uring* ring, FdChannel* conn, const(void*) buff, size_t len)
    {
        assert(buff);
        assert(len >= 0);
        conn.state = SocketConnectState.write;
        io_uring_sqe* sqe;
        if (!getSqe(ring, conn, sqe))
        {
            return;
        }

        applySQE(sqe, conn);

        io_uring_prep_send(sqe, conn.fd, buff, len, 0);
        io_uring_sqe_set_data(sqe, conn);
    }

    void addSocketWriteZC(io_uring* ring, FdChannel* conn, const(void*) buff, size_t len)
    {
        assert(buff);
        assert(len >= 0);

        conn.state = SocketConnectState.write;
        io_uring_sqe* sqe;
        if (!getSqe(ring, conn, sqe))
        {
            return;
        }

        applySQE(sqe, conn);

        enum IORING_SEND_ZC_REPORT_USAGE = 1U << 0;

        io_uring_prep_send_zc(sqe, conn.fd, buff, len, 0, IORING_SEND_ZC_REPORT_USAGE);
        io_uring_sqe_set_data(sqe, conn);
    }

    void addSocketSplice(io_uring* ring, FdChannel* conn)
    {
        io_uring_sqe* sqe;
        if (!getSqe(ring, conn, sqe))
        {
            return;
        }

        //io_uring_sqe_set_data(sqe, conn);

        import api.dn.channels.fd_file;

        auto file = cast(FdFile*) conn.data;
        assert(file, "File data must not be null");

        uint fileSize = cast(uint) file.size;

        int pipeIn = file.pipes[0];
        int pipeOut = file.pipes[1];

        applySQE(sqe, conn);

        //import core.sys.posix.sys.ioctl;
        //ioctl(pipeOut, FIONREAD, &bytesAvailable);

        sqe.flags |= IOSQE_IO_LINK;
        io_uring_prep_splice(sqe, file.fd, 0, pipeOut, -1, fileSize, 0);

        sqe = null;

        if (!getSqe(ring, conn, sqe))
        {
            return;
        }

        assert(sqe);

        io_uring_prep_splice(sqe, pipeIn, -1, conn.fd, -1, fileSize, 0);
        io_uring_sqe_set_data(sqe, conn);
        conn.state = SocketConnectState.splice;
    }

    void addSocketCancel(io_uring* ring, FdChannel* conn)
    {
        io_uring_sqe* sqe;
        if (!getSqe(ring, conn, sqe))
        {
            return;
        }
        io_uring_prep_cancel(sqe, conn, 0);
        conn.state = SocketConnectState.cancel;
        //io_uring_sqe_set_data(sqe, conn);
    }

    void addTimer(io_uring* ring, ulong sec, uint count = 0, uint flags = 0)
    {
        io_uring_sqe* sqe;
        if (!getSqe(ring, sqe))
        {
            return;
        }

        //TODO allocator
        import core.stdc.stdlib : malloc;

        FdChannel* chan = cast(FdChannel*) malloc(FdChannel.sizeof);
        assert(chan);

        chan.clear;

        chan.type = FdChannelType.timer;

        import time_libs;

        __kernel_timespec timeout;
        timeout.tv_sec = sec;
        timeout.tv_nsec = 0;

        io_uring_prep_timeout(sqe, &timeout, count, flags);
        io_uring_sqe_set_data(sqe, chan);
    }

    void removeTimer(io_uring* ring, ulong userData, uint flags = 0)
    {
        io_uring_sqe* sqe;
        if (!getSqe(ring, sqe))
        {
            return;
        }

        io_uring_prep_timeout_remove(sqe, userData, flags);
    }

    override void stop()
    {
        super.stop;

        io_uring_queue_exit(&ring);
        io_uring_close_ring_fd(&ring);
    }

}
