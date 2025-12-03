module api.dn.protocols.http1.static_http_resp_decoder;

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

    parseProtoVersionLine = "parseProtoVersionLine",
    parseStatusCodeLine = "parseStatusCodeLine",
    parseReasonPhraseLine = "parseReasonPhraseLine",

    parseHeadersLine = "parseHeadersLine",
    parseBodyLine = "parseBodyLine",

    errorEmpty = "Empty",
    errorInvalidProtoVersionLine = "errorInvalidProtoVersionLine",
    errorProtoVersionMaxLimit = "errorProtoVersionMaxLimit",
    errorOnlyProto = "errorOnlyProto",

    errorNoStatusCode = "errorNoStatusCode",
    errorStatusCodeMaxLimit = "errorStatusCodeMaxLimit",
    errorInvalidStatusCode = "errorInvalidStatusCode",

    errorNoReasonPhrase = "errorNoReasonPhrase",
    errorReasonPhraseMaxLimit = "errorReasonPhraseMaxLimit",
    errorInvalidReasonPhrase = "errorInvalidReasonPhrase",

    errorNoHeaders = "errorNoHeaders",
    errorInvalidHeadersLine = "errorInvalidHeadersLine",
    errorHeaderMaxLimit = "errorHeaderMaxLimit",

    errorNoBody = "errorNoBody",
    errorInvalidBodyLine = "errorInvalidBodyLine",
    errorBodyMaxLimit = "errorBodyMaxLimit"
}

/** 

/**
 * Authors: initkfs
 */
class StaticHttpRespDecoder : Codec
{
    DecoderState state;

    char cr = HttpControlСhar.cr;
    char lf = HttpControlСhar.lf;

    size_t limitBodySizeBytes = size_t.max;
    size_t limitHeadersCount = 20;

    //10-100Mb 
    enum defaultLimitBodyLength = 30 * 1024;
    size_t limitBodyLength = defaultLimitBodyLength;

    HttpVersion httpVersion;
    char[] statusCodeSlice;
    char[] reasonPhraseSlice;

    char[] headersLineSlice;
    ubyte[] bodySlice;

    ubyte[] buffSlice;

