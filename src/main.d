module main;

/**
 * Authors: initkfs
 */

int main(string[] args)
{
    enum errorCode = 1;
    enum successCode = 0;

    version (linux)
    {
        version (DigitalMars)
        {
            import etc.linux.memoryerror : registerMemoryErrorHandler;

            registerMemoryErrorHandler;
        }

    }

    import api.dn.apps.server_app : ServerApp;
    import api.dn.protos.http1.servers.http_server: HTTPServer;

    auto app = new ServerApp(() => new HTTPServer);
    if (!app.initialize(args))
    {
        import std.stdio : stderr;

        stderr.writeln("Not initialized!");
        return errorCode;
    }

    assert(app.isInitializing);

    app.create;
    assert(app.isCreating);

    app.run;
    assert(app.isRunning);

    app.stop;
    assert(app.isStopping);

    app.dispose;
    assert(app.isDisposing);

    return successCode;
}
