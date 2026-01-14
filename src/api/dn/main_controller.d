module api.dn.main_controller;

import api.core.controllers.controller : Controller;
import api.core.components.uni_component : UniComponent;

import api.dn.servers.https_server: HTTPSServer;
import api.dn.servers.http_server: HTTPServer;
import api.dn.clients.http_client: HTTPClient;
import api.dn.clients.udp_client: UDPClient;

debug import std.stdio: writeln, writefln;

import signal_libs;
import api.dn.sys.locale;

/**
 * Authors: initkfs
 */
class MainController : Controller!UniComponent
{
    HTTPServer server;
    UDPClient client;

    override void run()
    {
        client = new UDPClient;
        client.host = "8.8.8.8";
        client.port = 53;
        buildInitCreateRun(client);
    }
}
