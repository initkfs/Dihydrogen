module api.dn.protocols.http1.parameters;

/**
 * Authors: initkfs
 * https://www.iana.org/assignments/http-parameters/http-parameters.xhtml
 */

immutable:

//HTTP Content Coding Registry

struct ContentCoding
{
immutable:
    string aes128gcm = "aes128gcm"; //	AES-GCM encryption with a 128-bit content encryption key
    string br = "br"; // Brotli Compressed Data Format
    string compress = "compress"; //UNIX "compress" data format
    string dcb = "dcb"; // "Dictionary-Compressed Brotli" data format.
    string dcz = "dcz"; // "Dictionary-Compressed Zstandard" data format.
    string deflate = "deflate"; //	"deflate" compressed data ([RFC1951]) inside the "zlib" data format ([RFC1950])
    string exi = "exi"; // W3C Efficient XML Interchange
    string gzip = "gzip"; // GZIP file format [RFC1952]
    string identity = "identity"; // Reserved
    string pack200_gzip = "pack200-gzip"; // Network Transfer Format for Java Archives
    string zstd = "zstd"; // A stream of bytes compressed using the Zstandard protocol with a Window_Size of not more than 8 MB.
}

//HTTP Transfer Coding Registry

struct TransferCoding
{
immutable:
    string chunked = "chunked"; //	Transfer in a series of chunks	[RFC9112]	Section 7.1
    string compress = "compress"; // UNIX "compress" data format [Welch, T., "A Technique for High Performance Data Compression", IEEE Computer 17(6), June 1984.]	[RFC9112]	Section 7.2
    string deflate = "deflate"; //	"deflate" compressed data ([RFC1951]) inside the "zlib" data format ([RFC1950])	[RFC9112]	Section 7.2
    string gzip = "gzip"; //GZIP file format [RFC1952]	[RFC9112]	Section 7.2
    string identity = "identity"; //(withdrawn in errata to [RFC2616])	[RFC2616]	Section 3.6
    string trailers = "trailers"; //	(reserved)	[RFC9112]	Section 12.3
}

//HTTP Forwarded Parameters
struct ForwardedParameters
{
immutable:
    string by = "by"; //	IP-address of incoming interface of a proxy	[RFC7239]	Section 5.1
    string _for = "for"; //	IP-address of client making a request through a proxy	[RFC7239]	Section 5.2
    string host = "host"; //	Host header field of the incoming request	[RFC7239]	Section 5.3
    string proto = "proto"; //	Application protocol used for incoming request
}

//HTTP Preferences
struct Preferences
{
immutable:
    string respond_async = "respond-async"; //		Indicates that the client prefers that the server respond asynchronously to a request.

    string _return = "return"; //	One of either "minimal" or "representation"	When the value is "minimal", it indicates that the client prefers that the server return a minimal response to a request. When the value is "representation", it indicates that the client prefers that the server include a representation of the current state of the resource in response to a request.

    string wait = "wait"; //		Indicates an upper bound to the length of time the       client expects it will take the server to process the request once       it has been received.

    string handling = "handling"; //	One of either "strict" or "lenient"	When value is "strict", it indicates that the client wishes the server to apply strict validation and error handling to the processing of a request. When the value is "lenient", it indicates that the client wishes the server to apply lenient validation and error handling to the processing of the request.

    string depth_noroot = "depth-noroot"; //		The "depth-noroot" preference indicates that the client wishes for the server to exclude the target (root) resource from processing by the HTTP method and only apply the HTTP method to the target resource's subordinate resources. This preference is only intended to be used with HTTP methods whose definitions explicitly provide support for the Depth [RFC4918] header field. Furthermore, this preference only applies when the Depth header field has a value of "1" or "infinity" (either implicitly or explicitly).

    string safe = "safe"; //		Indicates that safe (i.e., unobjectionable) content is preferred.

    string odata_allow_entityreferences = "odata.allow-entityreferences"; //		Indicates that the service is allowed to return references in place of         resources that have previously been returned, with at least the properties         requested, in the same response.

    string odata_callback = "odata.callback"; //		Requests that the service invoke the specified URL to signal some service         state, such as the completion of an asynchronous result or availability of         new or modified information. The service state that triggers the change is         dependent upon the request.

    string odata_continue_on_error = "odata.continue-on-error"; //		Requests that the service attempt to continue processing a request that         encounters non-fatal errors, for example in a multi-part request. The         response SHOULD indicate what portions of the request were and were not         able to be successfully handled.

    string odata_include_annotations = "odata.include-annotations"; //	Comma-separated list of terms to include or, when prefixed with a minus         sign (-), exclude from the response. Terms MUST be namespace-qualified and         MAY specify just a namespace to include or exclude all terms within that         namespace. The special value "*" matches all annotations.	Specifies the set of annotations the client requests to be included, where         applicable, or excluded in the response.

    string odata_maxpagesize = "odata.maxpagesize"; //	A positive integer that represents the maximum number of items each         collection in a response SHOULD contain.	Requests that each collection within the response contain no more than the         number of items specified as the positive integer value of this preference.

    string omit_values = "omit-values"; //	One of nulls -  properties containing null values may be omitted from the         response defaults - properties containing the property default value may be         omitted from the response.	Specifies whether a server can omit properties with a null value or         properties set to their default value from a response.

    string odata_track_changes = "odata.track-changes"; //		Requests that the service initiate change tracking on the result of this         request, according to the underlying protocol.

}

//HTTP Range Unit Registry

struct RangeUnit
{
immutable:
    string bytes = "bytes"; //	a range of octets
    string none = "none"; //reserved as keyword to indicate range requests are not supported
}
