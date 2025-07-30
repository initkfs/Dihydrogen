module api.dn.protocols.http1.static_http_decoder;

import api.dn.codecs.codec : Codec;

import api.dn.protocols.http1.http_common;

import std.typecons : Nullable;

debug import std.stdio : writefln, writeln;

enum DecoderState : string
{
    none = "none",
    ok = "ok",
    error = "Common parser error",
    end = "End",

    parseUriLine = "URI line parsing",
    parseProtoVersionLine = "Protocol version line parsing",
    parseHeadersLine = "Headers parsing",
    parseBodyLine = "Body parsing",

    errorInvalidMethod = "Error. Invalid HTTP method",
    errorEmptyMethod = "Error. Empty HTTP method",
    errorMethodTooLong = "Error. HTTP method too long",
    errorMethodTooShort = "Error. HTTP method too short",
    errorMethodOnly = "Error. Only method in request",
    errorEmptyRequest = "Error. Empty request",
    errorInvalidDupCharsInUriLine = "Error. Invalid special characters duplication in URI line",
    errorInvalidUriLine = "Error. Invalid URI line",
    errorInvalidCharsInUriLine = "Error. Invalid chars in URI line",
    errorUriLineTooLong = "Error. URI line too long",
    errorNoUriLine = "Error. No URI line",
    errorInvalidHeadersLine = "Error. Invalid headers line",
    errorInvalidBodyLine = "Error. Invalid body line",
    errorInvalidProtoVersionLine = "Error. Invalid protocol version",
    errorInvalidMessage = "Error. Invalid message",
    errorNoProtoVersion = "Error. No protocol version",
    errorNoHeadersNoBody = "Error. No headers, no body in request",
    errorBodyTooLong = "Error. Body too long"
}

/** 
 * RFC9112
 * HTTP-message   = start-line CRLF
                    *( field-line CRLF )
                    CRLF
                    [ message-body ]

   start-line     = request-line / status-line
 */

/**
 * Authors: initkfs
 */
class StaticHttpDecoder : Codec
{
    DecoderState state;

    char cr = HttpControlСhar.cr;
    char lf = HttpControlСhar.lf;

    size_t limitBodySizeBytes = size_t.max;
    size_t limitHeadersCount = 20;
    size_t limitUriLength = uriMaxSizeBytes;
    bool isStrictUri = true;

    //10-100Mb 
    enum defaultLimitBodyLength = 30 * 1024;
    size_t limitBodyLength = defaultLimitBodyLength;

    char[] requestMethodSlice;
    char[] uriSlice;
    char[] headersLineSlice;
    ubyte[] bodySlice;

    HttpVersion httpVersion;

    //StaticBuffer!(StompHeader!(char, 256, 256), 20, false) headers;

