module api.dn.protos.http1.status;

/**
 * Authors: initkfs
 */

struct StatusInfo
{
    int code;
    string message;
}

/** 
    1xx: Informational - Request received, continuing process
    2xx: Success - The action was successfully received, understood, and accepted
    3xx: Redirection - Further action must be taken in order to complete the request
    4xx: Client Error - The request contains bad syntax or cannot be fulfilled
    5xx: Server Error - The server failed to fulfill an apparently valid request
 */

enum
{
    //Informational
    _101 = StatusInfo(101, "Switching Protocols"),
    _102 = StatusInfo(102, "Processing"),
    _103 = StatusInfo(103, "Early Hints"),
    //_104 = StatusInfo(104, "Upload Resumption Supported (TEMPORARY - registered 2024-11-13"),

    //Success
    _200 = StatusInfo(200, "OK"),
    _201 = StatusInfo(201, "Created"),
    _202 = StatusInfo(202, "Accepted"),
    _203 = StatusInfo(203, "Non-Authoritative Information"),
    _204 = StatusInfo(204, "No Content"),
    _205 = StatusInfo(205, "Reset Content"),
    _206 = StatusInfo(206, "Partial Content"),
    _207 = StatusInfo(207, "Multi-Status"),
    _208 = StatusInfo(208, "Already Reported"),
    _226 = StatusInfo(226, "IM Used"),

    //Redirection
    _300 = StatusInfo(300, "Multiple Choices"),
    _301 = StatusInfo(301, "Moved Permanently"),
    _302 = StatusInfo(302, "Found"),
    _303 = StatusInfo(303, "See Other"),
    _304 = StatusInfo(304, "Not Modified"),
    _305 = StatusInfo(305, "Use Proxy"),
    _307 = StatusInfo(307, "Temporary Redirect"),
    _308 = StatusInfo(308, "Permanent Redirect"),

    //Client Error
    _400 = StatusInfo(400, "Bad Request"),
    _401 = StatusInfo(401, "Unauthorized"),
    _402 = StatusInfo(402, "Payment Required"),
    _403 = StatusInfo(403, "Forbidden"),
    _404 = StatusInfo(404, "Not Found"),
    _405 = StatusInfo(405, "Method Not Allowed"),
    _406 = StatusInfo(406, "Not Acceptable"),
    _407 = StatusInfo(407, "Proxy Authentication Required"),
    _408 = StatusInfo(408, "Request Timeout"),
    _409 = StatusInfo(409, "Conflict"),
    _410 = StatusInfo(410, "Gone"),
    _411 = StatusInfo(411, "Length Required"),
    _412 = StatusInfo(412, "Precondition Failed"),
    _413 = StatusInfo(413, "Content Too Large"),
    _414 = StatusInfo(414, "URI Too Long"),
    _415 = StatusInfo(415, "Unsupported Media Type"),
    _416 = StatusInfo(416, "Range Not Satisfiable"),
    _417 = StatusInfo(417, "Expectation Failed"),
    _421 = StatusInfo(421, "Misdirected Request"),
    _422 = StatusInfo(422, "Unprocessable Content"),
    _423 = StatusInfo(423, "Locked"),
    _424 = StatusInfo(424, "Failed Dependency"),
    _425 = StatusInfo(425, "Too Early"),
    _426 = StatusInfo(426, "Upgrade Required"),
    _428 = StatusInfo(428, "Precondition Required"),
    _429 = StatusInfo(429, "Too Many Requests"),
    _431 = StatusInfo(431, "Request Header Fields Too Large"),
    _451 = StatusInfo(451, "Unavailable For Legal Reasons"),

    //Server Error
    _500 = StatusInfo(500, "Internal Server Error"),
    _501 = StatusInfo(501, "Not Implemented"),
    _502 = StatusInfo(502, "Bad Gateway"),
    _503 = StatusInfo(503, "Service Unavailable"),
    _504 = StatusInfo(504, "Gateway Timeout"),
    _505 = StatusInfo(505, "HTTP Version Not Supported"),
    _506 = StatusInfo(506, "Variant Also Negotiates"),
    _507 = StatusInfo(507, "Insufficient Storage"),
    _508 = StatusInfo(508, "Loop Detected"),
    _511 = StatusInfo(511, "Network Authentication Required")
}
