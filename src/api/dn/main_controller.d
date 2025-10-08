module api.dn.main_controller;

import api.core.controllers.controller : Controller;
import api.core.components.uni_component : UniComponent;

import api.dn.servers.https_server: HTTPSServer;

debug import std.stdio: writeln, writefln;

import signal_libs;
import api.dn.sys.locale;

/**
 * Authors: initkfs
 */
class MainController : Controller!UniComponent
{
    HTTPSServer server;

    override void run()
    {
        server = new HTTPSServer;
        buildInitCreateRun(server);
    }
}
