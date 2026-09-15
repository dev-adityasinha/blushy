import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

import { startTestServer, stopTestServer, createTestUser, api, getDb } from './helpers/testServer.js';

/**
 * Leaving is one person's decision.
 *
 * It used to take both: the first call parked the row at `breakup_pending` and
 * the connection stayed live -- still sharing -- until the other partner
 * agreed to let go. Someone who wants out of a relationship does not need the
 * other person's permission, and an app that requires it is the wrong shape
 * for the situation it is in.
 *
 * So one call ends it. `breakupRequestedByUserId` survives, and is what the
 * remaining partner reads to be told who ended it. A second call is that
 * partner acknowledging the notice, which retires the row entirely.
 */

before(async () => { await startTestServer(); });
after(async () => { await stopTestServer(); });

async function connectedPair() {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = randomUUID();

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

const breakup = (token, connectionId) =>
  api('POST', `/partner/connections/${connectionId}/breakup`, { token });

const connectionsFor = async (actor) => {
  const res = await api('GET', '/partner/connections', { token: actor.token });
  assert.equal(res.status, 200);
  return res.body.connections ?? res.body.data ?? [];
};

test('one partner disconnecting ends it there and then', async () => {
  const { woman, connectionId } = await connectedPair();

  const result = await breakup(woman.token, connectionId);
  assert.equal(result.status, 200);
  assert.equal(
    result.body.connection.status,
    'breakup',
    'no waiting on the other person to agree',
  );
  assert.ok(result.body.connection.endedAt, 'an ended connection is dated');
});

test('nothing is left pending for the other partner to answer', async () => {
  // The state that made leaving conditional. If it comes back, so does the
  // "your partner has asked to disconnect" prompt.
  const { woman, man, connectionId } = await connectedPair();
  await breakup(woman.token, connectionId);

  const row = await getDb().collection('partner_connections')
    .findOne({ connection_id: connectionId });
  assert.notEqual(row.status, 'breakup_pending');

  for (const [who, actor] of [['the one who left', woman], ['the other', man]]) {
    const conn = (await connectionsFor(actor))
      .find((c) => c.connectionId === connectionId);
    assert.ok(conn, `${who} still sees the row`);
    assert.notEqual(conn.status, 'breakup_pending', `${who} sees no pending ask`);
  }
});

test('the remaining partner can tell who ended it', async () => {
  // This is what the portal words as "<name> disconnected".
  const { woman, man, connectionId } = await connectedPair();
  await breakup(woman.token, connectionId);

  const conn = (await connectionsFor(man))
    .find((c) => c.connectionId === connectionId);
  assert.equal(conn.status, 'breakup');
  assert.equal(
    conn.breakupRequestedByUserId,
    woman.userId,
    'the name shown is read off this field',
  );
});

test('acknowledging the notice retires the connection for both', async () => {
  const { woman, man, connectionId } = await connectedPair();
  await breakup(woman.token, connectionId);

  const ack = await breakup(man.token, connectionId);
  assert.equal(ack.status, 200);
  assert.equal(ack.body.connection.status, 'ended');

  for (const [who, actor] of [['she', woman], ['he', man]]) {
    const conn = (await connectionsFor(actor))
      .find((c) => c.connectionId === connectionId);
    assert.equal(conn, undefined, `${who} should no longer be shown it`);
  }
});

test('an ended connection does not block connecting again', async () => {
  // A row left lying around that still counted as a connection would make the
  // two of them unable to reconnect, and unable to see why.
  const { woman, man, connectionId } = await connectedPair();
  await breakup(woman.token, connectionId);

  const invite = await api('POST', '/partner/invite', {
    token: woman.token,
    body: { partnerEmail: `${man.userId}@example.test` },
  });
  assert.notEqual(
    invite.status,
    409,
    'the dead connection must not read as an existing one',
  );
});

test('a stranger cannot disconnect someone else', async () => {
  const { connectionId } = await connectedPair();
  const outsider = await createTestUser({ role: 'woman' });

  const result = await breakup(outsider.token, connectionId);
  assert.ok(
    result.status >= 400 || result.body?.connection == null,
    'someone outside the connection must not be able to end it',
  );

  const row = await getDb().collection('partner_connections')
    .findOne({ connection_id: connectionId });
  assert.equal(row.status, 'active', 'the connection is untouched');
});
