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

    auto app = new ServerApp;
    app.isStrictConfigs = true;
    auto initRes = app.initialize(args);
    if (!initRes.isInit)
    {
        import std.stdio : stderr;

        stderr.writeln("Not initialized!");
        return errorCode;
    }

    if (initRes.isExit)
    {
        import std.stdio : writeln;

        writeln("App exit");
        return successCode;
    }

    assert(app.isInitializing);

    app.create;
    assert(app.isCreating);
    app.run;
    assert(app.isRunning);

    return successCode;
}
