module api.dn.sys.limit;

import core.stdc.config : c_long;
import std.conv : to;
import time_libs;

import sys_libs;

/**
 * Authors: initkfs
 */

private long getConf(int name)
{
    c_long ret = sys_libs.sysconf(name);
    if (ret == -1)
    {
        return ret;
    }
    return ret.to!long;
}

long hostNameMax() => getConf(_SC_HOST_NAME_MAX);
long pageSize() => getConf(_SC_PAGESIZE);
long openFilesProcMax() => getConf(_SC_OPEN_MAX);
