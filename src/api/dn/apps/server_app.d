module api.dn.apps.server_app;

import api.core.loggers.logging: Logging;
import api.dn.apps.base_server_app : BaseServerApp;
import api.dn.handlers.chan_handler : ChanHandler;

/**
 * Authors: initkfs
 */
class ServerApp : BaseServerApp
{
    override ChanHandler newAppHandler(Logging logging)
    {
        import api.dn.protos.ws.handlers.ws_handler : WSHandler;

        return new WSHandler(logging);
    }

}
