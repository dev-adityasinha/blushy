import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';

/**
 * The user record is read once per request, not twice.
 *
 * Both auth middlewares load the user and check the token version against it.
 * Every controller then called its own `requireAuthUser` helper, which loaded
 * the same record again — and `getUserById` is itself two queries, because a
 * user may be in either collection. So an authenticated request paid for the
 * same lookup twice before doing any of its own work.
 *
 * The middlewares now mark the request, and the helpers reuse that. The one
 * exception is partnerController, whose helper returns the whole record rather
 * than an id and role, so its lookup is doing real work.
 */
test('both auth middlewares mark the request as verified', async () => {
  for (const file of ['requireAuth.js', 'optionalAuth.js']) {
    const source = await readFile(new URL(`../src/middleware/${file}`, import.meta.url), 'utf8');
    assert.ok(source.includes('verifiedAgainstDb'),
      `${file} must record that it read and checked the user`);
  }
});

test('optionalAuth uses the database role, not the token role', async () => {
  // It already had the record in hand and set `req.user = decoded`, so the
  // role came from the token and stayed stale after a role change. The same
  // shape of bug was fixed in requireAuth earlier.
  const source = await readFile(new URL('../src/middleware/optionalAuth.js', import.meta.url), 'utf8');
  assert.ok(/role:\s*dbUser\.role/.test(source),
    'the authoritative role is the one on the record it just read');
});

test('controller helpers do not repeat the lookup', async () => {
  const dir = new URL('../src/controllers/', import.meta.url);
  const offenders = [];

  for (const name of await readdir(dir)) {
    if (!name.endsWith('.js')) continue;
    const source = await readFile(new URL(name, dir), 'utf8');
    const match = source.match(/async function requireAuthUser\w*\(req\)[\s\S]*?\n\}/);
    if (!match) continue;

    // partnerController returns the full record, which the middleware does not
    // carry on req.user, so it genuinely has to read it.
    if (name === 'partnerController.js') continue;

    if (!match[0].includes('verifiedAgainstDb')) offenders.push(name);
  }

  assert.deepEqual(offenders, [],
    `these read the user again after the middleware already did: ${offenders.join(', ')}`);
});
