module api.dn.protocols.http1.static_http_decoder;

import api.dn.codecs.codec : Codec;
import api.core.mem.buffers.static_buffer : StaticBuffer;

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
    errorInvalidUriLine = "Error. Invalid URI line",
    errorInvalidHeadersLine = "Error. Invalid headers line",
    errorInvalidBodyLine = "Error. Invalid body line",
    errorInvalidProtoVersionLine = "Error. Invalid protocol version",
    errorInvalidMessage = "Error. Invalid message",
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

    char[] requestMethodSlice;
    char[] uriSlice;
    char[] protoVersionSlice;
    char[] headersLineSlice;
    ubyte[] bodySlice;

    HttpVersion httpVersion;

    //StaticBuffer!(StompHeader!(char, 256, 256), 20, false) headers;

    void decode(ubyte[] buff)
    {
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

                    if (requestMethodSize == 0 || requestSepSize == 0 || (
                            (requestMethodSize + requestSepSize) >= buffSlice.length))
                    {
                        state = DecoderState.errorInvalidMethod;
                        return;
                    }

                    //TODO validateMethods;
                    requestMethodSlice = cast(char[]) buffSlice[0 .. requestMethodSize];

                    buffSlice = buffSlice[(requestMethodSize + requestSepSize) .. $];

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

                    if (uriSize == 0 || uriSize > uriMaxSizeBytes || uriSepSize == 0 || (
                            uriSize + uriSepSize >= buffSlice.length))
                    {
                        state = DecoderState.errorInvalidUriLine;
                        return;
                    }

                    uriSlice = cast(char[]) buffSlice[0 .. uriSize];

                    buffSlice = buffSlice[(uriSize + uriSepSize) .. $];

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

                    if (versionEolSize == 0 || (
                            buffSlice.length <= mustBeHttpVersion.length + versionEolSize))
                    {
                        state = DecoderState.errorInvalidProtoVersionLine;
                        return;
                    }

                    httpVersion = mustBeHttpVersion;

                    buffSlice = buffSlice[(mustBeHttpVersion.length + versionEolSize) .. $];

                    if (buffSlice.length < 2)
                    {
                        state = DecoderState.errorInvalidMessage;
                        return;
                    }

                    if (buffSlice[0] == HttpControlСhar.cr && buffSlice[1] == HttpControlСhar.lf)
                    {
                        state = DecoderState.parseBodyLine;
                        continue;
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
                    if(state != DecoderState.ok){
                        return;
                    }
                    if(bodySize == 0){
                        state = DecoderState.errorInvalidBodyLine;
                    }

                    bodySlice = buffSlice[0.. bodySize];

                    state = DecoderState.end;
                    return;
                    
                    break;
                default:
                    break parseLoop;
            }
        }
    }

    DecoderState parseBody(scope const(ubyte)[] buffer, out size_t bodySize)
    {
        size_t offset;
        foreach (b; buffer)
        {
            if (b == HttpControlСhar.nul)
            {
                bodySize = offset;
                return DecoderState.ok;
            }

            offset++;
        }

        return DecoderState.errorInvalidBodyLine;
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
                if (i > 0 && buffer[i - 1] == HttpControlСhar.lf && i < lastIndex && buffer[i + 1] == HttpControlСhar
                    .lf)
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
        if (buffer.length == 0 || buffer.length > uriMaxSizeBytes)
        {
            return DecoderState.errorInvalidUriLine;
        }

        size_t uriOffset;
        foreach (b; buffer)
        {
            if (uriOffset > uriMaxSizeBytes)
            {
                return DecoderState.errorInvalidUriLine;
            }

            if (b == HttpControlСhar.space)
            {
                uriSize = uriOffset;
                uriSepSize = HttpControlСhar.space.sizeof;
                return DecoderState.ok;
            }

            uriOffset++;
        }

        return DecoderState.errorInvalidUriLine;
    }

    DecoderState parseRequestMethod(scope const(ubyte)[] buffer, out size_t requestMethodSize, out size_t requestSepSize)
    {
        if (buffer.length < httpMethodMinSize)
        {
            return DecoderState.errorInvalidMethod;
        }

        size_t offset;
        foreach (b; buffer)
        {
            if (offset > httpMethodMaxSize)
            {
                return DecoderState.errorInvalidMethod;
            }

            if (b == HttpControlСhar.space)
            {
                requestMethodSize = offset;
                requestSepSize = HttpControlСhar.space.sizeof;
                return DecoderState.ok;
            }

            offset++;
        }

        return DecoderState.errorInvalidMethod;
    }
}
