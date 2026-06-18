module api.dn.libs.systemd.util;
/**
 * Authors: initkfs
 */

bool isInSystemd(string envId = "INVOCATION_ID")
{
    import std.process : environment;

    return environment.get(envId) !is null;
}

void sendReady()
{
    import api.dn.libs.systemd.binddynamic : sd_notify;

    sd_notify(0, "READY=1");
}
