import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

import { startTestServer, stopTestServer, createTestUser, api, getDb } from './helpers/testServer.js';

/**
 * Her life stage reaches her partner only when she says so.
 *
 * The partner app read `partnerUser.lifeStage` off the shared-data payload and
 * fell back to "everydayWellness" when it was missing -- which was always,
 * because the payload never carried it. So a partner of someone in her third
 * trimester was being coached as though she were having an ordinary week.
 *
 * It is carried now, behind `shareOnboarding`. That is the right key: a stage
 * says what she is going through -- pregnancy, postpartum, trying to conceive
 * -- rather than how she is feeling today, and it sits with the rest of her
 * onboarding answers.
 *
 * The read happens behind the switch rather than being filtered after it, so
 * when she has not agreed the query is never made.
 */

before(async () => { await startTestServer(); });
after(async () => { await stopTestServer(); });

async function connectedPair(permissions) {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = randomUUID();

  await getDb().collection('partner_connections').insertOne({
    connection_id: connectionId,
    user_a_id: woman.userId,
    user_b_id: man.userId,
    permission_owner_user_id: woman.userId,
    permissions,
    status: 'active',
    created_at: new Date(),
    updated_at: new Date(),
  });

  return { woman, man, connectionId };
}

/// Puts a stage where `getLifeStageState` reads it.
async function setStage(userId, stage) {
  await getDb().collection('user_life_stage').updateOne(
    { user_id: userId },
    { $set: { user_id: userId, life_stage: stage, updated_at: new Date() } },
    { upsert: true },
  );
}

const sharedFor = async (actor, connectionId) => {
  const res = await api('GET', `/partner/connections/${connectionId}/shared-data`, {
    token: actor.token,
  });
  assert.equal(res.status, 200, JSON.stringify(res.body));
  return res.body.data ?? res.body;
};

test('with onboarding shared, her stage reaches him', async () => {
  const { woman, man, connectionId } = await connectedPair({ shareOnboarding: true });
  await setStage(woman.userId, 'pregnancy');

  const data = await sharedFor(man, connectionId);
  assert.equal(data.shareOnboarding, true);
  assert.equal(data.lifeStage, 'pregnancy');
});

test('without it, the stage is null rather than a default', async () => {
  // "everydayWellness" was the old fallback, and it is a claim about her.
  const { woman, man, connectionId } = await connectedPair({ shareOnboarding: false });
  await setStage(woman.userId, 'pregnancy');

  const data = await sharedFor(man, connectionId);
  assert.equal(data.shareOnboarding, false);
  assert.equal(data.lifeStage, null);
});

test('the flag tells "not chosen" apart from "not shared"', async () => {
  // Two different things, and only one of them is about privacy.
  const { man, connectionId } = await connectedPair({ shareOnboarding: true });

  const data = await sharedFor(man, connectionId);
  assert.equal(data.shareOnboarding, true, 'she is sharing');
  assert.equal(data.lifeStage, null, 'she has simply not chosen one');
});

test('sharing her stage does not open anything else', async () => {
  // `shareOnboarding` is one key among thirteen. Turning it on must not carry
  // her mood or her cycle along with it.
  const { woman, man, connectionId } = await connectedPair({ shareOnboarding: true });
  await setStage(woman.userId, 'postpartum');

  const data = await sharedFor(man, connectionId);
  assert.equal(data.lifeStage, 'postpartum');
  assert.equal(data.shareMood, false);
  assert.equal(data.shareCycle, false);
  assert.equal(data.latestMood, null);
  assert.equal(data.cycleInfo, null);
});

test('an unreadable stage does not take the rest of the payload down', async () => {
  // A stage that cannot be read is simply not shown; failing the whole
  // response over it would blank the cycle and mood she did agree to.
  const { woman, man, connectionId } = await connectedPair({ shareOnboarding: true });
  await getDb().collection('user_life_stage').updateOne(
    { user_id: woman.userId },
    { $set: { user_id: woman.userId, life_stage: 12345 } },
    { upsert: true },
  );

  const data = await sharedFor(man, connectionId);
  assert.ok(data, 'the payload still arrives');
  assert.equal(typeof data.partnerName, 'string');
});
