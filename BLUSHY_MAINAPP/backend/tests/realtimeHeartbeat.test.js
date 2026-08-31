import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

/**
 * The realtime socket needs a keepalive.
 *
 * There was none — no ping, no pong, no liveness check. Proxies and load
 * balancers, Render's included, close connections idle for around a minute,
 * and a partner chat is idle most of the time. So the socket was dropped from
 * under a conversation that was still open, which is what "partner
 * disconnected suddenly" looks like from the app.
 *
 * The ping does a second job: a socket whose peer has vanished stays readable
 * indefinitely, so without it `isUserOnline` reported people as online for ever
 * and messages were published to nobody.
 */
test('the hub pings its clients and drops the ones that stop answering', async () => {
  const source = await readFile(new URL('../src/utils/realtimeHub.js', import.meta.url), 'utf8');

  assert.ok(/socket\.on\('pong'/.test(source), 'liveness must be recorded on pong');
  assert.ok(/\.ping\(\)/.test(source), 'the server has to send the ping');
  assert.ok(/\.terminate\(\)/.test(source),
    'a socket that misses a ping must be closed, or it is counted as online for ever');
});

test('the interval is under a typical proxy idle timeout', async () => {
  const source = await readFile(new URL('../src/utils/realtimeHub.js', import.meta.url), 'utf8');
  const match = source.match(/HEARTBEAT_INTERVAL_MS\s*=\s*([\d_]+)/);
  assert.ok(match, 'the interval should be named, not inline');

  const ms = Number(match[1].replace(/_/g, ''));
  assert.ok(ms > 0 && ms < 60_000,
    `${ms}ms is not under the ~60s idle timeout this exists to stay ahead of`);
});

test('the heartbeat is stopped on shutdown', async () => {
  const hub = await readFile(new URL('../src/utils/realtimeHub.js', import.meta.url), 'utf8');
  const server = await readFile(new URL('../src/server.js', import.meta.url), 'utf8');

  assert.ok(hub.includes('export function stopRealtimeHeartbeat'));
  assert.ok(server.includes('stopRealtimeHeartbeat()'),
    'a live interval would keep the process from exiting cleanly');
});
