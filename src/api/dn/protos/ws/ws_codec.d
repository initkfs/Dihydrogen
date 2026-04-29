module api.dn.protos.ws.ws_codec;

import std.bitmanip;
import std.conv;
import std.string;
import std.exception;

/*
 * Authors: initkfs
 */
enum OpCode : ubyte
{
    CONTINUATION = 0x0,
    TEXT = 0x1,
    BINARY = 0x2,

    //<= 125 payload, not fragmentation
    CLOSE = 0x8,
    PING = 0x9,
    PONG = 0xA
}

struct WebSocketFrame
{
    bool fin;
    ubyte[3] rsv;
    OpCode opcode;
    bool masked;
    ulong payloadLength;
    ubyte[4] maskingKey;
    ubyte[] payload;

    bool isControlFrame() const
    {
        return opcode == OpCode.CLOSE ||
            opcode == OpCode.PING ||
            opcode == OpCode.PONG;
    }
}

WebSocketFrame decode(ubyte[] data)
{
    if (data.length < 2)
    {
        throw new Exception("Invalid length");
    }

    // first byte (FIN, RSV, opcode)
    ubyte firstByte = data[0];
    bool fin = (firstByte & 0x80) != 0;
    ubyte[3] rsv = [
        cast(ubyte)((firstByte & 0x40) != 0 ? 1 : 0),
        cast(ubyte)((firstByte & 0x20) != 0 ? 1 : 0),
        cast(ubyte)((firstByte & 0x10) != 0 ? 1 : 0)
    ];

    //rsv[0]\RSV1 permessage-deflate, RFC 7692
    if (rsv[0] != 0 || rsv[1] != 0 || rsv[2] != 0)
    {
        throw new Error("RSV bits must be 0");
    }

    auto opcode = cast(OpCode)(firstByte & 0x0F);

    ubyte secondByte = data[1];

    bool masked = (secondByte & 0x80) != 0;
    ulong payloadLength = secondByte & 0x7F;

    if (payloadLength > 127)
    {
        throw new Error("Invalid payload length");
    }

    size_t offset = 2;

    if (payloadLength == 126)
    {
        if (data.length < offset + 2)
        {
            throw new Error("Not enough data for 16-bit length");
        }

        payloadLength = bigEndianToNative!ushort(data[offset .. offset + 2][0 .. 2]);
        offset += 2;
    }
    else if (payloadLength == 127)
    {
        if (data.length < offset + 8)
        {
            throw new Error(
                "Not enough data for 64-bit length");
        }
        payloadLength = bigEndianToNative!ulong(data[offset .. offset + 8][0 .. 8]);
        offset += 8;
    }

    if (opcode == OpCode.CLOSE || opcode == OpCode.PING || opcode == OpCode.PONG)
    {
        if (payloadLength > 125)
        {
            throw new Error(
                "The control frame is too large.");
        }
        if (!fin)
        {
            throw new Error(
                "Control frames cannot be fragmented.");
        }
    }

    ubyte[4] maskingKey;
    if (masked)
    {
        if (data.length < offset + 4)
        {
            throw new Error(
                "Insufficient data for masking key");
        }
        maskingKey[] = data[offset .. offset + 4];
        offset += 4;
    }

    if (data.length < offset + payloadLength)
    {
        throw new Error("Not enough data for payload");
    }

    ubyte[] payload = data[offset .. offset + payloadLength].dup;
    if (masked)
    {
        unmaskPayload(payload, maskingKey);
    }

    return WebSocketFrame(fin, rsv, opcode, masked, payloadLength,
        maskingKey, payload);
}

private size_t calculateFrameSize(ubyte[] header)
{
    if (header.length < 2)
        return 0;

    size_t size = 2;
    ubyte payloadLen = header[1] & 0x7F;
    bool masked = (header[1] & 0x80) != 0;

    if (payloadLen == 126)
    {
        size += 2;
    }
    else if (payloadLen == 127)
    {
        size += 8;
    }

    if (masked)
    {
        size += 4;
    }

    ulong actualPayloadLen = payloadLen;
    if (payloadLen == 126 && header.length >= 4)
    {
        actualPayloadLen = bigEndianToNative!ushort(header[2 .. 4][0 .. 2]);
    }
    else if (payloadLen == 127 && header.length >= 10)
    {
        actualPayloadLen = bigEndianToNative!ulong(header[2 .. 10][0 .. 8]);
    }

    return size + actualPayloadLen;
}

private void unmaskPayload(ubyte[] payload, ubyte[4] maskingKey)
{
    foreach (i, ref b; payload)
    {
        b ^= maskingKey[i % 4];
    }
}

WebSocketFrame createCloseFrame(ushort code, string reason = "")
{
    ubyte[] payload;
    if (code != 0)
    {
        payload ~= nativeToBigEndian(code);
        payload ~= cast(ubyte[]) reason.representation;
    }

    return WebSocketFrame(
        true, // fin
        [0, 0, 0], // rsv
        OpCode.CLOSE, // opcode
        false, // masked
        payload.length,
        [0, 0, 0, 0], // maskingKey
        payload
    );
}

WebSocketFrame createPingFrame(ubyte[] data = null)
{
    return WebSocketFrame(
        true,
        [0, 0, 0],
        OpCode.PING,
        false,
        data.length,
        [0, 0, 0, 0],
        data
    );
}

WebSocketFrame createTextFrame(string text)
{
    ubyte[] payload = cast(ubyte[]) text.representation;

    return WebSocketFrame(
        true, // FIN
        [0, 0, 0], // RSV 0
        OpCode.TEXT, // opcode = 1
        false, // non masked on server
        payload.length,
        [0, 0, 0, 0], // maskingKey
        payload
    );
}

ubyte[] encode(WebSocketFrame frame)
{
    if (frame.masked)
    {
        throw new Exception(
            "The server does not mask messages."
        );
    }

    size_t headerSize = 2;

    if (frame.payloadLength >= 126)
    {
        headerSize += (frame.payloadLength <= 0xFFFF) ? 2 : 8;
    }

    ubyte[] result = new ubyte[](headerSize + frame.payloadLength);
    size_t pos = 0;

    ubyte b0 = 0;
    // FIN ( 7)
    if (frame.fin)
        b0 |= 0x80;

    if (frame.rsv[0] != 0)
        b0 |= 0x40; // RSV1
    if (frame.rsv[1] != 0)
        b0 |= 0x20; // RSV2
    if (frame.rsv[2] != 0)
        b0 |= 0x10; // RSV3

    b0 |= cast(ubyte) frame.opcode & 0x0F;

    result[pos++] = b0;

    ubyte b1 = 0;
    if (frame.payloadLength < 126)
    {
        b1 |= cast(ubyte) frame.payloadLength & 0x7F;
        result[pos++] = b1;
    }
    else if (frame.payloadLength <= 0xFFFF)
    {
        b1 |= 126;
        result[pos++] = b1;

        ushort uLen = cast(ushort) frame.payloadLength;
        ushort len16 = (*(cast(ushort*)nativeToBigEndian!ushort(uLen)));
        result[pos .. pos + 2] = (cast(ubyte*)&len16)[0 .. 2];
        pos += 2;
    }
    else
    {
        b1 |= 127;
        result[pos++] = b1;

        ulong len64 = (*(cast(ushort*)nativeToBigEndian!ulong(frame.payloadLength)));
        result[pos .. pos + 8] = (cast(ubyte*)&len64)[0 .. 8];
        pos += 8;
    }

    result[pos .. pos + frame.payloadLength] = frame.payload[];
    return result;
}