    void decode(ubyte[] buff)
    {
        reset;

        if (buff.length == 0)
        {
            state = DecoderState.errorEmpty;
            return;
        }

        buffSlice = buff;

        parseLoop: while (buffSlice.length > 0)
        {
            switch (state) with (DecoderState)
            {
                case none:
                    state = DecoderState.parseProtoVersionLine;

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
                        state = DecoderState.errorOnlyProto;
                        return;
                    }

                    state = DecoderState.parseStatusCodeLine;
                    break;
                case parseStatusCodeLine:
                    size_t statusSize;
                    size_t statusSepSize;
                    state = parseStatusCode(buffSlice, statusSize, statusSepSize);

                    if (state != DecoderState.ok)
                    {
                        return;
                    }

                    if (statusSize == 0)
                    {
                        state = DecoderState.errorNoStatusCode;
                        return;
                    }

                    if (statusSize + statusSepSize > buffSlice.length)
                    {
                        state = DecoderState.errorInvalidStatusCode;
                        return;
                    }

                    statusCodeSlice = cast(char[]) buffSlice[0 .. statusSize];

                    buffSlice = buffSlice[(statusSize + statusSepSize) .. $];

                    state = DecoderState.parseReasonPhraseLine;
                    break;
                case parseReasonPhraseLine:

                    size_t size;
                    size_t sepSize;
                    state = parseReasonPhrase(buffSlice, size, sepSize);

                    if (state != DecoderState.ok)
                    {
                        return;
                    }

                    if (size == 0)
                    {
                        state = DecoderState.errorNoReasonPhrase;
                        return;
                    }

                    if (size + sepSize > buffSlice.length)
                    {
                        state = DecoderState.errorInvalidReasonPhrase;
                        return;
                    }

                    reasonPhraseSlice = cast(char[]) buffSlice[0 .. size];

                    buffSlice = buffSlice[(size + sepSize) .. $];

                    state = DecoderState.parseHeadersLine;
                    break;
                case parseHeadersLine:
                    size_t size;
                    size_t sepSize;
                    state = parseHeaders(buffSlice, size, sepSize);
                    if (state != DecoderState.ok)
                    {
                        return;
                    }

                    if (size == 0)
                    {
                        state = DecoderState.errorNoHeaders;
                        return;
                    }

                    if (size + sepSize > buffSlice.length)
                    {
                        state = DecoderState.errorInvalidHeadersLine;
                        return;
                    }

                    headersLineSlice = cast(char[]) buffSlice[0 .. size];

                    buffSlice = buffSlice[(size + sepSize) .. $];

                    state = DecoderState.parseBodyLine;
                    break;
                case parseBodyLine:
                    size_t size;
                    
                    state = parseBody(buffSlice, size);
                    if (state != DecoderState.ok)
                    {
                        return;
                    }

                    if (size == 0)
                    {
                        state = DecoderState.errorNoBody;
                        return;
                    }

                    if (size > buffSlice.length)
                    {
                        state = DecoderState.errorInvalidBodyLine;
                        return;
                    }

                    bodySlice = buffSlice[0 .. size];
                    state = DecoderState.end;
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

        buffSlice = null;
        statusCodeSlice = null;
        reasonPhraseSlice = null;
        headersLineSlice = null;
        bodySlice = null;
    }

    DecoderState parseProtoVersion(scope const(ubyte)[] buffer, out HttpVersion protoVersion, out size_t protoVersionEolSize)
    {
        const protoEol = ' ';
        protoVersionEolSize = 1;
        const maxLimit = 10;

        size_t count;
        foreach (ch; buffer)
        {
            if (ch == protoEol)
            {
                break;
            }

            if (count >= maxLimit)
            {
                return DecoderState.errorProtoVersionMaxLimit;
            }

            count++;
        }

        auto protoBuff = buffer[0 .. count];

        if (protoBuff == HttpVersion.http11)
        {
            protoVersion = HttpVersion.http11;
        }
        else if (protoBuff == HttpVersion.http2)
        {
            protoVersion = HttpVersion.http2;
        }
        else if (protoBuff == HttpVersion.http3)
        {
            protoVersion = HttpVersion.http3;
        }
        else
        {
            protoVersion = HttpVersion.none;
            return DecoderState.errorInvalidProtoVersionLine;
        }

        return DecoderState.ok;
    }

    DecoderState parseStatusCode(scope const(ubyte)[] buffer, out size_t size, out size_t sepSize)
    {
        const maxLimit = 3;

        const eol = ' ';
        sepSize = 1;

        size_t count;
        foreach (ch; buffer)
        {
            if (ch == eol)
            {
                break;
            }

            if (count >= maxLimit)
            {
                return DecoderState.errorStatusCodeMaxLimit;
            }

            count++;
        }

        size = count;
        return DecoderState.ok;
    }

    DecoderState parseReasonPhrase(scope const(ubyte)[] buffer, out size_t size, out size_t sepSize)
    {
        const maxLimit = 30;

        sepSize = cr.sizeof + lf.sizeof;

        size_t count;
        foreach (ch; buffer)
        {
            if (ch == cr)
            {
                if (count >= buffer.length)
                {
                    return DecoderState.errorReasonPhraseMaxLimit;
                }

                char nextChar = buffer[count + 1];
                if (nextChar == lf)
                {
                    size = count;
                    return DecoderState.ok;
                }
            }

            if (count >= maxLimit)
            {
                return DecoderState.errorReasonPhraseMaxLimit;
            }

            count++;
        }

        return DecoderState.errorInvalidReasonPhrase;
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
                    headersSize = i - 2;
                    headersEolSize = eolSizeof * 2;
                    return DecoderState.ok;
                }
            }
        }

        return DecoderState.errorInvalidHeadersLine;
    }

    DecoderState parseBody(scope const(ubyte)[] buffer, out size_t bodySize)
    {
        size_t offset;
        foreach (b; buffer)
        {
            if (offset >= limitBodyLength)
            {
                return DecoderState.errorBodyMaxLimit;
            }

            offset++;
        }

        bodySize = offset;
        return DecoderState.ok;
    }
}

/*
HTTP/1.1 200 OK 
Server: nginx/1.18.0 (Ubuntu) 
Date: Wed, 03 Dec 2025 12:17:23 GMT 
Content-Type: text/html 
Content-Length: 5124 
*/

unittest
{
    auto decoder = new StaticHttpRespDecoder;

    decoder.decode(null);
    assert(decoder.state == DecoderState.errorEmpty);

    string resp = "HTTP/1.1 200 OK\r\nServer: nginx/1.18.0 (Ubuntu)\r\nDate: Wed, 03 Dec 2025 12:17:23 GMT \r\nContent-Type: text/html\r\nContent-Length: 5124\r\n\r\nBody\0";

    decoder.decode(cast(ubyte[]) resp);
    assert(decoder.httpVersion == HttpVersion.http11);
    assert(decoder.statusCodeSlice == "200");
    assert(decoder.reasonPhraseSlice == "OK");
    assert(decoder.headersLineSlice == "Server: nginx/1.18.0 (Ubuntu)\r\nDate: Wed, 03 Dec 2025 12:17:23 GMT \r\nContent-Type: text/html\r\nContent-Length: 5124");
    assert(decoder.bodySlice == "Body");
    assert(decoder.state == DecoderState.end);
}
