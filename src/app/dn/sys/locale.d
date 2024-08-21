module app.dn.sys.locale;

import sys_libs;

/**
 * Authors: initkfs
 */

//TODO LC_* macros

bool setLocaleFromEnv()
{
    if (!setlocale(__LC_ALL, ""))
    {
        return false;
    }
    return true;
}

string getLocaleInfo(int category = __LC_ALL)
{
    import std.string : fromStringz;

    if (auto localePtr = setlocale(category, null))
    {
        return localePtr.fromStringz.idup;
    }
    return null;
}

string getLocaleInfoCtype() => getLocaleInfo(__LC_CTYPE);
string getLocaleInfoCollate() => getLocaleInfo(__LC_COLLATE);