import assert from 'node:assert/strict';
import test, { before, after } from 'node:test';
import { startTestServer, stopTestServer, api, createTestUser, getDb } from './helpers/testServer.js';

before(async () => { await startTestServer(); });
after(async () => { await stopTestServer(); });

/**
 * Stage state used to live in a process-level Map(): lost on restart, never
 * shared across instances. It now persists to Mongo, one document per user.
 */
test('postpartum: a check-in survives and reads back per user', async () => {
  const a = await createTestUser({ role: 'woman' });
  const b = await createTestUser({ role: 'woman' });

  await api('POST', '/api/postpartum/check-in', { token: a.token, body: { mood: 'low', painScore: 6, date: '2026-09-17' } });

  // Written to Mongo, not just memory.
  const db = getDb();
  const doc = await db.collection('postpartum_state').findOne({ user_id: a.userId });
  assert.ok(doc, 'no document was persisted');
  assert.equal(doc.state.checkins.length, 1);
  assert.equal(doc.state.checkins[0].mood, 'low');

  // Reads back through the API.
  const overviewA = await api('GET', '/api/postpartum/overview', { token: a.token });
  assert.equal(overviewA.status, 200);
  assert.equal((overviewA.body.data.recentCheckins || []).length, 1);

  // Another user is unaffected — no shared bucket.
  const overviewB = await api('GET', '/api/postpartum/overview', { token: b.token });
  assert.equal((overviewB.body.data.recentCheckins || []).length, 0);
});

test('postpartum: calibration persists', async () => {
  const a = await createTestUser({ role: 'woman' });
  await api('POST', '/api/postpartum/calibrate', { token: a.token, body: { deliveryDate: '2026-08-01', deliveryType: 'cesarean' } });
  const db = getDb();
  const doc = await db.collection('postpartum_state').findOne({ user_id: a.userId });
  assert.equal(doc.state.profile.deliveryType, 'cesarean');
  assert.equal(doc.state.profile.deliveryDate, '2026-08-01');
});

test('perimenopause: a check-in and treatment persist per user', async () => {
  const a = await createTestUser({ role: 'woman' });
  const b = await createTestUser({ role: 'woman' });

  await api('POST', '/api/perimenopause/checkin', { token: a.token, body: { sleepQuality: 'insomnia', botherLevel: 4 } });
  await api('POST', '/api/perimenopause/treatment', { token: a.token, body: { name: 'HRT patch', category: 'hrt' } });

  const db = getDb();
  const doc = await db.collection('perimenopause_state').findOne({ user_id: a.userId });
  assert.ok(doc, 'no perimenopause document persisted');
  assert.equal(doc.state.checkins.length, 1);
  assert.equal(doc.state.checkins[0].sleepQuality, 'insomnia');
  assert.equal(doc.state.treatments.length, 1);

  const ov = await api('GET', '/api/perimenopause/overview', { token: a.token });
  assert.equal(ov.status, 200);
  assert.equal(ov.body.data.todayCheckin.sleepQuality, 'insomnia');
  assert.ok(ov.body.data.treatments.some((t) => t.name === 'HRT patch'));

  // Isolation: b never sees a's data.
  const ovB = await api('GET', '/api/perimenopause/overview', { token: b.token });
  assert.equal(ovB.status, 200);
  assert.equal(ovB.body.data.todayCheckin.sleepQuality, undefined);
});

test('perimenopause: an empty user still gets seeded example treatments', async () => {
  const a = await createTestUser({ role: 'woman' });
  const ov = await api('GET', '/api/perimenopause/overview', { token: a.token });
  // Behaviour preserved from the Map version: no data -> seeded examples shown.
  assert.ok((ov.body.data.treatments || []).length >= 1);
  assert.ok((ov.body.data.questions || []).length >= 1);
});
