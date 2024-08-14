module app.dn.protocols.stomp.stomp_common;

import app.core.mem.buffers.static_buffer : StaticBuffer;

import std.typecons : Nullable;

/**
 * Authors: initkfs
 */
enum StompControlСhar : byte
{
    //10
    lf = '\n',
    //13
    cr = '\r',
    //0
    nul = 0,
    //58
    colon = ':',
}

enum StompCommand : string
{
    //client
    SEND = "SEND",
    SUBSCRIBE = "SUBSCRIBE",
    UNSUBSCRIBE = "UNSUBSCRIBE",
    BEGIN = "BEGIN",
    CONNECT = "CONNECT",
    COMMIT = "COMMIT",
    ABORT = "ABORT",
    ACK = "ACK",
    NACK = "NACK",
    DISCONNECT = "DISCONNECT",
    STOMP = "STOMP",

    //server
    CONNECTED = "CONNECTED",
    MESSAGE = "MESSAGE",
    RECEIPT = "RECEIPT",
    ERROR = "ERROR"
}

enum StompVersion
{
    current = "1.2"
}

enum StompDefaultHeader : string
{
    contentLength = "content-length",
    contentType = "content-type",
    receipt = "receipt",
    receiptID = "receipt-id",
    ver = "version",
    destination = "destination",
    subscription = "subscription",
    id = "id",
    transaction = "transaction",
    messageID = "message-id"
}

enum StompBufferLength = 256;

struct StompHeader(T,
    size_t NameLength = StompBufferLength,
    size_t ValueLength = StompBufferLength)
{
    StaticBuffer!(T, NameLength) name;
    StaticBuffer!(T, ValueLength) value;
}

struct StompFrame(
    size_t HeadersCount = 10,
    size_t HeaderNameLen = StompBufferLength,
    size_t HeaderValueLen = StompBufferLength,
    size_t BodyLength = StompBufferLength
)
{
    StompCommand command;
    StaticBuffer!(StompHeader!(char, StompBufferLength, StompBufferLength), 20, false) headers;
    StaticBuffer!(ubyte, BodyLength) content;
}
