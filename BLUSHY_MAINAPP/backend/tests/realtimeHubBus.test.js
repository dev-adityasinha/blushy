import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

/**
 * `clientsByUser` is a per-process Map. With a second instance, an event
 * published on one reached only the sockets attached to that one, and every
 * user connected elsewhere was silently skipped -- no error, nothing logged, a
 * partner notification that simply never arrived.
 *
 * These read the hub's source rather than standing up two instances and a
 * Redis: what matters is the delivery rules, and they are visible statically.
 * A behavioural test would need real infrastructure this suite does not have.
 */

const SOURCE = new URL('../src/utils/realtimeHub.js', import.meta.url);
const source = await readFile(SOURCE, 'utf8');

test('an event is published to the other instances, not just delivered locally', () => {
  const publish = source.slice(source.indexOf('export function publishToUsers'));
  const body = publish.slice(0, publish.indexOf('\n}'));

  assert.ok(body.includes('deliverLocally('), 'must still deliver to local sockets');
  assert.ok(body.includes('publisher'), 'must also fan out to the other instances');
});

test('an instance ignores its own message coming back', () => {
  // Without this the originating instance delivers twice: once directly, once
  // when its own broadcast returns on the channel.
  assert.ok(
    source.includes('message.origin === INSTANCE_ID'),
    'the subscriber must skip messages it published itself',
  );
  assert.ok(
    source.includes('origin: INSTANCE_ID'),
    'published messages must carry their origin',
  );
});

test('a received event is delivered but never re-published', () => {
  const handler = source.slice(source.indexOf('await subscriber.subscribe'));
  const body = handler.slice(0, handler.indexOf('announcePresence();'));

  assert.ok(body.includes('deliverLocally('), 'a received event should reach local sockets');
  assert.ok(
    !body.includes('publisher.publish'),
    're-publishing a received event would loop between instances forever',
  );
});

test('presence covers users connected to another instance', () => {
  const fn = source.slice(source.indexOf('export function isUserOnline'));
  const body = fn.slice(0, fn.indexOf('\n}'));

  assert.ok(body.includes('clientsByUser.get(userId)'), 'local sockets still count');
  assert.ok(body.includes('remotePresence'), 'so should sockets on another instance');
});

test('a dead instance stops making its users look online', () => {
  // Presence is announced, not queried, so a crashed instance would otherwise
  // leave its users permanently "online" and their messages wrongly ticked as
  // delivered.
  assert.ok(source.includes('function forgetStaleInstances'), 'stale instances must expire');
  assert.ok(
    /PRESENCE_STALE_MS\s*=\s*\d+/.test(source),
    'staleness needs a bound',
  );

  const announce = Number(source.match(/PRESENCE_ANNOUNCE_MS\s*=\s*([\d_]+)/)[1].replace(/_/g, ''));
  const stale = Number(source.match(/PRESENCE_STALE_MS\s*=\s*([\d_]+)/)[1].replace(/_/g, ''));
  assert.ok(
    stale > announce * 2,
    `a live instance must survive a missed announcement (announce ${announce}ms, stale ${stale}ms)`,
  );
});

test('without REDIS_URL the hub stays local instead of failing', () => {
  const fn = source.slice(source.indexOf('export async function connectRealtimeBus'));
  const body = fn.slice(0, fn.indexOf('\n}\n'));

  assert.ok(
    body.includes('!env.redisUrl') && body.includes('return'),
    'no Redis configured must be a no-op, not an error: it is correct for one instance',
  );
});

test('the subscriber uses its own connection', () => {
  // A subscribed Redis client cannot issue ordinary commands, so sharing the
  // rate limiter's client would break both.
  assert.ok(
    source.includes("createRedisConnection('realtime-pub')")
    && source.includes("createRedisConnection('realtime-sub')"),
    'publisher and subscriber need separate connections',
  );
});
