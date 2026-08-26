import { URL } from 'node:url';

import jwt from 'jsonwebtoken';
import { WebSocketServer } from 'ws';

import { env } from './env.js';
import { logger } from './logger.js';

const clientsByUser = new Map();
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
    addClient(userId, socket);
    safeSend(socket, { event: 'realtime.connected', userId, ts: new Date().toISOString() });

    socket.on('close', () => {
      removeClient(userId, socket);
    });

    socket.on('error', () => {
      removeClient(userId, socket);
    });
  });

  logger.info('Realtime WebSocket hub ready at /ws');
  return websocketServer;
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
