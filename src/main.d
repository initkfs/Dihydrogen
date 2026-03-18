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

    return successCode;
}
