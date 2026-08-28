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

/**
 * Authors: initkfs
 */

class BaseServer : UniComposite!UniComponent
{
    ServerLoop loop;

    bool isSystemd;
    bool isSandbox;

    bool isStartOnRun = true;

    ServerLoop newServerLoop(Logging logger, ServerChan[] serverChans, EventRouter router, EventConverter translator = null, EventMonitor monitor = null)
    {
        return new ServerLoop(logger, serverChans, router, translator, monitor);
    }

    abstract
    {
        ChanHandler newHandler(Logging logging);
    }

    override void run()
    {
        super.run;
    }

    void createLoop(ServerChan[] serverChans)
    {
        auto eventRouter = newPipelineRounter(logging);
        auto monitor = newEventMonitor(logging);
        
        //TODO translator

        loop = newServerLoop(logging, serverChans, eventRouter, translator:
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
}

static extern (C) void sigintHandler(int signo)
{
    import std.stdio : writefln;

    // writefln("^C pressed. Server socket '%s'", [
    //     serverSocket1.fd, serverSocket2.fd
    // ]);

    // if (loop)
    // {
    //     loop.stop;
    //     loop.dispose;
    //     loop = null;
    // }

    // if (serverSocket1)
    // {
    //     serverSocket1.stop;
    //     serverSocket1.dispose;
    //     serverSocket1 = null;
    // }

    // if (serverSocket2)
    // {
    //     serverSocket2.stop;
    //     serverSocket2.dispose;
    //     serverSocket2 = null;
    // }

    //exit(0);
}
