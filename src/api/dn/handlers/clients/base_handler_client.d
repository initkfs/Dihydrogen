module api.dn.handlers.clients.base_handler_client;

import api.core.components.uni_composite : UniComposite;
import api.core.components.uni_component : UniComponent;
import api.dn.handlers.chan_handler : ChanHandler;
import api.dn.chans.server_chan : ServerChan;
import api.dn.events.routes.event_router : EventRouter;
import api.dn.events.converters.event_converter : EventConverter;
import api.dn.events.monitors.event_monitor : EventMonitor;
import api.dn.pipelines.handler_pipeline : HandlerPipeline;
import api.dn.io.loops.client_loop : ClientLoop;

import api.core.loggers.logging : Logging;

import core.atomic : atomicLoad, atomicStore;

/**
 * Authors: initkfs
 */
abstract class BaseHandlerClient : UniComposite!UniComponent
{
    string host;
    string port;
    string path;

    static shared int controlFd;

    ClientLoop loop;

    abstract
    {
        ChanHandler newHandler(Logging logging);
    }

    override void create()
    {
        import core.sys.linux.sys.eventfd;

        int evfd = eventfd(0, EFD_NONBLOCK);
        atomicStore(controlFd, evfd);
    }

    HandlerPipeline createPipeline()
    {
        auto pipe = new HandlerPipeline;
        pipe.add(newHandler(logging));
        return pipe;
    }

    ClientLoop newClientLoop(Logging logger, int controlFd, ServerChan serverChan, EventRouter router, EventConverter translator = null, EventMonitor monitor = null)
    {
        return new ClientLoop(logger, controlFd, serverChan, router, translator, monitor);
    }

}
