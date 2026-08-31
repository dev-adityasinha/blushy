import { URL } from 'node:url';

import jwt from 'jsonwebtoken';
import { WebSocketServer } from 'ws';

import { env } from './env.js';
import { logger } from './logger.js';

const clientsByUser = new Map();

// Comfortably under the ~60s idle timeout that proxies apply.
const HEARTBEAT_INTERVAL_MS = 25_000;
let heartbeatTimer = null;
let websocketServer = null;

function addClient(userId, socket) {
  const existing = clientsByUser.get(userId);
  if (existing) {
    existing.add(socket);
    return;
  }

  clientsByUser.set(userId, new Set([socket]));
}

function removeClient(userId, socket) {
  const set = clientsByUser.get(userId);
  if (!set) {
    return;
  }

  set.delete(socket);
  if (set.size === 0) {
    clientsByUser.delete(userId);
  }
}

function parseTokenFromRequest(requestUrl) {
  try {
    const parsed = new URL(requestUrl ?? '', 'http://localhost');
    const token = parsed.searchParams.get('token');
    return typeof token === 'string' && token.trim().length > 0 ? token.trim() : null;
  } catch {
    return null;
  }
}

function safeSend(socket, payload) {
  if (socket.readyState !== socket.OPEN) {
    return;
  }

  socket.send(JSON.stringify(payload));
}

export function initRealtimeHub(server) {
  if (websocketServer) {
    return websocketServer;
  }

  websocketServer = new WebSocketServer({
    server,
    path: '/ws',
  });

  websocketServer.on('connection', (socket, request) => {
    const token = parseTokenFromRequest(request.url);
    if (!token) {
      socket.close(1008, 'Missing auth token');
      return;
    }

    let decoded;
    try {
      decoded = jwt.verify(token, env.jwtSecret, { algorithms: ['HS256'] });
    } catch {
      socket.close(1008, 'Invalid auth token');
      return;
    }

    const userId = typeof decoded?.userId === 'string' ? decoded.userId : null;
    if (!userId) {
      socket.close(1008, 'Invalid user');
      return;
    }

    socket.userId = userId;
    socket.isAlive = true;
    // Answering a ping is what keeps the connection from being culled below,
    // and what proves the peer is still there rather than merely still open.
    socket.on('pong', () => {
      socket.isAlive = true;
    });

    addClient(userId, socket);
    safeSend(socket, { event: 'realtime.connected', userId, ts: new Date().toISOString() });

    socket.on('close', () => {
      removeClient(userId, socket);
    });

    socket.on('error', () => {
      removeClient(userId, socket);
    });
  });

  // There was no keepalive at all. Proxies and load balancers -- Render's
  // included -- close connections that have been idle for around a minute, and
  // a partner chat is idle most of the time. So the socket was dropped from
  // underneath a conversation that was still open, which is what "partner
  // disconnected suddenly" looks like.
  //
  // The ping is also how a half-open connection is noticed: a socket whose peer
  // has gone away stays readable indefinitely and would otherwise be counted as
  // online for ever, so `isUserOnline` would lie and messages would be sent to
  // nobody.
  heartbeatTimer = setInterval(() => {
    for (const socket of websocketServer.clients) {
      if (socket.isAlive === false) {
        // It did not answer the previous ping.
        socket.terminate();
        continue;
      }
      socket.isAlive = false;
      try {
        socket.ping();
      } catch {
        socket.terminate();
      }
    }
  }, HEARTBEAT_INTERVAL_MS);
  // Node keeps the process alive for a pending timer; this one should not.
  heartbeatTimer.unref?.();

  logger.info('Realtime WebSocket hub ready at /ws');
  return websocketServer;
}

/// Stops the keepalive. Used by the test harness and graceful shutdown.
export function stopRealtimeHeartbeat() {
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }
}

export function isUserOnline(userId) {
  if (!userId) {
    return false;
  }
  const set = clientsByUser.get(userId);
  return Boolean(set && set.size > 0);
}

export function publishToUsers(userIds, event, payload = {}) {
  const uniqueUsers = [...new Set((userIds ?? []).filter((id) => typeof id === 'string' && id.length > 0))];

  for (const userId of uniqueUsers) {
    const sockets = clientsByUser.get(userId);
    if (!sockets || sockets.size === 0) {
      continue;
    }

    const envelope = {
      event,
      userId,
      ts: new Date().toISOString(),
      payload,
    };

    for (const socket of sockets) {
      safeSend(socket, envelope);
    }
  }
}
