module api.dn.events.converters.event_converter;

import api.dn.events.chan_events : ChanInEvent, ChanOutEvent;

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
