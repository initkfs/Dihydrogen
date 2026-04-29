module api.dn.main_controller;

import api.core.components.uni_composite : UniComposite;
import api.core.components.uni_component : UniComponent;

import api.dn.protos.http1.servers.https_server : HTTPSServer;
import api.dn.protos.http1.servers.base_http_server : BaseHTTPServer;
import api.dn.protos.http1.servers.http_server : HTTPServer;
import api.dn.protos.http1.clients.http_client : HTTPClient;
import api.dn.protos.udp.clients.udp_client : UDPClient;

debug import std.stdio : writeln, writefln;

import signal_libs;
import api.dn.sys.locale;

/**
 * Authors: initkfs
 */
class MainController : UniComposite!UniComponent
{
    BaseHTTPServer server;
    UDPClient client;

    override void run()
    {
        import api.dn.handlers.channel_handler : ChannelHandler;
        import api.core.loggers.logging : Logging;
        import api.dn.protos.ws.handlers.ws_handler : WSHandler;

        server = new class BaseHTTPServer
        {
            override ChannelHandler newHandler(Logging logging)
            {
                return new WSHandler(logging);
            }
        };
        buildInitCreateRun(server);
    }
}
