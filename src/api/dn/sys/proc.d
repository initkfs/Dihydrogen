module api.dn.sys.proc;

import sys_libs;

/**
 * Authors: initkfs
 */

uid_t getRealUserId() @trusted => sys_libs.getuid();
uid_t getEffectiveUserId() @trusted => sys_libs.geteuid();
gid_t getRealGroupId() @trusted => sys_libs.getgid();
gid_t getEffectifeGroupId() @trusted => sys_libs.getegid();
