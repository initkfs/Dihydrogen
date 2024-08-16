module app.dn.protocols.http1.http_common;

import app.core.mem.buffers.static_buffer : StaticBuffer;

/**
 * Authors: initkfs
 */

enum HttpControlСhar : byte
{
    //10
    lf = '\n',
    //13
    cr = '\r',
    //0
    nul = 0,
    //58
    colon = ':',
    space = ' '
}

//RFC9110
enum uriMaxSizeBytes = 8000;

enum HttpMethod : string
{
    GET = "GET",
    POST = "POST",
    HEAD = "HEAD",
    CONNECT = "CONNECT",
    DELETE = "DELETE",
    OPTIONS = "OPTIONS",
    PUT = "PUT",
    TRACE = "TRACE",
}

enum HttpVersion : string {
    none = "none",
    http11 = "HTTP/1.1"
}

private
{
    import std.meta: staticSort;
    import std.traits: EnumMembers;

    enum CompLength(string s1, string s2) = s1.length < s2.length;
    enum httpSortedMethods = staticSort!(CompLength, EnumMembers!HttpMethod);
}

enum httpMethodMinSize = httpSortedMethods[0].length;
enum httpMethodMaxSize = httpSortedMethods[$ - 1].length;
