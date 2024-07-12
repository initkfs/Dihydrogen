/**
 * Authors: initkfs
 */

int main(string[] args)
{
    version (linux)
    {
        version (DigitalMars)
        {
            import etc.linux.memoryerror : registerMemoryErrorHandler;

            registerMemoryErrorHandler;
        }

    }

    import dn.apps.server_app : ServerApp;

    auto app = new ServerApp;
    app.isStrictConfigs = true;
    if (app.initialize(args))
    {
        import std;

        writeln("Not initialized!");
        return 1;
    }

    app.create;
    app.run;

    return 0;
}
