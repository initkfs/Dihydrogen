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
import api.dn.chans.fd_chan : FdChan, FdChanType;
import api.dn.sockets.socket_connect : SocketConnectState;

import api.dn.chans.server_chan : ServerChan;

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

    size_t watchdogTimerSec = 0;
    FdChan* watchDogTimer;

    int controlFd;
    FdChan controlChan;
    private ubyte[8] controlBuffer;

    protected
    {
        size_t _queueCount;
    }

    this(Logging logging, int controlFd)
    {
        super(logging);

        this.controlFd = controlFd;
    }

    void delegate() onStartLoop;
    void delegate() onEndLoop;

    void delegate(FdChan*) onAcceptEnd;
    void delegate(FdChan*) onReadStart;
    void delegate(FdChan*) onReadEnd;
    void delegate(FdChan*) onReadError;
    void delegate(FdChan*) onWriteEnd;
    void delegate(FdChan*) onSpliceEnd;
    void delegate(FdChan*) onCloseEnd;

    void delegate() onBatchQueueEnd;
    bool delegate(io_uring_cqe*[]) onBatchIsContinue;

    bool isStop;

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
        params.flags |= IORING_SETUP_R_DISABLED;

        assert(ringEntries > 0);
        auto initRet = io_uring_queue_init_params(ringEntries, &ring, &params);
        if (initRet < 0)
        {
            logger.errorf("Init uring queue error: %s", strerror(-initRet).fromStringz);
            exit(1);
        }

        if (!(params.features & ringFeatFastPollFlag))
        {
            logger.error("io_uring fast poll not available in the kernel, quiting...\n");
            return;
        }

        io_uring_restriction[$] restr = [
            io_uring_restriction(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_ACCEPT),
            io_uring_restriction(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_READ),
            io_uring_restriction(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_READV),
            io_uring_restriction(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_RECV),
            io_uring_restriction(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_WRITE),
            io_uring_restriction(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_SEND),
            //io_uring_restriction(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_SEND_ZC),
            io_uring_restriction(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_SPLICE),
            io_uring_restriction(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_CLOSE),
            io_uring_restriction(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_SHUTDOWN),

            io_uring_restriction(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_TIMEOUT),
            io_uring_restriction(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_TIMEOUT_REMOVE),

            io_uring_restriction(IORING_RESTRICTION_REGISTER_OP, IORING_REGISTER_FILES),
            io_uring_restriction(IORING_RESTRICTION_REGISTER_OP, IORING_REGISTER_BUFFERS),
        ];

        const regRet = io_uring_register_restrictions(&ring, restr.ptr, restr.length);
        if (regRet != 0)
        {
            import std.format : format;

            throw new Exception(format("Error register restrictions: %s", strerror(-regRet)
                    .fromStringz.idup));
        }

        const enret = io_uring_enable_rings(&ring);
        if (enret < 0)
            throw new Exception("Error io_uring enable");

        //addTimer(&ring, 5);
        if (watchdogTimerSec != 0)
        {
            watchDogTimer = FdChan.newChan;
            addWatchdogTimer;
            logger.tracef("Add watchdog timer, sec: %d", watchdogTimerSec);
        }

        controlChan = FdChan(controlFd, FdChanType.control);
        controlChan.inb.buff = controlBuffer[0 .. controlBuffer.length];

        io_uring_sqe* controlSqe;
        if (!getSqe(&ring, controlSqe))
        {
            throw new Exception("Control sqe error");
        }

        io_uring_sqe_set_data(controlSqe, &controlChan);
        io_uring_prep_read(controlSqe, controlChan.fd, controlChan.inb.buff.ptr, cast(uint) controlChan
                .inb.buff.length, 0);
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

    FdChan* hasChannelFromCQE(io_uring_cqe* cqe)
    {
        auto connection = cast(FdChan*) io_uring_cqe_get_data(cqe);
        return connection;
    }

    FdChan* channelFromCQE(io_uring_cqe* cqe)
    {
        auto connection = hasChannelFromCQE(cqe);
        assert(connection);
        return connection;
    }

    bool runStepIsContinue(bool isWait = true, bool isLoopOnEmpty = true)
    {
        //TODO io_uring_cq_has_overflow
        io_uring_cqe* cqe;

        //const submitRet = io_uring_submit(&ring);
        const submitRet = isWait ? io_uring_submit_and_wait(&ring, 1) : io_uring_submit(&ring);
        if (submitRet < 0)
        {
            logger.errorf("Error events submitting: %d", submitRet);
            return true;
        }

        io_uring_cqe*[backlog] cqes;

        int cqeСount = io_uring_peek_batch_cqe(&ring, cqes.ptr, cqes.length);
        if (cqeСount < 0)
        {
            //EAGAIN
            logger.errorf("Batching error code: %d", cqeСount);
            return true;
        }

        if (cqeСount == 0)
        {
            return isLoopOnEmpty;
        }

        bool isRequestStop;

        for (int i = 0; i < cqeСount; ++i)
        {
            cqe = cqes[i];

            auto connectionPtr = io_uring_cqe_get_data(cqe);
            if (!connectionPtr)
            {
                logger.errorf("Connection not found: %d", cqe.res);
                continue;
            }

            auto connection = cast(FdChan*) connectionPtr;

            final switch (connection.type) with (FdChanType)
            {
                case control:
                    if (isStop)
                    {
                        continue;
                    }

                    isStop = applyControlStop(connection, cqe);
                    if (isStop)
                    {
                        isRequestStop = true;
                    }
                    break;
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
                    logger.error("Non initialized channel: " ~ connection.toSimpleString);
                    break;
            }
        }

        if (cqeСount > 0)
        {
            io_uring_cq_advance(&ring, cqeСount);

            if (cqeСount >= _queueCount)
            {
                _queueCount -= cqeСount;
            }
        }

        if (isRequestStop)
        {
            logger.trace("Request stop received for loop");
            return false;
        }

        return true;
    }

    bool applyControlStop(FdChan* connection, io_uring_cqe* cqe)
    {
        int ret = cqe.res;

        enum stopRet = true;

        if (ret < 0)
        {
            logger.tracef("Connection error fd %s, state '%s': %s", connection.fd, connection.state, strerror(
                    -ret).fromStringz.idup);
            return stopRet;
        }

        int readBytes = cqe.res;
        if (readBytes > connection.inb.buff.length)
        {
            logger.tracef("Control buffer overflow, buff size %d, received %d", connection.inb.buff, readBytes);
            return stopRet;
        }

        //TODO unsafe cast
        long controlCode = *(connection.inb.buff[0 .. readBytes].ptr);
        logger.tracef("Received chan control code: %d", controlCode);

        import api.dn.chans.chan_controls : ChanControlCode;

        if (controlCode == ChanControlCode.exit)
        {
            return stopRet;
        }

        return !stopRet;
    }

    void applySocketChannel(FdChan* connection, io_uring_cqe* cqe)
    {
        assert(connection.type == FdChanType.socket);

        int ret = cqe.res;

        if (ret < 0)
        {
            switch (ret)
            {
                case -EAGAIN:
                    logger.tracef("Connection reagain fd %s, state '%s'", connection.fd, connection
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
                    newConnect.reset;
                    newConnect.start;

                    if (newConnect.outb.isMustFree)
                    {
                        newConnect.outb.dispose;
                    }

                    //addTimer(&ring, newConnect, 10, 1);

                    onAcceptEnd(newConnect);
                }

                if (!isStop)
                {
                    addServerAccept(connection.fd);
                }

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

                connection.state = SocketConnectState.wrote;

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

    void applyTimerChannel(FdChan* chan, io_uring_cqe* cqe)
    {
        int ret = cqe.res;

        if (ret < 0)
        {
            switch (ret)
            {
                case -ETIME:

                    if (chan == watchDogTimer)
                    {
                        logger.trace("Watchdog timer end");
                        if (watchDogTimer)
                        {
                            if (onWatchdogIsContinue)
                            {
                                addWatchdogTimer;
                            }

                        }
                        break;
                    }

                    logger.trace("Timer end");

                    import core.stdc.stdlib : free;

                    free(chan);
                    break;
                case -ECANCELED:
                    logger.trace("Timer canceled");
                    break;
                default:
                    logger.errorf("Unknown error without connection: %d", ret);
                    break;
            }
        }
    }

    void applyFileChannel(FdChan* chan, io_uring_cqe* cqe)
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

        logger.info("Break server loop");
    }

    FdChan* newChan(int fd = -1, SocketConnectState state = SocketConnectState
            .none)
    {

        auto chan = FdChan.newChan;

        chan.type = FdChanType.socket;
        chan.fd = fd;
        chan.state = state;
        chan.isChain = false;

        if (maxMessageLen > 0)
        {
            auto mustBeBuffPtr = malloc(maxMessageLen);
            if (!mustBeBuffPtr)
            {
                logger.error("Allocate channel buffer error");
                exit(1);
            }

            chan.inb.buff = cast(ubyte[]) mustBeBuffPtr[0 .. maxMessageLen];
            chan.inb.isMustFree = true;
        }
        else
        {
            chan.inb.buff = null;
        }

        return chan;
    }

    FdChan* getChannel(int serverFd, int activeChannelFd)
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
        queueInc;

        return true;
    }

    bool getSqe(io_uring* ring, FdChan* conn, out io_uring_sqe* sqe)
    {
        io_uring_sqe* sqePtr = io_uring_get_sqe(ring);
        if (!sqePtr)
        {
            logger.error("Error. SQE is null on connection: %s", conn ? (*conn)
                    .toSimpleString : "null");
            return false;
        }

        sqe = sqePtr;
        queueInc;
        return true;
    }

    void applySQE(io_uring_sqe* sqe, FdChan* conn)
    {
        if (conn.isChain)
        {
            sqe.flags |= IOSQE_IO_LINK;
        }
    }

    void addSocketClose(io_uring* ring, FdChan* conn)
    {
        conn.state = SocketConnectState.close;
        io_uring_sqe* sqe;
        if (!getSqe(ring, conn, sqe))
        {
            //TODO bool or throw
            return;
        }

        applySQE(sqe, conn);

        io_uring_prep_close(sqe, conn.fd);
        io_uring_sqe_set_data(sqe, conn);
    }

    void addSocketShutdown(io_uring* ring, FdChan* conn, int how)
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

    void addSocketAccept(io_uring* ring, FdChan* conn, sockaddr* client_addr, socklen_t* client_len)
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

    void addSocketReadv(io_uring* ring, FdChan* conn)
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

    void addSocketWrite(io_uring* ring, FdChan* conn, const(void*) buff, size_t len)
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

    void addSocketWriteZC(io_uring* ring, FdChan* conn, const(void*) buff, size_t len)
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

    void addSocketSplice(io_uring* ring, FdChan* conn)
    {
        io_uring_sqe* sqe;
        if (!getSqe(ring, conn, sqe))
        {
            return;
        }

        //io_uring_sqe_set_data(sqe, conn);

        import api.dn.utils.io.fd_file;

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

    void addSocketCancel(io_uring* ring, FdChan* conn)
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

    void addWatchdogTimer(uint count = 0, uint flags = 0, bool isSubmit = true)
    {
        assert(watchDogTimer);
        addTimer(watchDogTimer, &ring, watchdogTimerSec, count, flags, isSubmit);
    }

    void addTimer(io_uring* ring, ulong sec, uint count = 0, uint flags = 0, bool isSubmit = true)
    {
        io_uring_sqe* sqe;
        if (!getSqe(ring, sqe))
        {
            return;
        }

        FdChan* chan = FdChan.newChan;
        addTimer(chan, ring, sec, count, flags, isSubmit);
    }

    void addTimer(FdChan* chan, io_uring* ring, ulong sec, uint count = 0, uint flags = 0, bool isSubmit = true)
    {
        io_uring_sqe* sqe;
        if (!getSqe(ring, sqe))
        {
            return;
        }

        chan.clear;
        chan.type = FdChanType.timer;

        import time_libs;

        __kernel_timespec timeout;
        timeout.tv_sec = sec;
        timeout.tv_nsec = 0;

        io_uring_prep_timeout(sqe, &timeout, count, flags);
        io_uring_sqe_set_data(sqe, chan);
        if (isSubmit)
        {
            io_uring_submit(ring);
        }
    }

    io_uring_sqe* addPrepTimer(io_uring* ring, ulong sec, uint count = 0, uint flags = 0)
    {
        io_uring_sqe* sqe;
        if (!getSqe(ring, sqe))
        {
            return null;
        }

        import time_libs;

        __kernel_timespec timeout;
        timeout.tv_sec = sec;
        timeout.tv_nsec = 0;
        io_uring_prep_timeout(sqe, &timeout, count, flags);
        return sqe;
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

    bool onWatchdogIsContinue() => true;

    void queueInc()
    {
        _queueCount++;
    }

    void queueDec()
    {
        if (_queueCount == 0)
        {
            return;
        }

        _queueCount--;
    }

    size_t queueCount() => _queueCount;

    override void stop()
    {
        super.stop;

        io_uring_queue_exit(&ring);
        io_uring_close_ring_fd(&ring);
    }

}
