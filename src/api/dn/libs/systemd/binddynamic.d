module api.dn.libs.systemd.binddynamic;

/**
 * Authors: initkfs
 */

/** 
 * TODO: journald + sd_journal_print, socket activation, etc
 */
import api.core.contexts.libs.dynamics.dynamic_loader : DynamicLoader;

extern (C) nothrow
{
    int function(int unset_environment,
        const char* state) sd_notify;

    int function(int unset_environment) sd_listen_fds;

    int function(int unset_environment,
        char*** names) sd_listen_fds_with_names;

}

class SystemdLib : DynamicLoader
{
    protected
    {

    }

    override void bindAll()
    {
        bind(&sd_notify, "sd_notify");
        bind(&sd_listen_fds, "sd_listen_fds");
        bind(&sd_listen_fds_with_names, "sd_listen_fds_with_names");
    }

    version (Posix)
    {
        string[] paths = [
            "libsystemd.so.0"
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
