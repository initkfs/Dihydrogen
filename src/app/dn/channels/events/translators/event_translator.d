module app.dn.channels.events.translators.event_translator;

import app.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

/**
 * Authors: initkfs
 */

class EventTranslator
{

    ChanInEvent translateInEvent(ChanInEvent inEvent)
    {
        return inEvent;
    }

    ChanOutEvent translateOutEvent(ChanOutEvent outEvent)
    {
        return outEvent;
    }

}