    void decode(ubyte[] buff)
    {

        reset;

        if (buff.length == 0)
        {
            state = DecoderState.errorEmptyRequest;
            return;
        }

        ubyte[] buffSlice = buff;

        parseLoop: while (buffSlice.length > 0)
        {
            switch (state) with (DecoderState)
            {
                case none:
                    size_t requestMethodSize;
                    size_t requestSepSize;
                    state = parseRequestMethod(buffSlice, requestMethodSize, requestSepSize);
                    if (state != DecoderState.ok)
                    {
                        return;
                    }

                    if (requestMethodSize > 0 && requestMethodSize == buffSlice.length)
                    {
                        state = DecoderState.errorMethodOnly;
                        return;
                    }

                    if (requestMethodSize == 0)
                    {
                        state = DecoderState.errorEmptyMethod;
                        return;
                    }

                    if ((requestMethodSize + requestSepSize) > buffSlice.length)
                    {
                        state = DecoderState.errorInvalidMethod;
                        return;
                    }

                    //TODO validateMethods;
                    requestMethodSlice = cast(char[]) buffSlice[0 .. requestMethodSize];

                    buffSlice = buffSlice[(requestMethodSize + requestSepSize) .. $];

                    if (buffSlice.length == 0)
                    {
                        state = DecoderState.errorNoUriLine;
                        return;
                    }

                    state = DecoderState.parseUriLine;
                    break;
                case parseUriLine:
                    size_t uriSize;
                    size_t uriSepSize;
                    state = parseUri(buffSlice, uriSize, uriSepSize);

                    if (state != DecoderState.ok)
                    {
                        return;
                    }

                    if (uriSize == 0)
                    {
                        state = DecoderState.errorNoUriLine;
                        return;
                    }
                    else
                    {
                        if (uriSize + uriSepSize == buffSlice.length)
                        {
                            state = DecoderState.errorNoProtoVersion;
                            return;
                        }
                    }

                    if (uriSize + uriSepSize > buffSlice.length)
                    {
                        state = DecoderState.errorInvalidUriLine;
                        return;
                    }

                    uriSlice = cast(char[]) buffSlice[0 .. uriSize];

                    buffSlice = buffSlice[(uriSize + uriSepSize) .. $];

                    if (buffSlice.length == 0)
                    {
                        state = DecoderState.errorNoProtoVersion;
                        return;
                    }

                    state = DecoderState.parseProtoVersionLine;
                    break;
                case parseProtoVersionLine:
                    HttpVersion mustBeHttpVersion;
                    size_t versionEolSize;
                    state = parseProtoVersion(buffSlice, mustBeHttpVersion, versionEolSize);

                    if (state != DecoderState.ok)
                    {
                        return;
                    }

                    if (buffSlice.length < mustBeHttpVersion.length + versionEolSize)
                    {
                        state = DecoderState.errorInvalidProtoVersionLine;
                        return;
                    }

                    httpVersion = mustBeHttpVersion;

                    buffSlice = buffSlice[(mustBeHttpVersion.length + versionEolSize) .. $];

                    if (buffSlice.length == 0)
                    {
                        state = DecoderState.errorNoHeadersNoBody;
                        return;
                    }

                    if (buffSlice[0] == HttpControlСhar.cr && buffSlice[1] == HttpControlСhar.lf)
                    {
                        state = DecoderState.parseBodyLine;
                        continue;
                    }

                    if (buffSlice.length < 2)
                    {
                        state = DecoderState.errorInvalidMessage;
                        return;
                    }

                    //TODO Reason phrase
                    //status-line = HTTP-version SP status-code SP [ reason-phrase ]

                    state = DecoderState.parseHeadersLine;
                    break;
                case parseHeadersLine:
                    size_t headersSize;
                    size_t headersEolSize;
                    state = parseHeaders(buffSlice, headersSize, headersEolSize);
                    if (state != DecoderState.ok)
                    {
                        return;
                    }

                    if (headersSize == 0 || headersEolSize == 0 || (
                            (headersSize + headersEolSize) > buffSlice.length))
                    {
                        state = DecoderState.errorInvalidHeadersLine;
                        return;
                    }

                    headersLineSlice = cast(char[]) buffSlice[0 .. headersSize];

                    buffSlice = buffSlice[(headersSize + headersEolSize) .. $];
                    if (buffSlice.length == 0)
                    {
                        state = DecoderState.end;
                        return;
                    }

                    state = parseBodyLine;
                    break;
                case parseBodyLine:
                    size_t bodySize;
                    state = parseBody(buffSlice, bodySize);
                    if (state != DecoderState.ok)
                    {
                        return;
                    }

                    if (bodySize == 0)
                    {
                        state = DecoderState.end;
                        return;
                    }

                    bodySlice = buffSlice[0 .. bodySize];

                    state = DecoderState.end;
                    return;

                    break;
                default:
                    break parseLoop;
            }
        }
    }

    void reset()
    {
        state = DecoderState.none;

        httpVersion = HttpVersion.none;

        requestMethodSlice = null;
        uriSlice = null;
        headersLineSlice = null;
        bodySlice = null;
    }

    DecoderState parseBody(scope const(ubyte)[] buffer, out size_t bodySize)
    {
        size_t offset;
        foreach (b; buffer)
        {
            if (offset >= limitBodyLength)
            {
                return DecoderState.errorBodyTooLong;
            }

            if (b == HttpControlСhar.nul)
            {
                bodySize = offset;
                return DecoderState.ok;
            }

            offset++;
        }

        return DecoderState.ok;
    }

