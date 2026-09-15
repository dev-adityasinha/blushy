import test from 'node:test';
import assert from 'node:assert/strict';

import { partnerRepository as P } from '../src/repositories/partnerRepository.js';
import { createEvent } from '../src/repositories/healthEventRepository.js';
import { closeDb, db } from '../src/utils/db.js';

/**
 * What the partner sees has to be what she logged.
 *
 * The partner view read `user_daily_moods` and the sleep table. Nothing in the
 * app writes either — the check-in records health events, and `saveDailyMood`
 * and `saveSleepLog` exist in the client service and are called from no screen.
 * So `latestMood` and `latestSleep` came back null for every couple however
 * faithfully she checked in, which is the partner feature showing nothing.
 */
async function pair(suffix) {
  const w = `test_psd_w_${suffix}`;
  const m = `test_psd_m_${suffix}`;

  await db.collection('users_woman').insertOne({
    user_id: w, role: 'woman', email: `${w}@t.test`, display_name: 'Asha',
    timezone: 'Asia/Kolkata', created_at: new Date(), life_stage: 'reproductiveYears',
    onboarding_answers: { life_stage: 'reproductiveYears', preferred_name: 'Asha' },
  });
  await db.collection('users_man').insertOne({
    user_id: m, role: 'man', email: `${m}@t.test`, display_name: 'Ravi',
    timezone: 'Asia/Kolkata', created_at: new Date(), onboarding_answers: {},
  });

  const inv = await P.createInvitation({ senderUserId: w, receiverUserId: m, receiverEmail: `${m}@t.test` });
  const connectionId = await P.createConnectionForInvitation({
    senderUserId: w, receiverUserId: m, invitationId: inv.invitationId ?? inv.invitation_id,
  });
  await P.updateConnectionPermissions({
    connectionId, actorUserId: w,
    permissionPatch: { shareMood: true, shareSleep: true, shareCycle: true },
  });

  return { w, m, connectionId };
}

async function wipe(ids) {
  for (const c of ['users_woman', 'users_man', 'partner_connections', 'partner_invitations',
                   'partner_messages', 'partner_notifications', 'health_events']) {
    try {
      await db.collection(c).deleteMany({
        $or: [{ user_id: { $in: ids } }, { user_a_id: { $in: ids } },
              { sender_user_id: { $in: ids } }, { recipient_user_id: { $in: ids } }],
      });
    } catch (_) {}
  }
}

test('a check-in logged as events reaches the partner', async (t) => {
  const { w, m, connectionId } = await pair(`ev_${Date.now()}`);
  t.after(() => wipe([w, m]));

  const today = new Date().toISOString().slice(0, 10);
  for (const [type, payload] of [
    ['mood_logged', { mood: 'low' }],
    ['energy_logged', { level: 2 }],
    ['sleep_logged', { durationHours: 5 }],
  ]) {
    const r = await createEvent(w, {
      eventType: type, payload, timestamp: `${today}T09:00:00.000Z`, source: 'manual',
    });
    assert.ok(r.ok, r.error);
  }

  const shared = await P.getSharedData({ connectionId, viewerUserId: m });

  assert.ok(shared.latestMood, 'mood must reach the partner');
  // The mood schema deliberately stores a canonical value and drops
  // `reportedAs`, so "Tired" reaches the partner as "low". That is the design,
  // not a defect: the coded set is what the pattern rules match on.
  assert.equal(shared.latestMood.mood, 'low');
  assert.equal(shared.latestMood.energyLevel, 2);
  assert.ok(shared.latestSleep, 'sleep must reach the partner');
});

test('her name is shown, never her account identifier', async (t) => {
  const { w, m, connectionId } = await pair(`nm_${Date.now()}`);
  t.after(() => wipe([w, m]));

  const shared = await P.getSharedData({ connectionId, viewerUserId: m });

  const needs = JSON.stringify(shared.dynamicNeeds ?? {});
  assert.doesNotMatch(needs, /test_psd_w_/, 'a user id must never appear in partner copy');
  assert.doesNotMatch(needs, /@t\.test/, 'nor an email address');
  assert.equal(shared.dynamicNeeds?.partnerName, 'Asha');
});

test('sharing stays off until she turns it on', async (t) => {
  const w = `test_psd_off_w_${Date.now()}`;
  const m = `test_psd_off_m_${Date.now()}`;
  t.after(() => wipe([w, m]));

  await db.collection('users_woman').insertOne({
    user_id: w, role: 'woman', email: `${w}@t.test`, display_name: 'Asha',
    timezone: 'Asia/Kolkata', created_at: new Date(), onboarding_answers: {},
  });
  await db.collection('users_man').insertOne({
    user_id: m, role: 'man', email: `${m}@t.test`, display_name: 'Ravi',
    timezone: 'Asia/Kolkata', created_at: new Date(), onboarding_answers: {},
  });

  const inv = await P.createInvitation({ senderUserId: w, receiverUserId: m, receiverEmail: `${m}@t.test` });
  const connectionId = await P.createConnectionForInvitation({
    senderUserId: w, receiverUserId: m, invitationId: inv.invitationId ?? inv.invitation_id,
  });

  const today = new Date().toISOString().slice(0, 10);
  await createEvent(w, {
    eventType: 'mood_logged', payload: { mood: 'low' },
    timestamp: `${today}T09:00:00.000Z`, source: 'manual',
  });

  const shared = await P.getSharedData({ connectionId, viewerUserId: m });
  assert.equal(shared.latestMood, null, 'the fallback must not bypass her permission');
  assert.equal(shared.shareMood, false);
});

test('messages go both ways and stay inside the connection', async (t) => {
  const { w, m, connectionId } = await pair(`msg_${Date.now()}`);
  t.after(() => wipe([w, m]));

  assert.ok(await P.sendMessageToConnection({ connectionId, senderUserId: w, message: 'hello' }));
  assert.ok(await P.sendMessageToConnection({ connectionId, senderUserId: m, message: 'hi back' }));

  assert.equal((await P.listMessagesForConnection(connectionId, w)).length, 2);
  assert.equal((await P.listMessagesForConnection(connectionId, m)).length, 2);

  const outsider = await P.listMessagesForConnection(connectionId, `test_psd_stranger_${Date.now()}`);
  assert.ok(!outsider || outsider.length === 0, 'a non-member must not read the thread');
});

test('teardown', async () => {
  await closeDb();
});
