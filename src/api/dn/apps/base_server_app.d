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
        import prctl_libs;

        const pret = prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0);
        if (pret != 0)
        {
            //TODO errno
            throw new Exception("prctl");
        }
        
        import landlock_libs;

         import  std.exception: ErrnoException;

        //TODO native support 
        enum long SYS_landlock_create_ruleset = 444;
        enum long SYS_landlock_add_rule = 445;
        enum long SYS_landlock_restrict_self = 446;

        int d_landlock_create_ruleset(const(void)* attr, size_t size, uint flags)
        {
            return cast(int) syscall(SYS_landlock_create_ruleset, attr, size, flags);
        }

        int d_landlock_add_rule(int ruleset_fd, ulong rule_type, const(void)* rule_attr, uint flags)
        {
            return cast(int) syscall(SYS_landlock_add_rule, ruleset_fd, rule_type, rule_attr, flags);
        }

        int d_landlock_restrict_self(int ruleset_fd, uint flags)
        {
            return cast(int) syscall(SYS_landlock_restrict_self, ruleset_fd, flags);
        }

        landlock_ruleset_attr ruleset_attr;
        ruleset_attr.handled_access_fs = LANDLOCK_ACCESS_FS_READ_FILE | LANDLOCK_ACCESS_FS_WRITE_FILE;

        auto ruleset = d_landlock_create_ruleset(&ruleset_attr, ruleset_attr.sizeof, 0);
        if (ruleset < 0)
        {
            import core.stdc.errno : errno;

            throw new Exception("d_landlock_create_ruleset");
        }

        landlock_path_beneath_attr path_attr;
        path_attr.allowed_access = LANDLOCK_ACCESS_FS_READ_FILE;

        import std.string : toStringz;
        import core.sys.posix.fcntl : O_PATH, O_CLOEXEC, open;
        import core.sys.posix.unistd: close;

        int dir_fd = open(".data/".toStringz, O_PATH | O_CLOEXEC);
        if (dir_fd < 0)
            throw new ErrnoException("Unable open data dir");

        path_attr.parent_fd = dir_fd;
        path_attr.allowed_access = LANDLOCK_ACCESS_FS_READ_FILE | LANDLOCK_ACCESS_FS_WRITE_FILE ;
        const isAdd = d_landlock_add_rule(ruleset, LANDLOCK_RULE_PATH_BENEATH, &path_attr, 0);
        if(isAdd < 0){
            //TODO close fd?
            throw new ErrnoException("d_landlock_add_rule");
        }
        close(dir_fd);

        //d_landlock_add_rule(ruleset, "/usr", LANDLOCK_ACCESS_FS_READ_DIR);
        // d_landlock_add_rule(ruleset, "/tmp", LANDLOCK_ACCESS_FS_READ_DIR);

        // d_landlock_restrict_self(ruleset);

        int result = d_landlock_restrict_self(ruleset, 0);
        if(result < 0){
            throw new ErrnoException("Landlock restrict fail");
        }
        //import std;
        //writeln(result);
        close(ruleset);
        
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

        if (isSandbox)
        {
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

            // addRule("accept4", ctx);
            // addRule("futex", ctx);
            // addRule("madvise", ctx);
            // addRule("epoll_create1", ctx);
            // addRule("epoll_ctl", ctx);
            // addRule("epoll_pwait", ctx);

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
        if (server)
        {
            if (server.isRunning)
            {
                server.stop;
            }

            server.dispose;
        }

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

        uservices.logger.trace("Dispose server app");

        super.dispose; //exit
    }
}
