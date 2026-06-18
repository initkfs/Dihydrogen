module api.dn.apps.base_server_app;

import api.core.apps.cli_app : CliApp;
import api.core.loggers.logging: Logging;
import api.dn.protos.http1.servers.base_http_server : BaseHTTPServer;
import api.dn.handlers.chan_handler : ChanHandler;

/**
 * Authors: initkfs
 */
abstract class BaseServerApp : CliApp
{
    BaseHTTPServer server;

    override void run()
    {
        super.run;

        server = newServer;
        uservices.build(server);
        initCreateRun(server);
    }

    abstract ChanHandler newAppHandler(Logging logging);

    BaseHTTPServer newServer()
    {
        return new class BaseHTTPServer
        {
            override ChanHandler newHandler(Logging logging)
            {
                return newAppHandler(logging);
            }
        };
    }
}