    DecoderState parseHeaders(scope const(ubyte)[] buffer, out size_t headersSize, out size_t headersEolSize)
    {
        enum eolSizeof = cr.sizeof + lf.sizeof;
        //TODO <= eolSizeof
        if (buffer.length < eolSizeof * 2)
        {
            return DecoderState.errorInvalidHeadersLine;
        }
        size_t lastIndex = buffer.length - 1;
        for (size_t i = 0; i < buffer.length; i++)
        {
            ubyte ch = buffer[i];
            if (ch == HttpControlСhar.cr)
            {
                if (i >= lastIndex || buffer[i + 1] != HttpControlСhar.lf)
                {
                    return DecoderState.errorInvalidHeadersLine;
                }

                if (i > 0 && buffer[i - 1] == HttpControlСhar.lf)
                {
                    //cr -1
                    headersSize = i;
                    headersEolSize = eolSizeof;
                    return DecoderState.ok;
                }
            }
        }

        return DecoderState.errorInvalidHeadersLine;
    }

    string[string] parseHeadersKeyValues()
    {
        string[string] headers;

        onHeader((key, value) {

            if (key in headers)
            {
                return true;
            }

            headers[key.idup] = value.idup;

            return true;
        });

        return headers;
    }

    bool onHeader(scope bool delegate(const(char[]) name, const(char[]) value) onNameValueIsContinue)
    {
        if (state != DecoderState.end && headersLineSlice.length == 0)
        {
            return false;
        }

        import std.string : lineSplitter, indexOf, strip;
        import std.algorithm.searching : countUntil;

        char sep = ':';
        const lineSep = "\r\n";

        const data = cast(char[]) headersLineSlice;

        size_t pos = 0;
        lineLoop: while (pos < data.length)
        {
            auto end = data[pos .. $].indexOf(lineSep);
            if (end == -1)
            {
                break;
            }

            auto line = data[pos .. pos + end];
            pos += end + lineSep.length;

            if (line.length == 0)
            {
                break;
            }

            long sepPos = -1;
            foreach (i, ch; line)
            {
                if (ch == sep)
                {
                    sepPos = i;
                    break;
                }

                if (!isValidHeaderKeyValueChars(ch) && ch != ' ')
                {
                    continue lineLoop;
                }
            }

            if (sepPos == -1)
            {
                continue;
            }

            const key = line[0 .. sepPos].strip;

            const value = line[sepPos + 1 .. $].strip;
            foreach (v; value)
            {
                if (!isValidHeaderKeyValueChars(v))
                {
                    continue lineLoop;
                }
            }

            if (!onNameValueIsContinue(key, value))
            {
                return true;
            }
        }

        return true;
    }

    DecoderState parseProtoVersion(scope const(ubyte)[] buffer, out HttpVersion protoVersion, out size_t protoVersionEolSize)
    {
        enum eolSizeof = cr.sizeof + lf.sizeof;

        if (buffer.length < (HttpVersion.http11.length + eolSizeof))
        {
            return DecoderState.errorInvalidProtoVersionLine;
        }

        auto buffProtoSlice = buffer[0 .. (HttpVersion.http11.length)];

        auto buffProtoEolSlize = buffer[HttpVersion.http11.length .. $];
        if (
            buffProtoEolSlize[0] == cr &&
            buffProtoEolSlize[1] == lf &&
            buffProtoSlice == HttpVersion.http11
            )
        {
            protoVersion = HttpVersion.http11;
            protoVersionEolSize = eolSizeof;
            return DecoderState.ok;
        }

        return DecoderState.errorInvalidProtoVersionLine;
    }

