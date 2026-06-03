module api.dn.io.loops.server_loop;

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

import api.dn.io.loops.endpointable_event_loop: EndpointableEventLoop;

import api.dn.chans.server_chan : ServerChan;
import api.dn.events.routes.event_router : EventRouter;
import api.dn.events.converters.event_converter : EventConverter;
import api.dn.events.monitors.event_monitor : EventMonitor;

/**
 * Authors: initkfs
 */
class ServerLoop : EndpointableEventLoop
{

    ServerChannelData[int] channelsMap;

    private
    {
        ServerChan[] serverChans;
    }

    this(Logging logger, ServerChan[] serverChans, EventRouter router, EventConverter translator = null, EventMonitor monitor = null)
    {
        super(logger, router, translator, monitor);
        this.serverChans = serverChans;
    }

    struct ServerChannelData
    {
        FdChan* chan;
        LinearPool!(FdChan*) pool;
        ushort port;
        sockaddr_in client_addr;
        socklen_t client_len = (client_addr).sizeof;
    }

    override void create()
    {
        super.create;

        foreach (serverChan; serverChans)
        {
            auto serverSocket = newChannel(serverChan.fd);
            auto pool = new LinearPool!(FdChan*)(channelsPoolSize);
            pool.create;
            foreach (i; 0 .. pool.length)
            {
                pool.set(i, newChannel);
            }

            auto chanData = ServerChannelData(serverSocket, pool, serverChan.port);

            channelsMap[serverChan.fd] = chanData;

            logger.infof("Listen: 127.0.0.1:%d fd: %d", chanData.port, chanData.chan.fd);

            addServerAccept(serverChan.fd);
        }
    }

    override FdChan* getChannel(int serverFd, int activeChannelFd)
    {
        auto channelsPool = channelsMap[serverFd].pool;
        assert(channelsPool);

        while (!channelsPool.hasIndex(activeChannelFd))
        {
            if (!channelsPool.increase)
            {
                logger.error("Error change buffer size");
                exit(1);
            }
        }

        auto conn = channelsPool.get(activeChannelFd);
        if (!conn)
        {
            auto newConnect = newChannel(activeChannelFd);
            channelsPool.set(activeChannelFd, newConnect);
            conn = newConnect;
        }
        else
        {
            conn.fd = activeChannelFd;
            conn.state = SocketConnectState.none;
            conn.resetPart;
        }

        assert(conn);
        return conn;
    }

    override void addServerAccept(int serverFd)
    {
        auto chanData = &channelsMap[serverFd];
        assert(chanData.chan);
        addSocketAccept(&ring, chanData.chan, cast(sockaddr*)&(chanData.client_addr), &(
                chanData.client_len));
    }
}
