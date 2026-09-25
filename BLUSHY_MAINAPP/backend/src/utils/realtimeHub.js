import { URL } from 'node:url';

import jwt from 'jsonwebtoken';
import { WebSocketServer } from 'ws';

import { randomUUID } from 'node:crypto';

import { env } from './env.js';
import { logger } from './logger.js';
import { createRedisConnection } from './redisStore.js';

const clientsByUser = new Map();

/**
 * Fired when a user's FIRST socket connects (online) or their LAST one closes
 * (offline) -- a genuine presence transition, not every socket. Registered at
 * startup (server.js) so the hub itself stays free of partner/DB imports and
 * there is no import cycle. Async and best-effort: a failure here must never
 * affect the socket lifecycle.
 */
let presenceObserver = null;
export function setPresenceObserver(fn) {
  presenceObserver = typeof fn === 'function' ? fn : null;
}
function notifyPresence(userId, online) {
  if (!presenceObserver || !userId) return;
  try {
    Promise.resolve(presenceObserver(userId, online)).catch(() => {});
  } catch {
    // Never let a presence hook break connect/disconnect handling.
  }
}

/**
 * Handles a JSON message a client sends up the socket (e.g. a typing ping).
 * Registered at startup so the hub stays free of partner/DB imports. Receives
 * (userId, parsedMessage); best-effort, never throws into the socket.
 */
let inboundHandler = null;
export function setInboundMessageHandler(fn) {
  inboundHandler = typeof fn === 'function' ? fn : null;
}
function handleInbound(userId, rawMessage) {
  if (!inboundHandler || !userId) return;
  let parsed;
  try {
    const text = typeof rawMessage === 'string' ? rawMessage : rawMessage.toString();
    // A typing ping is tiny; anything large is not something we handle inbound.
    if (!text || text.length > 2000) return;
    parsed = JSON.parse(text);
  } catch {
    return;
  }
  if (!parsed || typeof parsed !== 'object') return;
  try {
    Promise.resolve(inboundHandler(userId, parsed)).catch(() => {});
  } catch {
    // A bad inbound message must never break the connection.
  }
}

/**
 * Cross-instance delivery.
 *
 * `clientsByUser` only knows about sockets attached to *this* process, so with
 * more than one instance `publishToUsers` reached whichever fraction of users
 * happened to land here and silently dropped the rest. Nothing errored; partner
 * notifications simply did not arrive.
 *
 * Every instance publishes what it wants delivered onto one Redis channel and
 * subscribes to it, so an event raised anywhere reaches sockets everywhere. With
 * no REDIS_URL this is inert and the hub behaves exactly as before, which is
 * correct for a single instance.
 */
const CHANNEL = 'blushy:realtime';
const INSTANCE_ID = `${process.env.RENDER_INSTANCE_ID ?? 'local'}-${process.pid}-${randomUUID().slice(0, 8)}`;

let publisher = null;
let subscriber = null;

/**
 * Who is connected to the *other* instances: instance id -> { users, seenAt }.
 *
 * Kept so `isUserOnline` can stay synchronous -- it decides the delivered tick
 * on partner messages and is called inline while writing one. Each instance
 * re-announces periodically; an instance not heard from is dropped, so a crashed
 * one cannot leave users looking permanently online.
 */
const remotePresence = new Map();
const PRESENCE_ANNOUNCE_MS = 20_000;
const PRESENCE_STALE_MS = 70_000;
let presenceTimer = null;

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
  // A newly connected user is worth telling the others about immediately
  // rather than at the next scheduled announcement.
  announcePresence();
  // First socket for this user -> they just came online.
  notifyPresence(userId, true);
}

function removeClient(userId, socket) {
  const set = clientsByUser.get(userId);
  if (!set) {
    return;
  }

  set.delete(socket);
  if (set.size === 0) {
    clientsByUser.delete(userId);
    announcePresence();
    // Last socket for this user closed -> they are now offline.
    notifyPresence(userId, false);
  }
}

/** Tells the other instances who is connected here. */
function announcePresence() {
  if (!publisher) return;

  publisher
    .publish(CHANNEL, JSON.stringify({
      kind: 'presence',
      origin: INSTANCE_ID,
      users: [...clientsByUser.keys()],
    }))
    .catch((error) => logger.warn(`Realtime presence announce failed: ${error.message}`));
}

