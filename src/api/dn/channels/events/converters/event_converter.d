module api.dn.channels.events.converters.event_converter;

import api.dn.channels.events.channel_events : ChanInEvent, ChanOutEvent;

/**
 * Authors: initkfs
 */

class EventConverter
{
    bool isNeedConvert(in ChanInEvent inEvent) => false;
    ChanInEvent convertInEvent(ChanInEvent inEvent) => inEvent;

    bool isNeedConvert(in ChanOutEvent outEvent) => false;
    ChanOutEvent convertOutEvent(ChanOutEvent outEvent) => outEvent;
}
