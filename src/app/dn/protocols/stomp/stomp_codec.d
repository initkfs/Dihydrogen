module app.dn.protocols.stomp.stomp_codec;

import app.core.mem.static_buffer : StaticBuffer;

/**
 * Authors: initkfs
 */
enum StompControlСhars : byte
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

enum StompVersions
{
    current = "1.2"
}

enum StompDefaultHeaders : string
{
    contentLength = "content-length",
    contentType = "content-type",
    receipt = "receipt",
    receiptID = "receipt-id",
    ver = "version",
    destination = "destination",
    id = "id",
    transaction = "transaction",
    messageID = "message-id"
}

struct StompHeader(T, size_t NameSize, size_t ValueSize)
{
    StaticBuffer!(T, NameSize) name;
    StaticBuffer!(T, ValueSize) value;
}

struct StompHeaders(T, size_t HeadersCount, size_t NameSize, size_t ValueSize)
{
    StaticBuffer!(StompHeader!(T, NameSize, ValueSize), HeadersCount, false) headers;
}