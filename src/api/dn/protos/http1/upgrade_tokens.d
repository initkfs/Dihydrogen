module api.dn.protos.http1.upgrade_tokens;

/**
 * Authors: initkfs
 */

//https://www.iana.org/assignments/http-upgrade-tokens/http-upgrade-tokens.xhtml

struct UpgradeToken
{
    string value;
    string message;
}

enum
{
    HTTP = UpgradeToken("HTTP", "Hypertext Transfer Protocol"),
    TLS = UpgradeToken("TLS", "Transport Layer Security	"),
    WebSocket = UpgradeToken("WebSocket", "The Web Socket Protocol"),
    websocket = UpgradeToken("websocket", "The Web Socket Protocol	"),
    connect_udp = UpgradeToken("connect-udp", "Proxying of UDP Payloads"),
    connect_ip = UpgradeToken("connect-ip", "Proxying of IP Payloads"),
}
