module api.dn.io.loops.client_loop;

import std.stdio : writeln, writefln;
import std.string : toStringz, fromStringz;

import io_uring_libs;
import socket_libs;

import core.stdc.stdlib : malloc, exit;
import core.stdc.string : memset, strerror;

import api.dn.io.natives.iouring.io_uring;
import api.dn.io.natives.iouring.io_uring_types;

import std.conv : to;
import std.string : toStringz, fromStringz;
import api.core.loggers.logging;

import api.core.components.units.services.loggable_unit : LoggableUnit;
import api.dn.utils.pools.linear_pool : LinearPool;
import api.dn.chans.fd_chan : FdChan, FdChanType;
import api.dn.sockets.socket_connect : SocketConnectState;

import api.dn.io.loops.endpointable_event_loop : EndpointableEventLoop;

import api.dn.chans.server_chan : ServerChan;
import api.dn.events.channel_events : ChanInEvent, ChanOutEvent;
import api.dn.events.routes.event_router : EventRouter;
import api.dn.events.converters.event_converter : EventConverter;
import api.dn.events.monitors.event_monitor : EventMonitor;

/**
 * Authors: initkfs
 */
class ClientLoop : EndpointableEventLoop
{

    ClientChannelData channelData;

    protected
    {
        ServerChan clientChannel;
    }

    this(Logging logger, ServerChan clientChannel, EventRouter router, EventConverter translator = null, EventMonitor monitor = null)
    {
        super(logger, router, translator, monitor);
        this.clientChannel = clientChannel;

        isClient = true;

        assert(!onStartLoop);
        onStartLoop = () {
            assert(channelData.chan);
            router.routeInEvent(newChanInEvent(channelData.chan, ChanInEvent
                    .ChanInEventState
                    .connect));
        };
    }

    struct ClientChannelData
    {
        FdChan* chan;
        ushort port;
    }

    override void create()
    {
        super.create;

        auto clientSocket = newChannel(clientChannel.fd);
        channelData = ClientChannelData(clientSocket, clientChannel.port);
    }

    override FdChan* getChannel(int serverFd, int activeChannelFd)
    {
        assert(serverFd == channelData.chan.fd);
        return channelData.chan;
    }
}
