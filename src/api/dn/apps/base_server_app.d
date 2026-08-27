module api.dn.apps.base_server_app;

import api.core.apps.cli_app : CliApp;
import api.core.loggers.logging : Logging;
import api.dn.servers.base_server : BaseServer;
import api.dn.handlers.chan_handler : ChanHandler;

import signal_libs;
import api.dn.libs.seccomp.binddynamic;
import api.dn.libs.systemd.binddynamic : SystemdLib;

import AppKeys = api.dn.app_config_keys;

/**
 * Authors: initkfs
 */
abstract class BaseServerApp : CliApp
{
    BaseServer server;

    bool isSystemd;
    SystemdLib systemdLib;

    bool isSandbox;
    SeccompLib seccomp;

    abstract BaseServer newServer();

    override bool initialize(string[] args)
    {
        if (!super.initialize(args))
        {
            return false;
        }

        if (uservices.config.hasKey(AppKeys.systemdIsSupport))
        {
            isSystemd = uservices.config.getBool(
                AppKeys.systemdIsSupport);
        }

        if (uservices.config.hasKey(AppKeys.seccompIsSupport))
        {
            isSandbox = uservices.config.getBool(
                AppKeys.seccompIsSupport);
        }

        return true;
    }

    override void create()
    {
        super.create;

        if(isSandbox){
            loadSeccomp;
        }

        if (isSystemd)
        {
            systemdLib = new SystemdLib;
            systemdLib.onLoad = () { uservices.logger.trace("Load libsystemd"); };
            systemdLib.onErrors = (errs) {
                import std.conv : to;

                uservices.logger.error("Error systemd: " ~ errs.to!string);
                if (isSystemd)
                {
                    isSystemd = false;
                    uservices.logger.info("Disable systemd support on error");
                }
            };
            systemdLib.load;
        }
    }

    override void run()
    {
        super.run;

        server = newServer;
        uservices.build(server);
        server.isSystemd = isSystemd;
        server.isSandbox = isSandbox;
        initCreateRun(server);
    }

    void loadSeccomp()
    {
        seccomp = new SeccompLib;
        seccomp.onLoad = () {

            sigaction_t sa;
            sa.__sigaction_handler.sa_sigaction = &sigsysHandler;
            sa.sa_flags = SA_SIGINFO;
            if (sigaction(SIGSYS, &sa, null) < 0)
            {
                throw new Exception("SIGSYS handler error");
            }

            scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_TRAP);
            if (!ctx)
            {
                throw new Exception("seccomp_init");
            }

            scope (exit)
            {
                seccomp_release(ctx);
            }

            addRule("io_uring_enter", ctx);
            addRule("io_uring_setup", ctx);

            addRule("exit_group", ctx);
            addRule("rt_sigreturn", ctx);
            addRule("rt_sigaction", ctx);
            addRule("prlimit64", ctx);
            addRule("brk", ctx);
            addRule("mmap", ctx);
            addRule("munmap", ctx);
            addRule("mprotect", ctx);
            addRule("write", ctx);
            addRule("openat", ctx);
            addRule("newfstatat", ctx);
            addRule("read", ctx);
            addRule("close", ctx);
            addRule("getcwd", ctx);
            addRule("prctl", ctx);
            addRule("socket", ctx);
            addRule("setsockopt", ctx);
            addRule("bind", ctx);
            addRule("listen", ctx);

            if (seccomp_load(ctx) != 0)
            {
                throw new Exception("seccomp_load");
            }

            isSandbox = true;
            uservices.logger.trace("Load seccomp");
        };

        seccomp.onErrorsStr = (err) {
            uservices.logger.error("Error seccomp loading: " ~ err);
            seccomp.unload;
            seccomp = null;
            isSandbox = false;
        };
    }

    static extern (C) void sigsysHandler(int signum, siginfo_t* info, void* context)
    {
        import core.stdc.stdio : snprintf;
        import core.sys.posix.unistd : write, STDERR_FILENO;
        import core.stdc.string : strlen;

        //pragma(msg, __traits(allMembers, typeof(siginfo_t._sifields._sigsys)));

        int syscallNum = info._sifields._sigsys._syscall;
        uint arch = info._sifields._sigsys._arch;

        char* syscallSame = seccomp_syscall_resolve_num_arch(arch, syscallNum);

        char[256] logBuf;
        auto len = snprintf(logBuf.ptr, logBuf.sizeof,
            "syscall ID: %d (%s)\n",
            syscallNum, syscallSame ? syscallSame : "UNKNOWN");

        write(STDERR_FILENO, logBuf.ptr, len);
        if (syscallSame)
        {
            import core.stdc.stdlib : free;

            free(syscallSame);
        }

        import core.sys.posix.unistd;

        _exit(1);
    }

    override void dispose()
    {
        super.dispose;

        if (systemdLib)
        {
            systemdLib.unload;
            systemdLib = null;
        }

        if (seccomp)
        {
            seccomp.unload;
            seccomp = null;
        }
    }
}
