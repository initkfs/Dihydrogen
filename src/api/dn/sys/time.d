module api.dn.sys.time;

import time_libs;

/**
 * Authors: initkfs
 */

enum realClockId = CLOCK_REALTIME_COARSE;

long timestamp()
{
    timespec tms;
    enum clockErr = -1;
    if (time_libs.clock_gettime(realClockId, &tms) == clockErr)
    {
        return clockErr;
    }
    return tms.tv_sec;
}

bool timestampf(char[] buff, out size_t buffLen, const(char[]) pattern = "%Y-%m-%dT%H:%M:%S")
{
    timespec tms;
    if (time_libs.clock_gettime(realClockId, &tms) == -1)
    {
        return false;
    }

    tm timeRes;
    if (!gmtime_r(&tms.tv_sec, &timeRes))
    {
        return false;
    }

    size_t len = strftime(buff.ptr, buff.length, pattern.ptr, &timeRes);
    if (len == 0)
    {
        return false;
    }
    buffLen = len;
    return true;
}
