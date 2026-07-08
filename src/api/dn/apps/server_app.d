module api.dn.apps.server_app;

import api.core.loggers.logging : Logging;
import api.dn.apps.base_server_app : BaseServerApp;
import api.dn.handlers.chan_handler : ChanHandler;

import signal_libs;
import api.dn.libs.seccomp.binddynamic;

/**
 * Authors: initkfs
 */
class ServerApp : BaseServerApp
{
    SeccompLib seccomp;

    override void create()
    {
        super.create;

        seccomp = new SeccompLib;
        seccomp.load;

        //TODO errno

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
        addRule("brk", ctx);
        addRule("mmap", ctx);
        addRule("write", ctx);
        addRule("openat", ctx);
        addRule("newfstatat", ctx);
        addRule("read", ctx);
        addRule("close", ctx);
        addRule("getcwd", ctx);
        addRule("mprotect", ctx);
        addRule("prctl", ctx);
        addRule("munmap", ctx);
        addRule("rt_sigaction", ctx);
        addRule("socket", ctx);
        addRule("setsockopt", ctx);
        addRule("bind", ctx);
        addRule("listen", ctx);
        addRule("getuid", ctx);
        addRule("geteuid", ctx);
        addRule("getgid", ctx);
        addRule("getegid", ctx);
        addRule("prlimit64", ctx);

        if (seccomp_load(ctx) != 0)
        {
            throw new Exception("seccomp_load");
        }

        uservices.logger.info("Run seccomp");
    }

    override ChanHandler newAppHandler(Logging logging)
    {
        import api.dn.protos.ws.handlers.ws_handler : WSHandler;

        return new WSHandler(logging);
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
        if (seccomp)
        {
            seccomp.unload;
        }
    }

}