    DecoderState parseUri(scope const(ubyte)[] buffer, out size_t uriSize, out size_t uriSepSize)
    {
        if (buffer.length == 0)
        {
            return DecoderState.errorNoUriLine;
        }

        if (buffer.length > limitUriLength)
        {
            return DecoderState.errorUriLineTooLong;
        }

        size_t uriOffset;
        bool isSpecial;
        char lastSpecialChar;
        foreach (b; buffer)
        {
            if (uriOffset > limitUriLength)
            {
                return DecoderState.errorUriLineTooLong;
            }

            if (!isValidUriChar(b, isStrictUri) && !(b == ' '))
            {
                return DecoderState.errorInvalidCharsInUriLine;
            }

            if (isValidUriSpecialChar(b, isStrictUri))
            {
                if (isSpecial)
                {
                    if (lastSpecialChar == b)
                    {
                        return DecoderState.errorInvalidDupCharsInUriLine;
                    }
                }
                else
                {
                    isSpecial = true;
                    lastSpecialChar = b;
                }
            }
            else
            {
                if (isSpecial)
                {
                    isSpecial = false;
                    lastSpecialChar = 0;
                }
            }

            if (b == HttpControlСhar.space)
            {
                //TODO isSpecial last _-
                uriSize = uriOffset;
                uriSepSize = HttpControlСhar.space.sizeof;
                return DecoderState.ok;
            }

            uriOffset++;
        }

        uriSize = uriOffset;
        uriSepSize = 0;

        if (uriSize > limitUriLength)
        {
            return DecoderState.errorUriLineTooLong;
        }

        return DecoderState.ok;
    }

    DecoderState parseRequestMethod(scope const(ubyte)[] buffer, out size_t requestMethodSize, out size_t requestSepSize)
    {
        if (buffer.length < httpMethodMinSize)
        {
            return DecoderState.errorMethodTooShort;
        }

        size_t offset;
        foreach (b; buffer)
        {
            if (offset > httpMethodMaxSize)
            {
                return DecoderState.errorMethodTooLong;
            }

            if (!isUpperCharOrSpace(b))
            {
                return DecoderState.errorInvalidMethod;
            }

            if (b == HttpControlСhar.space)
            {
                if (offset < httpMethodMinSize)
                {
                    return DecoderState.errorMethodTooShort;
                }

                requestMethodSize = offset;
                requestSepSize = HttpControlСhar.space.sizeof;
                return DecoderState.ok;
            }

            offset++;
        }

        requestMethodSize = offset;
        requestSepSize = 0;

        //an extra check, but useful
        if (requestMethodSize > httpMethodMaxSize)
        {
            return DecoderState.errorMethodTooLong;
        }

        if (requestMethodSize < httpMethodMinSize)
        {
            return DecoderState.errorMethodTooShort;
        }

        return DecoderState.ok;
    }

