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
    api.isStrictConfigs = true;
    auto initRes = api.initialize(args);
    if (!initRes)
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

    assert(api.isInitialized);

    api.create;
    assert(api.isCreated);
    api.run;
    assert(api.isRunning);

    return successCode;
}
