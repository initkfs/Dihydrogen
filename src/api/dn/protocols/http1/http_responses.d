module api.dn.protocols.http1.http_responses;

/**
 * Authors: initkfs
 */

immutable
{
    string _html = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: 44\r\nConnection: close\r\n\r\n<html><body><h1>It works!</h1></body></html>";

    string _404 = "HTTP/1.1 404 Not Found\r\nContent-Length: 18\r\nConnection: close\r\n\r\n404 Page Not Found";
    string _500 = "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 25\r\nConnection: close\r\n\r\n500 Internal Server Error";
    string _204 = "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
    string _301_html = "HTTP/1.1 301 Moved Permanently\r\nContent-Length: 56\r\nConnection: close\r\n\r\n<html><body><h1>301 Moved Permanently</h1></body></html>";
    string _403 = "HTTP/1.1 403 Forbidden\r\nContent-Length: 13\r\nConnection: close\r\n\r\n403 Forbidden";
    string _400 = "HTTP/1.1 400 Bad Request\r\nContent-Length: 15\r\nConnection: close\r\n\r\n400 Bad Request";
    string _405 = "HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 22\r\nConnection: close\r\n\r\n405 Method Not Allowed";
}

string mimeType(const(char[]) path)
{
    import std.path : extension;
    import std.range : empty, drop;

    auto ext = path.extension;
    if (ext.empty)
    {
        return null;
    }

    ext = ext.drop(1); //remove dot

    import MimeImages = api.dn.utils.mime.image;
    import MimeText = api.dn.utils.mime.text;

    static string[string] extMap = [
        "png": MimeImages.png,
        "jpg": MimeImages.jpeg,
        "js": MimeText.javascript,
        "css": MimeText.css,
        "txt": MimeText.plain,
        "html": MimeText.html,
        "ico": MimeImages.vnd_microsoft_icon
    ];

    if(auto extPtr = ext in extMap){
        return *extPtr;
    }

    return null;
}

string headerLine(string mimeType, string contentLen)
{
    return "HTTP/1.1 200 OK\r\n" ~ mimeType ~ "\r\nContent-Length: " ~ contentLen ~ "\r\nConnection: close\r\n\r\n";
}
