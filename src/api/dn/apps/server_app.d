module api.dn.apps.server_app;

import api.core.loggers.logging : Logging;
import api.dn.apps.base_server_app : BaseServerApp;
import api.dn.handlers.chan_handler : ChanHandler;
import api.dn.servers.base_server : BaseServer;

import AppKeys = api.dn.app_config_keys;

/**
 * Authors: initkfs
 */
class ServerApp : BaseServerApp
{
    BaseServer delegate() serverProvider;

    this(BaseServer delegate() serverProvider)
    {
        if (!serverProvider)
        {
            throw new Exception("Server provider must not be null");
        }

        this.serverProvider = serverProvider;
    }

    override BaseServer newServer() => serverProvider();
}
