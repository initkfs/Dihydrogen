module api.dn.sys.fs;

import core.sys.posix.sys.stat;

import std.file : getAttributes;

extern(C) nothrow @nogc
{
    char* realpath(const char* path, char* resolved_path);
}

char[10] getAtrrStr(R)(R file) => attrToStr(file.getAttributes);

char[10] attrToStr(uint mode)
{
    char[10] buf = '-';

    if (S_ISDIR(mode))
        buf[0] = 'd';
    else if (S_ISLNK(mode))
        buf[0] = 'l';

    buf[1] = (mode & S_IRUSR) ? 'r' : '-';
    buf[2] = (mode & S_IWUSR) ? 'w' : '-';
    buf[3] = (mode & S_IXUSR) ? 'x' : '-';
    if (mode & S_ISUID)
        buf[3] = 's'; // SUID

    buf[4] = (mode & S_IRGRP) ? 'r' : '-';
    buf[5] = (mode & S_IWGRP) ? 'w' : '-';
    buf[6] = (mode & S_IXGRP) ? 'x' : '-';
    if (mode & S_ISGID)
        buf[6] = 's'; // SGID

    buf[7] = (mode & S_IROTH) ? 'r' : '-';
    buf[8] = (mode & S_IWOTH) ? 'w' : '-';
    buf[9] = (mode & S_IXOTH) ? 'x' : '-';
    if (mode & S_ISVTX)
        buf[9] = 't'; // Sticky bit

    return buf;
}
