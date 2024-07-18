module dn.io.loops.pool_pipeline_event_loop;

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

import dn.io.loops.event_loop : EventLoop;
import core.components.units.services.loggable_unit : LoggableUnit;
import dn.pools.linear_pool : LinearPool;
import dn.channels.fd_channel : FdChannel, FdChannelType;
import dn.net.sockets.socket_connect : SocketConnectState;
import dn.channels.contexts.channel_context : ChannelContext, ChannelContextType;
import dn.channels.server_channel: ServerChannel;
import dn.channels.pipes.pipleline : Pipeline;

/**
 * Authors: initkfs
 */
class PoolPipelineEventLoop : EventLoop
{
    int pipelinePoolSize = 100;

    LinearPool!(Pipeline) pipelinePool;

    Pipeline delegate() pipelineFactory;
    void delegate(Pipeline) pipelineDestroyer;

    bool isDestroyPipeAfterClose = true;

    this(Logger logger, ServerChannel[] serverSockets, Pipeline delegate() pipelineFactory, void delegate(
            Pipeline) pipelineDestroyer)
    {
        super(logger, serverSockets);

        assert(pipelineFactory);
        this.pipelineFactory = pipelineFactory;

        assert(pipelineDestroyer);
        this.pipelineDestroyer = pipelineDestroyer;
    }

    override void create()
    {
        super.create;

        pipelinePool = new LinearPool!(Pipeline)(pipelinePoolSize);
        pipelinePool.create;

        onAccept = (chan) {
            while (!pipelinePool.hasIndex(chan.fd))
            {
                if (!pipelinePool.increase)
                {
                    logger.error("Error change pipeline pool size");
                    exit(1);
                }
            }

            auto pipeline = pipelinePool.get(chan.fd);
            if (!pipeline)
            {
                auto newPipeline = pipelineFactory();
                pipelinePool.set(chan.fd, newPipeline);
                pipeline = newPipeline;
            }

            return pipeline.onAccept(chan);

        };

        onRead = (chan) {
            auto pipeline = pipelinePool.get(chan.fd);
            assert(pipeline);

            return pipeline.onRead(chan);
        };

        onReadEnd = (chan) {
            auto pipeline = pipelinePool.get(chan.fd);
            assert(pipeline);

            return pipeline.onReadEnd(chan);
        };

        onWrite = (chan) {
            auto pipeline = pipelinePool.get(chan.fd);
            assert(pipeline);

            return pipeline.onWrite(chan);
        };

        onClose = (chan) {
            auto pipeline = pipelinePool.get(chan.fd);
            assert(pipeline);

            //TODO calling before context runs can be destructive.
            if (isDestroyPipeAfterClose)
            {
                pipelineDestroyer(pipeline);
                pipelinePool.set(chan.fd, null);
            }
        };

    }
}