/** Sends an envelope to sockets attached to this process only. */
function deliverLocally(userIds, envelopeFor) {
  for (const userId of userIds) {
    const sockets = clientsByUser.get(userId);
    if (!sockets || sockets.size === 0) continue;

    const envelope = envelopeFor(userId);
    for (const socket of sockets) {
      safeSend(socket, envelope);
    }
  }
}

function forgetStaleInstances() {
  const cutoff = Date.now() - PRESENCE_STALE_MS;
  for (const [instanceId, entry] of remotePresence) {
    if (entry.seenAt < cutoff) remotePresence.delete(instanceId);
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

    // Clients may send small JSON messages up (e.g. a typing ping); relayed to
    // partners by the registered inbound handler.
    socket.on('message', (raw) => handleInbound(userId, raw));

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
  if (set && set.size > 0) return true;

  // Connected to another instance counts as online. This decides the delivered
  // tick on a partner message: judged locally, a recipient on another instance
  // looked offline and her message was marked undelivered while she read it.
  forgetStaleInstances();
  for (const entry of remotePresence.values()) {
    if (entry.users.has(userId)) return true;
  }

  return false;
}

export function publishToUsers(userIds, event, payload = {}) {
  const uniqueUsers = [...new Set((userIds ?? []).filter((id) => typeof id === 'string' && id.length > 0))];
  if (uniqueUsers.length === 0) return;

  const ts = new Date().toISOString();
  deliverLocally(uniqueUsers, (userId) => ({ event, userId, ts, payload }));

  // And to whoever is connected elsewhere. Carries the origin so this instance
  // ignores its own message coming back and does not deliver twice.
  if (publisher) {
    publisher
      .publish(CHANNEL, JSON.stringify({
        kind: 'event', origin: INSTANCE_ID, userIds: uniqueUsers, event, payload, ts,
      }))
      .catch((error) => logger.warn(`Realtime publish failed: ${error.message}`));
  }
}

/**
 * Connects the hub to the other instances.
 *
 * Called at startup. Without REDIS_URL it does nothing and delivery stays
 * local, which is correct for one instance and is what happened before.
 */
export async function connectRealtimeBus() {
  if (!env.redisUrl && !process.env.REDIS_URL) {
    logger.info('Realtime hub is local to this process (no REDIS_URL). Correct for a single instance.');
    return;
  }

  publisher = await createRedisConnection('realtime-pub');
  subscriber = await createRedisConnection('realtime-sub');

  if (!publisher || !subscriber) {
    logger.error('Realtime hub could not reach Redis; events will not cross instances.');
    publisher = null;
    subscriber = null;
    return;
  }

  await subscriber.subscribe(CHANNEL, (raw) => {
    let message;
    try {
      message = JSON.parse(raw);
    } catch {
      return;
    }

    if (!message || message.origin === INSTANCE_ID) return;

    if (message.kind === 'presence') {
      remotePresence.set(message.origin, {
        users: new Set(Array.isArray(message.users) ? message.users : []),
        seenAt: Date.now(),
      });
      return;
    }

    if (message.kind === 'event' && Array.isArray(message.userIds)) {
      deliverLocally(message.userIds, (userId) => ({
        event: message.event,
        userId,
        ts: message.ts,
        payload: message.payload ?? {},
      }));
    }
  });

  announcePresence();
  presenceTimer = setInterval(() => {
    forgetStaleInstances();
    announcePresence();
  }, PRESENCE_ANNOUNCE_MS);
  presenceTimer.unref?.();

  logger.info(`Realtime hub joined the bus as ${INSTANCE_ID}.`);
}

/** Closes the bus connections. */
export async function disconnectRealtimeBus() {
  if (presenceTimer) {
    clearInterval(presenceTimer);
    presenceTimer = null;
  }
  remotePresence.clear();

  const closing = [];
  if (subscriber) { closing.push(subscriber.quit().catch(() => {})); subscriber = null; }
  if (publisher) { closing.push(publisher.quit().catch(() => {})); publisher = null; }
  await Promise.all(closing);
}
