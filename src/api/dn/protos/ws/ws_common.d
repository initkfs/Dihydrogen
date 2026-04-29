module api.dn.protos.ws.ws_common;

/*
 * Authors: initkfs
 */

//RFC 6455
immutable
{
    string guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    string headerSecWebSocketVersion = "Sec-WebSocket-Version";
    string headerSecWebSocketKey = "Sec-WebSocket-Key";
    string headerSecWebSocketExtensions = "Sec-WebSocket-Extensions";
}

enum secWebSocketKeyLength = 24;

/*
GET /chat HTTP/1.1
Host: server.example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: key1
Origin: http://example.com
Sec-WebSocket-Protocol: chat, superchat
Sec-WebSocket-Version: 13

HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: key2
Sec-WebSocket-Protocol: chat
*/
