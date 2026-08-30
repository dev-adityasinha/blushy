import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

/**
 * The general IP limiter must leave room for ordinary use.
 *
 * It was 60 requests per five minutes in production -- 0.2 a second -- while
 * filling the dashboard once costs seven. Reading the feed and writing a post
 * went over the line, and the only thing the user saw was "Failed to publish
 * post" even though the endpoint returned 201 whenever it was allowed through.
 *
 * The limiter is also keyed by IP, and mobile carriers put many subscribers
 * behind one address, so unrelated users shared a single budget.
 */
test('rate limits: the general IP budget leaves room for a real session', async () => {
  const source = await readFile(
    new URL('../src/middleware/rateLimiters.js', import.meta.url), 'utf8');

  const match = source.match(/IP_RATE_LIMIT_MAX \?\? \(isDev \? (\d+) : (\d+)\)/);
  assert.ok(match, 'could not read the IP limiter default');

  const production = Number(match[2]);
  // One dashboard sync is 7 requests. A five minute window should absorb many
  // syncs plus browsing, not two dozen requests total.
  assert.ok(production >= 300,
    `production budget is ${production} per window; that is too tight for a session `
    + 'whose dashboard sync alone costs 7 requests');
});

test('rate limits: credential endpoints stay tight', async () => {
  // Raising the general limiter must not loosen brute-force protection. These
  // are what actually guard credentials, and they are deliberately strict.
  const source = await readFile(
    new URL('../src/middleware/rateLimiter.js', import.meta.url), 'utf8');

  const limits = [...source.matchAll(/export const (\w+RateLimiter)[\s\S]{0,200}?max: (\d+)/g)]
    .map(([, name, max]) => [name, Number(max)]);

  assert.ok(limits.length >= 4, `expected the credential limiters, found ${limits.length}`);
  for (const [name, max] of limits) {
    assert.ok(max <= 10, `${name} allows ${max} attempts per window, which is too many`);
  }
});
