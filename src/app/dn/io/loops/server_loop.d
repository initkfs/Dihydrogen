module app.dn.io.loops.server_loop;

import std.stdio : writeln, writefln;
import std.string : toStringz, fromStringz;

import io_uring_libs;
import socket_libs;

import core.stdc.stdlib : malloc, exit;
import core.stdc.string : memset, strerror;

import app.dn.io.natives.iouring.io_uring;
import app.dn.io.natives.iouring.io_uring_types;

import std.conv : to;
import std.string : toStringz, fromStringz;
import std.logger;

import app.core.components.units.services.loggable_unit : LoggableUnit;
import app.dn.pools.linear_pool : LinearPool;
import app.dn.channels.fd_channel : FdChannel, FdChannelType;
import app.dn.net.sockets.socket_connect : SocketConnectState;

import app.dn.io.loops.endpointable_event_loop: EndpointableEventLoop;

import app.dn.channels.server_channel : ServerChannel;
import app.dn.channels.events.routes.event_router : EventRouter;
import app.dn.channels.events.translators.event_translator : EventTranslator;
import app.dn.channels.events.monitors.event_monitor : EventMonitor;

/**
 * Authors: initkfs
 */
class ServerLoop : EndpointableEventLoop
{

    ServerChannelData[int] channelsMap;

    private
    {
        ServerChannel[] serverChans;
    }

    this(Logger logger, ServerChannel[] serverChans, EventRouter router, EventTranslator translator = null, EventMonitor monitor = null)
    {
        super(logger, router, translator, monitor);
        this.serverChans = serverChans;
    }

    struct ServerChannelData
    {
        FdChannel* chan;
        LinearPool!(FdChannel*) pool;
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
            auto pool = new LinearPool!(FdChannel*)(channelsPoolSize);
            pool.create;
            foreach (i; 0 .. pool.count)
            {
                pool.set(i, newChannel);
            }

            auto chanData = ServerChannelData(serverSocket, pool, serverChan.port);

            channelsMap[serverChan.fd] = chanData;

            logger.infof("Listen: 127.0.0.1:%d fd: %d", chanData.port, chanData.chan.fd);

            addServerAccept(serverChan.fd);
        }
    }

    override FdChannel* getChannel(int serverFd, int activeChannelFd)
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
            conn.resetBufferIndices;
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
