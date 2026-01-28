module api.dn.protos.sntp.sntp_codec;

import std.stdio;
import std.datetime;
import std.socket;
import std.conv;
import core.stdc.stdint;

/**
 * Authors: initkfs
 */
struct NtpTimestamp
{
    uint seconds;
    uint fraction;

    double toDouble()
    {
        // seconds since 1900-01-01
        return seconds + (fraction / 4294967296.0);
    }

    static NtpTimestamp fromSystemTime()
    {
        auto now = Clock.currTime();
        // NTP epoch: 1900-01-01, D epoch: 1970-01-01
        // 70 years + 17 leap days = 2208988800 seconds
        const uint64_t ntpEpochOffset = 2208988800UL;

        auto sinceUnixEpoch = (now.stdTime) / 1_000_000.0;
        auto ntpSeconds = cast(uint)(sinceUnixEpoch + ntpEpochOffset);
        auto fraction = cast(uint)((sinceUnixEpoch - cast(uint) sinceUnixEpoch) * 4294967296.0);

        return NtpTimestamp(ntpSeconds, fraction);
    }
}

struct SntpPacket
{
    private ubyte firstByte; // LI (2 bits), VN (3 bits), Mode (3 bits)
    public ubyte stratum; // Stratum level (0=unspecified, 1=primary, 2+=secondary)
    public ubyte poll; // Poll interval (as power of 2 seconds)
    public ubyte precision; // Clock precision (as power of 2 seconds)

    public uint rootDelay; // Total round-trip delay (NTP short format)
    public uint rootDispersion; // Maximum error (NTP short format)
    public uint referenceId; // Reference source identifier

    public NtpTimestamp referenceTimestamp; // Last clock update time
    public NtpTimestamp originateTimestamp; // Time request sent by client (T1)
    public NtpTimestamp receiveTimestamp; // Time request received by server (T2)
    public NtpTimestamp transmitTimestamp; // Time response sent by server (T3)

    // Leap Indicator (bits 7-6): 0=no warning, 1=61s, 2=59s, 3=unknown
    ubyte leapIndicator() const => (firstByte >> 6) & 0x03;
    void leapIndicator(ubyte value)
    {
        firstByte = (firstByte & 0x3F) | ((value & 0x03) << 6);
    }

    // Version Number (bits 5-3): Typically 3 (NTPv3) or 4 (NTPv4)
    ubyte versionNumber() const => (firstByte >> 3) & 0x07;

    void versionNumber(ubyte value)
    {
        firstByte = (firstByte & 0xC7) | ((value & 0x07) << 3);
    }

    // Mode (bits 2-0): 1=symmetric active, 2=symmetric passive, 
    //                  3=client, 4=server, 5=broadcast, 6=control, 7=private
    ubyte mode() const => firstByte & 0x07;

    void mode(ubyte value)
    {
        firstByte = (firstByte & 0xF8) | (value & 0x07);
    }

    ubyte getFirstByte() const => firstByte;

    void setFirstByte(ubyte value)
    {
        firstByte = value;
    }

    private static uint toNetworkByteOrder(uint value)
    {
        version (LittleEndian)
        {
            import core.bitop : bswap;

            return bswap(value);
        }
        else version (BigEndian)
        {
            return value;
        }
    }

    private static uint fromNetworkByteOrder(uint value)
    {
        version (LittleEndian)
        {
            import core.bitop : bswap;

            return bswap(value);
        }
        else version (BigEndian)
        {
            return value;
        }
    }

    private static void packTimestamp(ref ubyte[8] buffer, const ref NtpTimestamp ts)
    {
        uint networkSeconds = toNetworkByteOrder(ts.seconds);
        uint networkFraction = toNetworkByteOrder(ts.fraction);

        if ((cast(size_t) buffer.ptr & 0x3) == 0)
        {
            (cast(uint*) buffer.ptr)[0] = networkSeconds;
            (cast(uint*) buffer.ptr)[1] = networkFraction;
            return;
        }

        buffer[0] = cast(ubyte)(networkSeconds & 0xFF);
        buffer[1] = cast(ubyte)((networkSeconds >> 8) & 0xFF);
        buffer[2] = cast(ubyte)((networkSeconds >> 16) & 0xFF);
        buffer[3] = cast(ubyte)((networkSeconds >> 24) & 0xFF);

        buffer[4] = cast(ubyte)(networkFraction & 0xFF);
        buffer[5] = cast(ubyte)((networkFraction >> 8) & 0xFF);
        buffer[6] = cast(ubyte)((networkFraction >> 16) & 0xFF);
        buffer[7] = cast(ubyte)((networkFraction >> 24) & 0xFF);
    }

