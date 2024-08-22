module api.dn.channels.events.translators.event_translator;

import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

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
