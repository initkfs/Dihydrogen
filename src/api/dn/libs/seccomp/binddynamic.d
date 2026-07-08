module api.dn.libs.seccomp.binddynamic;

/**
 * Authors: initkfs
 */

import api.core.contexts.libs.dynamics.dynamic_loader : DynamicLoader;

extern (C) nothrow
{
    alias scmp_filter_ctx = void*;
    enum
    {
        SCMP_ACT_KILL_PROCESS = 0x80000000U,
        //dmesg | grep seccomp
        //journalctl -k | grep seccomp
        SCMP_ACT_LOG = 0x7ffc0000U,
        SCMP_ACT_TRAP = 0x00030000U,
        SCMP_ACT_ALLOW = 0x7fff0000U

    }

    scmp_filter_ctx function(uint def_action) seccomp_init;
    char* function(uint arch_token, int num) seccomp_syscall_resolve_num_arch;
    int function(scmp_filter_ctx ctx,
        uint action, int syscall, uint arg_cnt, ...) seccomp_rule_add;
    int function(const scmp_filter_ctx ctx) seccomp_load;
    void function(scmp_filter_ctx ctx) seccomp_release;
    int function(const char* name) seccomp_syscall_resolve_name;
    int function(const scmp_filter_ctx ctx, int fd) seccomp_export_bpf;

}

class SeccompLib : DynamicLoader
{
    protected
    {

    }

    override void bindAll()
    {
        //bind(&sd_notify, "sd_notify");
        bind(&seccomp_init, "seccomp_init");
        bind(&seccomp_syscall_resolve_num_arch, "seccomp_syscall_resolve_num_arch");
        bind(&seccomp_rule_add, "seccomp_rule_add");
        bind(&seccomp_load, "seccomp_load");
        bind(&seccomp_release, "seccomp_release");
        bind(&seccomp_syscall_resolve_name, "seccomp_syscall_resolve_name");
        bind(&seccomp_export_bpf, "seccomp_export_bpf");
    }

    version (Posix)
    {
        string[] paths = [
            "libseccomp.so.2"
        ];
    }
    else
    {
        string[] paths;
    }

    override string[] libPaths()
    {
        return paths;
    }
}

void addRule(string name, scmp_filter_ctx ctx)
{
    import std.string : toStringz;

    int num = seccomp_syscall_resolve_name(name.toStringz);
    if (num < 0)
    {
        import std.format : format;

        throw new Exception(format("Invalid syscall %s: %d", name, num));
    }

    if (seccomp_rule_add(ctx, SCMP_ACT_ALLOW, num, 0) != 0)
    {
        throw new Exception("Error adding rule: " ~ name);
    }
}
