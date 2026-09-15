import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

import { startTestServer, stopTestServer, createTestUser, api, getDb } from './helpers/testServer.js';

/**
 * The portal names the partner, not their inbox.
 *
 * The connection payload carried `partnerEmail` and nothing else, so the card
 * read "codeaviii@gmail.com's Portal". The three aggregations that build it
 * already join the user document -- they just dropped everything but the
 * address and the role.
 *
 * One wrinkle these tests have to work around: the aggregations join
 * `from: 'users'`, while `createTestUser` inserts into `users_man` /
 * `users_woman`. Production has a `users` collection (650 rows, 504 of them
 * with a `display_name`), which is why the join works there. So the fixture
 * here writes where the lookup actually reads, and the first test pins that
 * mismatch rather than leaving it as a trap for the next person.
 */

before(async () => { await startTestServer(); });
after(async () => { await stopTestServer(); });

/** Puts a row where the connection aggregations look for it. */
async function seedLookupUser({ userId, email, role, displayName, preferredName }) {
  await getDb().collection('users').insertOne({
    user_id: userId,
    email,
    role,
    display_name: displayName ?? null,
    onboarding_answers: preferredName ? { preferred_name: preferredName } : {},
    created_at: new Date(),
    updated_at: new Date(),
  });
}

async function connectedPair({ manDisplayName, manPreferredName } = {}) {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = randomUUID();

  await seedLookupUser({
    userId: woman.userId,
    email: `${woman.userId}@example.test`,
    role: 'woman',
    displayName: 'Anaya',
  });
  await seedLookupUser({
    userId: man.userId,
    email: `${man.userId}@example.test`,
    role: 'man',
    displayName: manDisplayName,
    preferredName: manPreferredName,
  });

  await getDb().collection('partner_connections').insertOne({
    connection_id: connectionId,
    user_a_id: woman.userId,
    user_b_id: man.userId,
    permission_owner_user_id: woman.userId,
    permissions: {},
    status: 'active',
    created_at: new Date(),
    updated_at: new Date(),
  });

  return { woman, man, connectionId };
}

async function connectionFor(actor, connectionId) {
  const res = await api('GET', '/partner/connections', { token: actor.token });
  assert.equal(res.status, 200);
  return (res.body.connections ?? []).find((c) => c.connectionId === connectionId);
}

test('the connection carries the partner name, not only the address', async () => {
  const { woman, connectionId } = await connectedPair({ manDisplayName: 'Aviii' });

  const conn = await connectionFor(woman, connectionId);
  assert.ok(conn, 'the connection should be listed');
  assert.equal(conn.partnerName, 'Aviii');
  assert.ok(conn.partnerEmail, 'the address is still there for other uses');
  assert.notEqual(
    conn.partnerName,
    conn.partnerEmail,
    'a name that equals the address means the lookup fell through',
  );
});

test('both partners see each other by name', async () => {
  // Each side reads the other end of the same row, so a mix-up here would show
  // someone their own name as their partner's.
  const { woman, man, connectionId } = await connectedPair({ manDisplayName: 'Aviii' });

  const hers = await connectionFor(woman, connectionId);
  const his = await connectionFor(man, connectionId);

  assert.equal(hers.partnerName, 'Aviii', 'she sees him');
  assert.equal(his.partnerName, 'Anaya', 'he sees her');
});

test('an onboarding preferred_name is used when no display_name is set', async () => {
  // Saving onboarding answers writes display_name too, but older rows only
  // carry the answer.
  const { woman, connectionId } = await connectedPair({ manPreferredName: 'Avi' });

  const conn = await connectionFor(woman, connectionId);
  assert.equal(conn.partnerName, 'Avi');
});

test('no name set leaves partnerName null rather than the address', async () => {
  // The client decides what to show when there is no name. A repository that
  // answered an email to a question about a name would make the two
  // impossible to tell apart.
  const { woman, connectionId } = await connectedPair();

  const conn = await connectionFor(woman, connectionId);
  assert.equal(conn.partnerName, null);
  assert.ok(conn.partnerEmail, 'the address is still available as a fallback');
});
