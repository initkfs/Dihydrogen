module api.dn.handlers.clients.base_handler_client;

import api.core.components.uni_composite: UniComposite;
import api.core.components.uni_component : UniComponent;
import api.dn.handlers.channel_handler : ChannelHandler;
import api.dn.channels.server_channel : ServerChannel;
import api.dn.events.routes.event_router : EventRouter;
import api.dn.events.converters.event_converter : EventConverter;
import api.dn.events.monitors.event_monitor : EventMonitor;
import api.dn.pipelines.handler_pipeline : HandlerPipeline;
import api.dn.io.loops.client_loop : ClientLoop;

import api.core.loggers.logging : Logging;

/**
 * Authors: initkfs
 */
abstract class BaseHandlerClient : UniComposite!UniComponent
{
    string host;
    string port;
    string path;

    ClientLoop loop;

    abstract
    {
        ChannelHandler newHandler(Logging logging);
    }

    HandlerPipeline createPipeline()
    {
        auto pipe = new HandlerPipeline;
        pipe.add(newHandler(logging));
        return pipe;
    }

     ClientLoop newClientLoop(Logging logger, ServerChannel serverChan, EventRouter router, EventConverter translator = null, EventMonitor monitor = null)
    {
        return new ClientLoop(logger, serverChan, router, translator, monitor);
    }

}
