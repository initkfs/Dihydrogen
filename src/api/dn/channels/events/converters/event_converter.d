module api.dn.channels.events.converters.event_converter;

import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

/**
 * Authors: initkfs
 */

class EventConverter
{

    ChanInEvent convertInEvent(ChanInEvent inEvent)
    {
        return inEvent;
    }

    ChanOutEvent convertOutEvent(ChanOutEvent outEvent)
    {
        return outEvent;
    }

}
