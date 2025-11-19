module api.dn.channels.events.monitors.log_event_monitor;

import api.dn.channels.events.monitors.event_monitor : EventMonitor;
import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

import api.core.loggers.logging : Logging;

/**
 * Authors: initkfs
 */
class LogEventMonitor : EventMonitor
{

    this(Logging logging)
    {
        super(logging);
    }

    private char[] escape(const(char[]) buff)
    {
        string formatChar(char ch)
        {
            import std.format : format;

            return format("\\x%02X", ch);
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

        foreach (char ch; 0x00 .. 0x20) // 0x00 до 0x1F
        {
            string result = escape(ch);
            string expected = "\\x" ~ (ch < 0x10 ? "0" : "") ~
                ([
                    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B",
                    "C", "D", "E", "F"
            ][ch & 0xF]);
            assert(result == expected,
                "0x" ~ to!string(ch, 16) ~ " must be escaped as " ~ expected ~ ", but received: " ~ result);
        }
    }

    override void onInEvent(ChanInEvent inEvent)
    {
        if (inEvent.state == ChanInEvent.ChanInEventState.readStart)
        {
            import std.conv : to;

            try
            {
                bool isText = inEvent.chan.isText;

                ubyte[] buffer = inEvent.chan.readableBytes;
                logger.tracef("IN:%s, %s, %s", inEvent.chan.fd, inEvent.state, buffer);

            }

            catch (Exception e)
            {
                logger.error("Monitor error:", e.toString);
            }
            return;
        }

        logger.tracef("%s:%s, %s", typeof(inEvent).stringof, inEvent.chan.fd, inEvent.state);
    }

    override void onOutRouterEvent(ChanOutEvent outEvent)
    {
        if (outEvent.state == ChanOutEvent.ChanOutEventState.write)
        {
            import std.conv : to;

            //TODO utf, remove unsafe cast
            // dstring buffStr = (cast(string) outEvent.buffer).to!dstring;
            // logger.tracef("%s:%s, %s, buff:%s", typeof(outEvent).stringof, outEvent.chan.fd, outEvent.state, escape(
            //         buffStr));
            return;
        }

        logger.tracef("%s:%s, %s", typeof(outEvent).stringof, outEvent.chan.fd, outEvent.state);
    }
}
