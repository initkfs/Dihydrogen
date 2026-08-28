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

import api.dn.io.loops.endpointable_event_loop : EndpointableEventLoop;

import api.dn.chans.server_chan : ServerChan;
import api.dn.sockets.socket_connect : SocketConnectState;
import api.dn.chans.fd_chan : FdChanType;
import api.dn.events.routes.event_router : EventRouter;
import api.dn.events.converters.event_converter : EventConverter;
import api.dn.events.monitors.event_monitor : EventMonitor;

import socket_libs;

/**
 * Authors: initkfs
 */
class ServerLoop : EndpointableEventLoop
{

    ServerChannelData[int] channelsMap;

    bool isSystemd;
    size_t shutdownMaxSec = 1;

    private
    {
        ServerChan[] serverChans;
    }

    this(Logging logger, int controlFd, ServerChan[] serverChans, EventRouter router, EventConverter translator = null, EventMonitor monitor = null)
    {
        super(logger, controlFd, router, translator, monitor);
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

    override void run()
    {
        super.run;

        import socket_libs : close;
        import io_uring_libs;

        //TODO IORING_OP_ACCEPT, MULTISHOT_ACCEPT, IORING_OP_ASYNC_CANCEL
        foreach (ServerChan serverChan; serverChans)
        {
            import Mem = api.core.utils.mem;

            FdChan* schan = new FdChan(serverChan.fd, FdChanType.socket);
            Mem.addRootSafe(schan);
            addSocketClose(&ring, schan);
            logger.tracef("Close server chan: %d", serverChan.fd);
        }

        size_t clientCount;
        foreach (int fd, ref chanData; channelsMap)
        {
            //TODO max chan
            foreach (FdChan* chan; chanData.pool.slice)
            {
                //send FIN
                if (chan.type == FdChanType.socket && chan.state == SocketConnectState.write)
                {
                    addSocketShutdown(&ring, chan, SHUT_WR);
                    clientCount++;
                }
            }
        }

        if (clientCount > 0)
        {
            logger.tracef("Shutdown clients: %d", clientCount);
        }

        logger.trace("Start drain loop");

        import std.datetime.stopwatch : StopWatch, AutoStart;
        import std.datetime : Duration, seconds;

        immutable Duration maxWaitTime = shutdownMaxSec.seconds;
        auto sw = StopWatch(AutoStart.yes);

        while (queueCount > 0 && sw.peek < maxWaitTime)
        {
            if (!runStepIsContinue(false))
            {
                logger.trace("Break drain loop");
                break;
            }
        }

        logger.trace("End drain loop");
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

    override bool onWatchdogIsContinue()
    {
        if (isSystemd)
        {
            import api.dn.libs.systemd.binddynamic : sd_notify;

            assert(sd_notify);
            sd_notify(0, "WATCHDOG=1");
            logger.trace("Send notify to systemd");
        }

        return true;
    }
}
