import test from 'node:test';
import assert from 'node:assert/strict';

import { getActivePartnerUserIds } from '../src/repositories/partnerRepository.js';
import { closeDb, db } from '../src/utils/db.js';

/**
 * Presence notifications go to the user on the *other* side of an ACTIVE
 * connection, so the partner screen can flip an online/offline dot. Pending or
 * ended connections must not leak presence.
 */
test('getActivePartnerUserIds returns the other side of active connections only', async (t) => {
  const stamp = Date.now();
  const a = `pres_a_${stamp}`;
  const b = `pres_b_${stamp}`;
  const c = `pres_c_${stamp}`;

  t.after(async () => {
    try {
      await db.collection('partner_connections')
        .deleteMany({ connection_id: { $in: [`pc1_${stamp}`, `pc2_${stamp}`, `pc3_${stamp}`] } });
    } catch (_) {}
  });

  await db.collection('partner_connections').insertMany([
    { connection_id: `pc1_${stamp}`, user_a_id: a, user_b_id: b, status: 'active' },
    { connection_id: `pc2_${stamp}`, user_a_id: a, user_b_id: c, status: 'ended' },   // ignored
    { connection_id: `pc3_${stamp}`, user_a_id: c, user_b_id: a, status: 'pending' }, // ignored
  ]);

  assert.deepEqual(await getActivePartnerUserIds(a), [b],
    'only the active connection counts, from either side');
  assert.deepEqual(await getActivePartnerUserIds(b), [a],
    'resolves the partner from the user_b side too');
  assert.deepEqual(await getActivePartnerUserIds(c), [],
    'a user with only pending/ended connections has no active partner');
  assert.deepEqual(await getActivePartnerUserIds(null), []);
});

test('teardown', async () => {
  await closeDb();
});