    bool isValidHeaderKeyValueChars(char c)
    {
        //Content-Disposition: Unicode filename* (RFC 5987).
        //Set-Cookie: ,, ;, "
        if ((c >= 'A' && c <= 'Z') ||
            (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '-' || c == '/')
        {
            return true;
        }

        return false;
    }

    bool isPercentEncodingCharsAfter(char c)
    {
        if ((c >= 'A' && c <= 'F') ||
            (c >= 'a' && c <= 'f') ||
            (c >= '0' && c <= '9'))
        {
            return true;
        }

        return false;
    }

    bool isValidUriSpecialChar(char c, bool isStrict = true)
    {
        //%00 (Null), %0A, %1C
        if (c == '-' || c == '.' || c == '_' || c == '/')
        {
            return true;
        }

        if (isStrict)
        {
            return false;
        }

        // (RFC 3986): :/?#[]@!$&'()*+,;=
        //command injection: ;|`$()<>
        switch (c)
        {
            case ':':
            case '?':
            case '#':
            case '[':
            case ']':
            case '@':
            case '!':
            case '$':
            case '&':
            case '\'':
            case '(':
            case ')':
            case '*':
            case '+':
            case ',':
            case ';':
            case '=':
                return true;
            default:
                break;
        }

        return false;
    }

    bool isValidUriChar(char c, bool isStrict = true)
    {
        //%00 (Null), %0A, %1C
        //(RFC 3986): A-Z, a-z, 0-9, '-', '.', '_', '~'; and '/', '%'
        if (
            (c >= 'A' && c <= 'Z') ||
            (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') ||
            isValidUriSpecialChar(c, isStrict))
        {
            return true;
        }

        return false;
    }

    protected bool isUpperCharOrSpace(char c)
    {
        if ((c >= 'A' && c <= 'Z') || c == ' ')
        {
            return true;
        }

        return false;
    }

    void setUriDefaultLengthLimit()
    {
        limitUriLength = uriMaxSizeBytes;
    }

    void setBodyDefaultLengthLimit()
    {
        limitBodyLength = defaultLimitBodyLength;
    }
}

// unittest
// {
//     auto decoder = new StaticHttpDecoder;

//     ubyte[] request = cast(ubyte[]) "GET /path/to/resource HTTP/1.1\r\nHost: example.com\r\nUser-Agent: MyCustomClient/1.0\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8\r\nConnection: close\r\n\r\n"
//         .dup;

//     decoder.decode(request);
//     assert(decoder.state == DecoderState.end);
//     assert(decoder.httpVersion == HttpVersion.http11);
//     assert(decoder.requestMethodSlice == "GET");
//     assert(decoder.uriSlice == "/path/to/resource");
//     assert(decoder.headersLineSlice == "Host: example.com\r\nUser-Agent: MyCustomClient/1.0\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8\r\nConnection: close\r\n"
//             .dup);
//     assert(decoder.bodySlice.length == 0);
// }

unittest
{
    auto decoder = new StaticHttpDecoder;

    decoder.decode(null);
    assert(decoder.state == DecoderState.errorEmptyRequest);

    ubyte[] onlyMethod = cast(ubyte[]) "GET";
    decoder.decode(onlyMethod);
    assert(decoder.state == DecoderState.errorMethodOnly);

    ubyte[] lowerMethod = cast(ubyte[]) "get";
    decoder.decode(lowerMethod);
    assert(decoder.state == DecoderState.errorInvalidMethod);

    ubyte[] onlyMethod2 = cast(ubyte[]) "GET ";
    decoder.decode(onlyMethod2);
    assert(decoder.state == DecoderState.errorNoUriLine);

    ubyte[] onlyMethod3 = cast(ubyte[]) "GET       ";
    decoder.decode(onlyMethod3);
    assert(decoder.state == DecoderState.errorNoUriLine);

    ubyte[] onlyMethodRn = cast(ubyte[]) "GET\r\n";
    decoder.decode(onlyMethodRn);
    assert(decoder.state == DecoderState.errorInvalidMethod);

    ubyte[] spuff = cast(ubyte[]) "GET\nPOST /";
    decoder.decode(spuff);
    assert(decoder.state == DecoderState.errorInvalidMethod);

    ubyte[] invalidMethod = cast(ubyte[]) "GЦT";
    decoder.decode(invalidMethod);
    assert(decoder.state == DecoderState.errorInvalidMethod);

    ubyte[] tooLongMethod = cast(ubyte[]) "GETGETGETGETGETGETGETGET";
    decoder.decode(tooLongMethod);
    assert(decoder.state == DecoderState.errorMethodTooLong);

    ubyte[] tooLongMethod2 = cast(ubyte[]) "GETGETGETGETGET /helloworld HTTP/1.1";
    decoder.decode(tooLongMethod2);
    assert(decoder.state == DecoderState.errorMethodTooLong);

    ubyte[] tooShortMethod = cast(ubyte[]) "GE";
    decoder.decode(tooShortMethod);
    assert(decoder.state == DecoderState.errorMethodTooShort);
}

unittest
{
    auto decoder = new StaticHttpDecoder;

    decoder.decode(cast(ubyte[]) "GET /");
    assert(decoder.state == DecoderState.errorNoProtoVersion);
    decoder.decode(cast(ubyte[]) "GET / ");
    assert(decoder.state == DecoderState.errorNoProtoVersion);
    decoder.decode(cast(ubyte[]) "GET /    ");
    assert(decoder.state == DecoderState.errorInvalidProtoVersionLine);

    decoder.limitUriLength = 5;
    decoder.decode(cast(ubyte[]) "GET /helloworld");
    assert(decoder.state == DecoderState.errorUriLineTooLong);
    decoder.decode(cast(ubyte[]) "GET /helloworld HTTP/1.1");
    assert(decoder.state == DecoderState.errorUriLineTooLong);
    decoder.setUriDefaultLengthLimit;
    decoder.decode(cast(ubyte[]) "GET /helloworld");
    assert(decoder.state == DecoderState.errorNoProtoVersion);

    decoder.decode(cast(ubyte[]) "GET Ё");
    assert(decoder.state == DecoderState.errorInvalidCharsInUriLine);

    decoder.decode(cast(ubyte[]) "GET /.\n/");
    assert(decoder.state == DecoderState.errorInvalidCharsInUriLine);

    //%2E%2E
    decoder.decode(cast(ubyte[]) "GET /../");
    assert(decoder.state == DecoderState.errorInvalidDupCharsInUriLine);

    decoder.decode(cast(ubyte[]) "GET /%2E%2E/");
    assert(decoder.state == DecoderState.errorInvalidCharsInUriLine);

    decoder.decode(cast(ubyte[]) "GET /cmd--arg/");
    assert(decoder.state == DecoderState.errorInvalidDupCharsInUriLine);

    decoder.decode(cast(ubyte[]) "GET /delete/1/;DROP");
    assert(decoder.state == DecoderState.errorInvalidCharsInUriLine);

    //%2F == / 
    decoder.decode(cast(ubyte[]) "GET /%2F");
    assert(decoder.state == DecoderState.errorInvalidCharsInUriLine);

    decoder.decode(cast(ubyte[]) "GET /\0");
    assert(decoder.state == DecoderState.errorInvalidCharsInUriLine);

    decoder.decode(cast(ubyte[]) "GET /h//h");
    assert(decoder.state == DecoderState.errorInvalidDupCharsInUriLine);
}

unittest
{
    auto decoder = new StaticHttpDecoder;

    decoder.decode(cast(ubyte[]) "GET / HTTP/1.1\r\n\r\n");
    assert(decoder.state == DecoderState.end);

    decoder.decode(cast(ubyte[]) "GET / HTTP/1.1");
    assert(decoder.state == DecoderState.errorInvalidProtoVersionLine);

    decoder.decode(cast(ubyte[]) "GET / HTTP/1.1\r\n");
    assert(decoder.state == DecoderState.errorNoHeadersNoBody);

    decoder.decode(cast(ubyte[]) "GET / HTTP/\n1.1\r\n");
    assert(decoder.state == DecoderState.errorInvalidProtoVersionLine);

    decoder.decode(cast(ubyte[]) "GET / HTTЕ/1.1\r\n");
    assert(decoder.state == DecoderState.errorInvalidProtoVersionLine);
}

unittest
{
    auto decoder = new StaticHttpDecoder;

    decoder.decode(cast(ubyte[]) "GET / HTTP/1.1\r\nHost");
    assert(decoder.state == DecoderState.errorInvalidHeadersLine);

    decoder.decode(cast(ubyte[]) "GET / HTTP/1.1\r\nHost\r\n");
    assert(decoder.state == DecoderState.errorInvalidHeadersLine);

    decoder.decode(cast(ubyte[]) "GET / HTTP/1.1\r\nHost\r\n\r\n");
    assert(decoder.state == DecoderState.end);

    decoder.decode(cast(ubyte[]) "GET / HTTP/1.1\r\nHost\r\n\r\n\r\n");
    assert(decoder.state == DecoderState.end);
    assert(decoder.parseHeadersKeyValues.length == 0);

    decoder.decode(cast(ubyte[]) "GET / HTTP/1.1\r\nHost:\r\n\r\n");
    assert(decoder.state == DecoderState.end);
    assert(decoder.parseHeadersKeyValues == ["Host": ""]);

    decoder.decode(cast(ubyte[]) "GET / HTTP/1.1\r\nHost:name\r\n   XHeader: value\r\n\r\n");
    assert(decoder.state == DecoderState.end);
    assert(decoder.parseHeadersKeyValues == ["Host": "name", "XHeader": "value"]);

    decoder.decode(cast(ubyte[]) "GET / HTTP/1.1\r\nHost:name\r\nXHeader\r\n\r\n");
    assert(decoder.parseHeadersKeyValues == ["Host": "name"]);

    decoder.decode(cast(ubyte[]) "GET / HTTP/1.1\r\nXHeader\r\nHost:name\r\n\r\n");
    assert(decoder.parseHeadersKeyValues == ["Host": "name"]);

    decoder.decode(cast(
            ubyte[]) "GET / HTTP/1.1\r\nHeader1: value1\r\nHea\nder2     :value2\r\n Header3: va\nlue3\r\nHeader4:value4\r\n\r\n");
    assert(decoder.parseHeadersKeyValues == [
        "Header1": "value1",
        "Header4": "value4"
    ]);
}
