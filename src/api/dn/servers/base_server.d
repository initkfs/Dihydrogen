module api.dn.servers.base_server;

import api.core.components.uni_composite : UniComposite;
import api.core.components.uni_component : UniComponent;
import api.core.loggers.logging : Logging;

import api.dn.chans.server_chan : ServerChan;
import api.dn.events.routes.event_router : EventRouter;
import api.dn.events.monitors.event_monitor : EventMonitor;
import api.dn.events.converters.event_converter : EventConverter;
import api.dn.pipelines.handler_pipeline : HandlerPipeline;
import api.dn.events.routes.pipeline_router : PipelineRouter;
import api.dn.handlers.chan_handler : ChanHandler;

import api.dn.io.loops.server_loop : ServerLoop;

import core.atomic : atomicLoad, atomicStore;

import signal_libs;

/**
 * Authors: initkfs
 */

class BaseServer : UniComposite!UniComponent
{
    ServerLoop loop;

    static shared int controlFd;

    bool isSystemd;
    bool isSandbox;

    bool isStartOnRun = true;

    ServerLoop newServerLoop(Logging logger, int controlFd, ServerChan[] serverChans, EventRouter router, EventConverter translator = null, EventMonitor monitor = null)
    {
        return new ServerLoop(logger, controlFd, serverChans, router, translator, monitor);
    }

    abstract
    {
        ChanHandler newHandler(Logging logging);
    }

    override void create()
    {
        super.create;

        import core.sys.linux.sys.eventfd;

        int evfd = eventfd(0, EFD_NONBLOCK);
        atomicStore(controlFd, evfd);

        signal(SIGINT, &sigintHandler);
    }

    override void stop()
    {
        super.stop;

        import core.sys.posix.unistd : close;

        auto evfd = controlFd.atomicLoad;
        close(evfd);
        evfd = -1;

        logger.trace("Close control chan");
    }

    void createLoop(ServerChan[] serverChans)
    {
        auto eventRouter = newPipelineRounter(logging);
        auto monitor = newEventMonitor(logging);

        //TODO translator

        loop = newServerLoop(logging, controlFd, serverChans, eventRouter, translator:
            null, monitor);

        loop.isSystemd = isSystemd;
        loop.initialize;
        loop.create;
    }

    PipelineRouter newPipelineRounter(Logging logging)
    {
        return new PipelineRouter(newHandlerPipeline(logging));
    }

    HandlerPipeline newHandlerPipeline(Logging logging)
    {
        auto pipe = new HandlerPipeline;
        pipe.add(newHandler(logging));
        return pipe;
    }

    EventRouter newEventRouter(Logging logging)
    {
        return new PipelineRouter(newHandlerPipeline(logging));
    }

    EventMonitor newEventMonitor(Logging logger)
    {
        import api.dn.events.monitors.log_event_monitor : LogEventMonitor;

        return new LogEventMonitor(logger);
    }

    void logServerInfo()
    {
        import Locale = api.dn.sys.locale;
        import Time = api.dn.sys.time;

        char[64] timeBuff = 0;
        size_t buffLen;
        Time.timestampf(timeBuff, buffLen);

        import std.exception : enforce;

        if (buffLen <= timeBuff.length)
        {
            logger.infof("Server time: %s, %s. LC_ALL:%s, LC_CTYPE:%s, LC_COLLATE:%s", timeBuff[0 .. buffLen], Time.timestamp, Locale
                    .getLocaleInfo, Locale.getLocaleInfoCtype, Locale.getLocaleInfoCollate);
        }
        else
        {
            logger.error("Time buffer overflow");
        }

        import Limit = api.dn.sys.limit;

        logger.infof("Hostname max:%s, page size:%s, max files:%s", Limit.hostNameMax, Limit.pageSize, Limit
                .openFilesProcMax);
    }

    static extern (C) void sigintHandler(int signo)
    {
        import core.sys.posix.unistd : write;
        import api.dn.chans.chan_controls : ChanControlCode;

        auto evfd = controlFd.atomicLoad;

        ulong val = ChanControlCode.exit;
        //TODO LE/BE?
        write(evfd, &val, val.sizeof);

        import core.sys.posix.unistd : write;

        enum msg = "Run sigint handler\n";
        write(1, msg.ptr, msg.length);
    }

    override void dispose()
    {
        super.dispose;

        if (loop)
        {
            if (loop.isRunning)
            {
                loop.stop;
            }
            loop.dispose;
        }
    }
}
