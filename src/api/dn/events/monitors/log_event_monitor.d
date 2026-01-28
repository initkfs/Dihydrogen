module api.dn.events.monitors.log_event_monitor;

import api.dn.events.monitors.event_monitor : EventMonitor;
import api.dn.events.channel_events : ChanInEvent, ChanOutEvent;

import api.core.loggers.logging : Logging;

/**
 * Authors: initkfs
 */
class LogEventMonitor : EventMonitor
{
    size_t maxPrintLengthInEvents = 100;
    size_t maxPrintLengthOutEvents = 50;
    string clipSymbol = "....";

    int targetChanIn = -1;
    int targetChanOut = -1;

    this(Logging logging)
    {
        super(logging);
    }

    static char[] escape(const(char[]) buff)
    {
        string formatChar(char ch)
        {
            import std.format : format;

            return format("\\x%X", ch);
        }

        import std.ascii : isASCII, isControl;

        char[] result;
        result.reserve(buff.length);

        foreach (char ch; buff)
        {
            if (!isASCII(ch))
            {
                result ~= formatChar(ch);
                continue;
            }

            if (isControl(ch))
            {
                if (ch >= 0x00 && ch <= 0x1F)
                {
                    static immutable hexTable = [
                        "\\x00", "\\x01", "\\x02", "\\x03", "\\x04", "\\x05",
                        "\\x06",
                        "\\x07",
                        "\\x08", "\\x09", "\\x0A", "\\x0B", "\\x0C", "\\x0D",
                        "\\x0E",
                        "\\x0F",
                        "\\x10", "\\x11", "\\x12", "\\x13", "\\x14", "\\x15",
                        "\\x16",
                        "\\x17",
                        "\\x18", "\\x19", "\\x1A", "\\x1B", "\\x1C", "\\x1D",
                        "\\x1E",
                        "\\x1F"
                    ];
                    result ~= hexTable[ch];

                }
                else
                {
                    result ~= formatChar(ch);
                }

                continue;
            }

            result ~= ch;
        }

        return result;
    }

    unittest
    {
        import std.stdio;

        assert(escape("") == "");
        assert(escape("\n\t\r") == "\\x0A\\x09\\x0D");
        assert(escape("Hello World!") == "Hello World!");
        assert(escape("Line1\nLine2\tEnd") == "Line1\\x0ALine2\\x09End");
        assert(escape("test" ~ cast(char) 0x7F ~ "end") == "test\\x7Fend");
        assert(escape(
                "Привет") == "\\xD0\\x9F\\xD1\\x80\\xD0\\xB8\\xD0\\xB2\\xD0\\xB5\\xD1\\x82");
        assert(escape("Hello\tПривет\nWorld") == "Hello\\x09\\xD0\\x9F\\xD1\\x80\\xD0\\xB8\\xD0\\xB2\\xD0\\xB5\\xD1\\x82\\x0AWorld");

        import std.conv : to;

        foreach (char ch; 0x00 .. 0x20) // 0x00 до 0x1F
        {
            auto result = escape(ch.to!string);
            auto hexDigit = [
                "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C",
                "D", "E", "F"
            ];
            string expected = "\\x" ~ hexDigit[(ch >> 4) & 0xF] ~ hexDigit[ch & 0xF];
            assert(result == expected,
                "0x" ~ to!string(cast(int) ch, 16) ~ " must be escaped as " ~ expected ~ ", but received: " ~ result);
        }
    }

    protected bool clipBuffer(ref char[] buffer, size_t maxLen)
    {
        if (buffer.length > maxLen)
        {
            buffer = buffer[0 .. maxLen];
            return true;
        }
        return false;
    }

    override bool onInEvent(ChanInEvent inEvent)
    {
        if (targetChanIn >= 0 && inEvent.chan.fd != targetChanIn)
        {
            return false;
        }

        if (inEvent.state == ChanInEvent.ChanInEventState.readStart)
        {
            import std.conv : to;

            try
            {
                char[] buffer = cast(char[]) inEvent.chan.readableBytes;
                bool isClip = clipBuffer(buffer, maxPrintLengthInEvents);
                logger.tracef("IN: %s, %s, len %d, %s%s", inEvent.chan.fd, inEvent.state, inEvent.chan
                        .readableBytes.length, escape(buffer), isClip ? clipSymbol : "");
            }

            catch (Exception e)
            {
                logger.error("IN monitor error:", e.toString);
            }
            return true;
        }

        logger.tracef("IN: %s, %s", inEvent.chan.fd, inEvent.state);
        return true;
    }

    override bool onOutRouterEvent(ChanOutEvent outEvent)
    {
        if (targetChanOut >= 0 && outEvent.chan.fd != targetChanOut)
        {
            return false;
        }

        if (outEvent.state == ChanOutEvent.ChanOutEventState.write)
        {
            import std.conv : to;

            try
            {
                char[] buffer = cast(char[]) outEvent.chan.outb.slice;
                bool isClip = clipBuffer(buffer, maxPrintLengthOutEvents);
                logger.tracef("OUT: %s, %s, len %d, %s%s", outEvent.chan.fd, outEvent.state, outEvent.chan.outb.length, buffer, isClip ? clipSymbol : "");
            }

            catch (Exception e)
            {
                logger.error("OUT monitor error:", e.toString);
            }
            return true;
        }

        logger.tracef("OUT: %s, %s", outEvent.chan.fd, outEvent.state);
        return true;
    }
}
