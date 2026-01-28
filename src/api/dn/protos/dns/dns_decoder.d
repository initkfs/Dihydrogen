module api.dn.protos.dns.dns_decoder;

import api.dn.protos.dns.dns_common;

import core.sys.posix.arpa.inet;
import core.sys.posix.netinet.in_;

import std;
/**
 * Authors: initkfs
 */

/** 
 *  +---------------------+
    |        Header       |
    +---------------------+
    |       Question      |
    +---------------------+
    |        Answer       |
    +---------------------+
    |      Authority      |
    +---------------------+
    |      Additional     |
    +---------------------+
 */
struct DNSHeader
{
    ushort id;
    ushort flags;
    ushort questions;
    ushort answers;
    ushort authority;
    ushort additional;
}

static assert(DNSHeader.sizeof == headerSize);

struct DNSAnswer
{
    string name;
    ushort type;
    ushort class_;
    uint ttl;

    //RDATA
    ubyte[] data;

    string ip; // A records
}

//TODO check array overflow
DNSAnswer[] decode(ubyte[] response)
{
    DNSAnswer[] answers;
    
    if (response.length < headerSize)
    {
        return answers;
    }
    
    DNSHeader header;

    //or ushort value = (hi << 8) | lo;
    header.id = ntohs(*(cast(ushort*)&response[0]));
    header.flags = ntohs(*(cast(ushort*)&response[2]));
    header.questions = ntohs(*(cast(ushort*)&response[4]));
    header.answers = ntohs(*(cast(ushort*)&response[6]));
    header.authority = ntohs(*(cast(ushort*)&response[8]));
    header.additional = ntohs(*(cast(ushort*)&response[10]));

    // skip questions
    size_t pos = headerSize;
    
    while (pos < response.length && response[pos] != 0)
    {
        ubyte len = response[pos];
        pos += len + 1;
    }

    pos += 5; // null byte + QTYPE + QCLASS
    
    for (int i = 0; i < header.answers && pos < response.length; i++)
    {        
        string name;
        //pointer
        if ((response[pos] & 0xC0) == 0xC0)
        {
            ushort pointer = ((response[pos] & 0x3F) << 8) | response[pos + 1];
            pos += 2;
            name = decodeName(response, pointer);
        }
        else // sequence
        {
            name = decodeName(response, pos);
            while (pos < response.length && response[pos] != 0)
            {
                ubyte len = response[pos];
                pos += len + 1;
            }
            pos++;
        }
        
        ushort type = (response[pos] << 8) | response[pos + 1];
        pos += 2;
        
        ushort class_ = (response[pos] << 8) | response[pos + 1];
        pos += 2;
        
        // TTL
        uint ttl = (response[pos] << 24) | (response[pos + 1] << 16) | 
                   (response[pos + 2] << 8) | response[pos + 3];
        pos += 4;
        
        ushort rdlength = (response[pos] << 8) | response[pos + 1];
        pos += 2;
        
        ubyte[] data = response[pos..pos + rdlength];
        pos += rdlength;
        
        string ip = "";
        if (type == 1 && rdlength == 4) // A
        {
            ip = format("%d.%d.%d.%d", data[0], data[1], data[2], data[3]);
        }
        else if (type == 28 && rdlength == 16) // AAAA (IPv6)
        {
            ip = decodeIPv6(data);
        }
        
        auto answer = DNSAnswer(name, type, class_, ttl, data, ip);
        answers ~= answer;
    }
    
    return answers;
}

string decodeName(ubyte[] response, size_t start)
{
    Appender!string name;
    size_t pos = start;
    bool isPointer = false;
    
    while (pos < response.length && response[pos] != 0)
    {
        if ((response[pos] & 0xC0) == 0xC0) // pointer
        {
            if (!isPointer)
            {
                isPointer = true;
                start = pos;
            }
            ushort pointer = ((response[pos] & 0x3F) << 8) | response[pos + 1];
            pos = pointer;
        }
        else
        {
            ubyte len = response[pos++];
            if (pos + len > response.length) break;
            
            if (name.data.length > 0) name.put(".");
            foreach (j; 0..len)
            {
                name.put(cast(char)response[pos++]);
            }
        }
    }
    
    return name.data;
}

string typeToString(ushort type)
{
    switch (type)
    {
        case 1: return "A (IPv4)";
        case 2: return "NS";
        case 5: return "CNAME";
        case 6: return "SOA";
        case 12: return "PTR";
        case 15: return "MX";
        case 16: return "TXT";
        case 28: return "AAAA (IPv6)";
        default: return "Unknown";
    }
}

string classToString(ushort class_)
{
    switch (class_)
    {
        case 1: return "IN (Internet)";
        case 3: return "CH (Chaos)";
        case 4: return "HS (Hesiod)";
        default: return format("0x%04X", class_);
    }
}

string decodeIPv6(ubyte[] data)
{
    char[40] buf;
    import core.stdc.stdio : sprintf;
    sprintf(buf.ptr, "%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x",
        data[0], data[1], data[2], data[3],
        data[4], data[5], data[6], data[7],
        data[8], data[9], data[10], data[11],
        data[12], data[13], data[14], data[15]);
    return buf.idup;
}

unittest {
    /** 
     * 
; <<>> DiG 9.18.39-0ubuntu0.22.04.2-Ubuntu <<>> wikipedia.org
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 6067
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 65494
;; QUESTION SECTION:
;wikipedia.org.			IN	A

;; ANSWER SECTION:
wikipedia.org.		19	IN	A	185.15.59.224

     */
    ubyte[] response = [
       18, 52, 129, 128, 0, 1, 0, 1, 0, 0, 0, 0, 9, 119, 105, 107, 105, 112, 101, 100, 105, 97, 3, 111, 114, 103, 0, 0, 1, 0, 1, 192, 12, 0, 1, 0, 1, 0, 0, 0, 49, 0, 4, 185, 15, 59, 224
    ];

    auto answers = decode(response);
    assert(answers.length == 1);

    DNSAnswer answer = answers[0];
    assert(answer.ip == "185.15.59.224");
    assert(answer.name == "wikipedia.org");
}

