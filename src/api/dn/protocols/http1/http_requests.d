module api.dn.protocols.http1.http_requests;

/**
 * Authors: initkfs
 */

string get(string host)
{
    import std.format : format;

    return format("GET / HTTP/1.1\r\nHost: %s\r\nUser-Agent: curl/7.81.0\r\nAccept: */*\r\n\r\n", host);
}
