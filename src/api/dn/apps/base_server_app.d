module api.dn.apps.base_server_app;

import api.core.apps.cli_app : CliApp;
import api.core.loggers.logging : Logging;
import api.dn.protos.http1.servers.base_http_server : BaseHTTPServer;
import api.dn.handlers.chan_handler : ChanHandler;

import api.dn.libs.systemd.binddynamic : SystemdLib;

/**
 * Authors: initkfs
 */
abstract class BaseServerApp : CliApp
{
    BaseHTTPServer server;

    bool isSystemd;
    SystemdLib systemdLib;

    override void run()
    {
        super.run;

        import AppKeys = api.dn.app_config_keys;

        if (uservices.config.hasKey(AppKeys.systemdIsSupport) && uservices.config.getBool(
                AppKeys.systemdIsSupport))
        {
            isSystemd = true;
        }

        if (isSystemd)
        {
            systemdLib = new SystemdLib;
            systemdLib.onErrors = (errs) {
                import std.conv : to;

                uservices.logger.error("Error systemd: " ~ errs.to!string);
                if (isSystemd)
                {
                    isSystemd = false;
                    uservices.logger.info("Disable systemd support on error");
                }
            };
            systemdLib.load;
            uservices.logger.trace("Load libsystemd");
        }

        server = newServer;
        uservices.build(server);

        server.isSystemd = isSystemd;

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

    override void stop()
    {
        super.stop;

        if (systemdLib)
        {
            systemdLib.unload;
        }
    }
}
