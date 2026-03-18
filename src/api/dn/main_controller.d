module api.dn.main_controller;

import api.core.components.uni_composite : UniComposite;
import api.core.components.uni_component : UniComponent;

import api.dn.protos.http1.servers.https_server: HTTPSServer;
import api.dn.protos.http1.servers.http_server: HTTPServer;
import api.dn.protos.http1.clients.http_client: HTTPClient;
import api.dn.protos.udp.clients.udp_client: UDPClient;

debug import std.stdio: writeln, writefln;

import signal_libs;
import api.dn.sys.locale;

/**
 * Authors: initkfs
 */
class MainController : UniComposite!UniComponent
{
    HTTPServer server;
    UDPClient client;

    override void run()
    {
        client = new UDPClient;
        client.host = "8.8.8.8";
        client.port = "53";
        buildInitCreateRun(client);
    }
}
