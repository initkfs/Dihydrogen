module app.dn.io.loops.multi_event_loop;

import core.thread.osthread : Thread;
import app.dn.io.loops.server_loop : ServerLoop;
import app.dn.io.loops.one_pipeline_event_loop : OnePipelineEventLoop;
import app.dn.channels.server_channel : ServerChannel;
import app.dn.io.loops.event_loop : EventLoop;
import app.dn.channels.fd_channel : FdChannel, FdChannelType;
import app.dn.channels.commands.channel_context : ChannelCommand, ChannelCommandType;
import app.dn.channels.pipes.pipeline : Pipeline;
import app.dn.net.sockets.socket_connect : SocketConnectState;

import io_uring_libs;
import app.dn.io.natives.iouring.io_uring;
import app.dn.io.natives.iouring.io_uring_types;

import std.logger : Logger;
import std.concurrency;

class EventLoopThread : Thread
{
    import std.logger;
    import std.stdio : stdout;
    import core.time : dur;
    import app.dn.pools.linear_pool : LinearPool;
    import core.stdc.stdlib : malloc, exit;
    import app.dn.io.natives.iouring.io_uring;
    import app.dn.io.natives.iouring.io_uring_types;
    import io_uring_libs;
    import core.atomic;

    immutable(Pipeline delegate()) workerPipelineProvider;
    int workerIndex;
    FileLogger newLogger;

    private
    {
        LinearPool!(FdChannel*) pool;
        EventLoop loop;
        Pipeline pipeline;

        shared int[512] queue;
        shared size_t queueSize;
        shared size_t queueIdx;
        shared bool isComplete;
    }

    void setComplete()
    {
        isComplete = true;
    }

    void addFd(int fd)
    {
        assert(queueIdx < queue.length);

        queue[queueIdx] = fd;

        atomicOp!"+="(queueIdx, 1UL);
        atomicOp!"+="(queueSize, 1UL);
    }

    this(int workerIndex, immutable(Pipeline delegate()) workerPipelineProvider)
    {
        super(&run);
        this.workerPipelineProvider = workerPipelineProvider;
        this.workerIndex = workerIndex;
    }

    void addAcept(int fd)
    {
        // while (!pool.hasIndex(fd))
        // {
        //     if (!pool.increase)
        //     {
        //         newLogger.error("Error change buffer size");
        //         exit(1);
        //     }
        // }

        // auto conn = pool.get(fd);
        // if (!conn)
        // {
        //     auto newConnect = loop.newChannel(fd);
        //     pool.set(fd, newConnect);
        //     conn = newConnect;
        // }
        // else
        // {
        //     conn.fd = fd;
        //     conn.state = SocketConnectState.none;
        //     conn.availableBytes = 0;
        // }

        // auto acceptCtx = pipeline.onAccept(conn);
        // loop.runContext(acceptCtx);
    }

    private void run()
    {
        // newLogger = new FileLogger(stdout, LogLevel.trace);
        // try
        // {

        //     loop = new class EventLoop
        //     {
        //         this()
        //         {
        //             super(newLogger);
        //         }

        //         override int getEvents(io_uring* ring, io_uring_cqe** cqes, out bool isError)
        //         {
        //             return getEventsPeek(ring, cqes, isError);
        //         }
        //     };

        //     pool = new LinearPool!(FdChannel*)(2048);
        //     pool.create;
        //     foreach (i; 0 .. pool.count)
        //     {
        //         pool.set(i, loop.newChannel);
        //     }
        //     newLogger.infof("Create worker pool with id %d", workerIndex);

        //     pipeline = workerPipelineProvider();
        //     newLogger.infof("Create worker pipeline");

        //     loop.onRead = (chan) { return pipeline.onRead(chan); };
        //     loop.onReadEnd = (chan) { return pipeline.onReadEnd(chan); };
        //     loop.onWrite = (chan) { return pipeline.onWrite(chan); };
        //     loop.onClose = (chan) { pipeline.onClose(chan); };

        //     loop.initialize;
        //     loop.create;

        //     newLogger.infof("Run worker loop №%d", workerIndex);

        //     while (true)
        //     {
        //         if (isComplete)
        //         {
        //             foreach (int fd; queue[0 .. queueSize])
        //             {
        //                 addAcept(fd);
        //             }

        //             atomicExchange(&queueIdx, 0);
        //             atomicExchange(&queueSize, 0);
        //             atomicExchange(&isComplete, false);
        //         }

        //         if (!loop.runStepIsContinue)
        //         {
        //             break;
        //         }
        //     }
        // }
        // catch (Throwable e)
        // {
        //     import std;

        //     writefln("Worker id %d error: %s", workerIndex, e);
        // }
    }
}

/**
 * Authors: initkfs
 */
class MultiEventLoop : ServerLoop
{
    int loopNum = 1;
    EventLoopThread[] workers;

    immutable(Pipeline delegate()) workerPipelineProvider;

    this(Logger logger, ServerChannel[] serverChans, immutable(
            Pipeline delegate()) workerPipelineProvider)
    {
        super(logger, serverChans);
        this.workerPipelineProvider = workerPipelineProvider;
    }

    override void create()
    {
        super.create;

        onBatchIsContinue = (io_uring_cqe*[] cqes) {
            foreach (cqe; cqes)
            {
                auto conn = channelFromCQE(cqe);
                if (conn.state == SocketConnectState.accept)
                {
                    auto newFd = cqe.res;
                    assert(newFd >= 0);

                    auto tidIndex = newFd % workers.length;
                    auto worker = workers[tidIndex];
                    worker.addFd(newFd);
                }
            }

            foreach (worker; workers)
            {
                worker.setComplete;
            }

            return false;
        };

        foreach (int i; 0 .. loopNum)
        {
            auto newWorker = new EventLoopThread(i, workerPipelineProvider);
            workers ~= newWorker;
            newWorker.start;
        }
    }

}
