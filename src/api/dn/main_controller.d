module api.dn.main_controller;

import api.core.controllers.controller : Controller;
import api.core.components.uni_component : UniComponent;

import api.dn.servers.https_server: HTTPSServer;
import api.dn.servers.http_server: HTTPServer;
import api.dn.clients.http_client: HTTPClient;

debug import std.stdio: writeln, writefln;

import signal_libs;
import api.dn.sys.locale;

/**
 * Authors: initkfs
 */
class MainController : Controller!UniComponent
{
    HTTPServer server;
    HTTPClient client;

    override void run()
    {
        client = new HTTPClient;
        client.host = "http://site";
        client.path = "/echo/get/json";
        buildInitCreateRun(client);
    }
}