    private static NtpTimestamp unpackTimestamp(const ref ubyte[8] buffer)
    {
        // Read seconds (first 4 bytes)
        uint networkSeconds = (cast(uint) buffer[0] << 24) |
            (
                cast(uint) buffer[1] << 16) |
            (cast(uint) buffer[2] << 8) |
            cast(uint) buffer[3];

        // Read fraction (next 4 bytes)
        uint networkFraction = (cast(uint) buffer[4] << 24) |
            (
                cast(uint) buffer[5] << 16) |
            (cast(uint) buffer[6] << 8) |
            cast(uint) buffer[7];

        return NtpTimestamp(
            networkSeconds,
            networkFraction
        );
    }

    private static uint unpackUint32(const ref ubyte[4] buffer)
    {
        return (cast(uint) buffer[0] << 24) |
            (cast(uint) buffer[1] << 16) |
            (
                cast(uint) buffer[2] << 8) |
            cast(uint) buffer[3];
    }

    private static void packUint32(ref ubyte[4] buffer, uint value)
    {
        uint networkValue = toNetworkByteOrder(value);

        if ((cast(size_t) buffer.ptr & 0x3) == 0)
        {
            (cast(uint*) buffer.ptr)[0] = networkValue;
        }
        else
        {
            buffer[0] = cast(ubyte)(networkValue & 0xFF);
            buffer[1] = cast(ubyte)((networkValue >> 8) & 0xFF);
            buffer[2] = cast(ubyte)((networkValue >> 16) & 0xFF);
            buffer[3] = cast(ubyte)((networkValue >> 24) & 0xFF);
        }
    }

    ubyte[48] encode()
    {
        ubyte[48] buffer;

        // Byte 0: First byte (LI, VN, Mode)
        buffer[0] = firstByte;

        // Bytes 1-3: Stratum, Poll, Precision
        buffer[1] = stratum;
        buffer[2] = poll;
        buffer[3] = precision;

        // Bytes 4-15: Root Delay, Root Dispersion, Reference ID (12 bytes)
        packUint32(buffer[4 .. 8], rootDelay);
        packUint32(buffer[8 .. 12], rootDispersion);
        packUint32(buffer[12 .. 16], referenceId);

        // Bytes 16-47: Four timestamps (32 bytes)
        packTimestamp(buffer[16 .. 24], referenceTimestamp);
        packTimestamp(buffer[24 .. 32], originateTimestamp);
        packTimestamp(buffer[32 .. 40], receiveTimestamp);
        packTimestamp(buffer[40 .. 48], transmitTimestamp);

        return buffer;
    }

    static SntpPacket decode(const ubyte[] data)
    {
        if (data.length < 48)
        {
            import std.format : format;

            throw new Exception(format(
                    "SNTP packet too short: %d bytes (expected %d)",
                    data.length, SntpPacket.sizeof
            ));
        }

        SntpPacket packet;

        // Byte 0: First byte
        packet.firstByte = data[0];

        // Bytes 1-3
        packet.stratum = data[1];
        packet.poll = data[2];
        packet.precision = data[3];

        // Bytes 4-7: Root Delay
        packet.rootDelay = unpackUint32(data[4 .. 8]);

        // Bytes 8-11: Root Dispersion
        packet.rootDispersion = unpackUint32(data[8 .. 12]);

        // Bytes 12-15: Reference ID
        packet.referenceId = unpackUint32(data[12 .. 16]);

        // Bytes 16-23: Reference Timestamp
        packet.referenceTimestamp = unpackTimestamp(data[16 .. 24]);

        // Bytes 24-31: Originate Timestamp
        packet.originateTimestamp = unpackTimestamp(data[24 .. 32]);

        // Bytes 32-39: Receive Timestamp
        packet.receiveTimestamp = unpackTimestamp(data[32 .. 40]);

        // Bytes 40-47: Transmit Timestamp
        packet.transmitTimestamp = unpackTimestamp(data[40 .. 48]);

        return packet;
    }

    double calculateOffset()
    {
        // offset = [(T2 - T1) + (T3 - T4)] / 2
        // T1 = originateTimestamp (client send time)
        // T2 = receiveTimestamp (server receive time)
        // T3 = transmitTimestamp (server send time)
        // T4 = client receive time (not in packet - must be provided separately)

        // Note: This requires T4 to be passed separately or calculated externally
        return 0; // Placeholder
    }

    double calculateDelay(double T4)
    {
        // delay = (T4 - T1) - (T3 - T2)
        double T1 = originateTimestamp.toDouble();
        double T2 = receiveTimestamp.toDouble();
        double T3 = transmitTimestamp.toDouble();

        return (T4 - T1) - (T3 - T2);
    }
}

static assert(SntpPacket.sizeof == 48);

unittest
{
    SntpPacket packet;
    packet.versionNumber(4);
    packet.mode(3); // Client mode
    packet.leapIndicator(0);
    packet.stratum = 0;
    packet.poll = 4; // 16 seconds interval
    packet.precision = 0xFA; //0xFA == -6, 2^-6 = 1/64 ≈ 0.015625 secs

    import std;

    auto encoded = packet.encode();
    assert(encoded == [
            35, 0, 4, 250, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0
        ]);

    auto decoded = SntpPacket.decode(encoded);
    assert(decoded == packet);
}
