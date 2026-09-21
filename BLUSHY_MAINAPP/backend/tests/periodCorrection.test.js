import test from 'node:test';
import assert from 'node:assert/strict';

import { createOrUpdatePeriodEntry, getPeriodEntries } from '../src/repositories/periodRepository.js';
import { calculatePeriodPredictions } from '../src/services/periodPredictionService.js';
import { closeDb, db } from '../src/utils/db.js';

/**
 * Logging a period start corrects the current cycle; it does not add another.
 *
 * The upsert matched an exact date only, so every correction appended a row.
 * Taken from a real device: nine entries built up -- 24th through 31st -- and
 * because the current cycle start is the most recent of them, correcting the
 * date to the 26th could never take effect. It read as the date being
 * rejected, while in fact all nine were stored.
 */
test('correcting the start date replaces the cluster, not adds to it', async (t) => {
  const uid = `test_period_fix_${Date.now()}`;
  const coll = 'user_period_logs_woman';

  t.after(async () => {
    try {
      await db.collection(coll).deleteMany({ user_id: uid });
      await db.collection('users_woman').deleteMany({ user_id: uid });
    } catch (_) {}
  });

  await db.collection('users_woman').insertOne({
    user_id: uid, role: 'woman', timezone: 'Asia/Kolkata',
    created_at: new Date('2026-06-01'),
  });

  // The nine entries observed on the device.
  for (const d of ['2026-08-04', '2026-08-11', '2026-08-18', '2026-08-24',
                   '2026-08-25', '2026-08-26', '2026-08-27', '2026-08-28',
                   '2026-08-31']) {
    await db.collection(coll).insertOne({
      user_id: uid, period_start_date: d, created_at: new Date(), updated_at: new Date(),
    });
  }

  const before = await calculatePeriodPredictions(uid, { referenceDate: '2026-08-31' });
  assert.equal(before.currentCycle.currentCycleDay, 1,
    'the reported state: the newest of the cluster wins');

  // She corrects it to the 26th.
  await createOrUpdatePeriodEntry(uid, { periodStartDate: '2026-08-26', source: 'sia_drawer' });

  const entries = (await getPeriodEntries(uid, 20)).map((e) => e.periodStartDate);
  assert.deepEqual(entries, ['2026-08-26', '2026-08-04'],
    'starts within a cycle of the correction are superseded');

  const after = await calculatePeriodPredictions(uid, { referenceDate: '2026-08-31' });
  assert.equal(after.currentCycle.cycleStartDate, '2026-08-26');
  assert.equal(after.currentCycle.currentCycleDay, 6);
});

test('a genuinely earlier cycle is left alone', async (t) => {
  const uid = `test_period_keep_${Date.now()}`;
  const coll = 'user_period_logs_woman';

  t.after(async () => {
    try {
      await db.collection(coll).deleteMany({ user_id: uid });
      await db.collection('users_woman').deleteMany({ user_id: uid });
    } catch (_) {}
  });

  await db.collection('users_woman').insertOne({
    user_id: uid, role: 'woman', timezone: 'Asia/Kolkata',
    created_at: new Date('2026-05-01'),
  });

  // 28 days apart: two real cycles, and logging the later one must not erase
  // the earlier. Cycle history is what every prediction is built from.
  await createOrUpdatePeriodEntry(uid, { periodStartDate: '2026-07-01' });
  await createOrUpdatePeriodEntry(uid, { periodStartDate: '2026-07-29' });

  const entries = (await getPeriodEntries(uid, 20)).map((e) => e.periodStartDate);
  assert.deepEqual(entries, ['2026-07-29', '2026-07-01']);
});

test('logging the same date twice stays idempotent', async (t) => {
  const uid = `test_period_same_${Date.now()}`;
  const coll = 'user_period_logs_woman';

  t.after(async () => {
    try {
      await db.collection(coll).deleteMany({ user_id: uid });
      await db.collection('users_woman').deleteMany({ user_id: uid });
    } catch (_) {}
  });

  await createOrUpdatePeriodEntry(uid, { periodStartDate: '2026-08-26' });
  await createOrUpdatePeriodEntry(uid, { periodStartDate: '2026-08-26' });

  const entries = await getPeriodEntries(uid, 20);
  assert.equal(entries.length, 1);
});

/**
 * Re-logging an older real start must clear a recent stray that sits beyond the
 * ±window. This is the perimenopause bug: a long cycle (22 days here) is longer
 * than minCycleLengthDays (18), so the ±window supersede cannot reach a stray
 * logged a day or two ago; it stays the newest row and currentCycleDay -- which
 * counts from the newest start -- stays stuck on Day 1/2, and re-logging the
 * real start never fixes it.
 */
test('re-logging an older real start clears a recent stray beyond the window', async (t) => {
  const uid = `test_period_stray_${Date.now()}`;
  const coll = 'user_period_logs_woman';

  t.after(async () => {
    try {
      await db.collection(coll).deleteMany({ user_id: uid });
      await db.collection('users_woman').deleteMany({ user_id: uid });
    } catch (_) {}
  });

  await db.collection('users_woman').insertOne({
    user_id: uid, role: 'woman', timezone: 'Asia/Kolkata',
    created_at: new Date('2026-06-01'),
  });

  // Real start on the 1st; a stray logged by mistake on the 23rd -- 22 days
  // later, further apart than minCycleLengthDays, so the ±window cannot catch it.
  await db.collection(coll).insertOne({
    user_id: uid, period_start_date: '2026-08-01', created_at: new Date(), updated_at: new Date(),
  });
  await db.collection(coll).insertOne({
    user_id: uid, period_start_date: '2026-08-23', created_at: new Date(), updated_at: new Date(),
  });

  const before = await calculatePeriodPredictions(uid, { referenceDate: '2026-08-23' });
  assert.equal(before.currentCycle.currentCycleDay, 1,
    'the reported state: the stray is newest, so the day counts from it');

  // She re-logs her real start through the tracker (the HTTP endpoint sets
  // supersedeNewer, marking this as the current cycle).
  await createOrUpdatePeriodEntry(uid, {
    periodStartDate: '2026-08-01', source: 'manual_tracker', supersedeNewer: true,
  });

  const entries = (await getPeriodEntries(uid, 20)).map((e) => e.periodStartDate);
  assert.deepEqual(entries, ['2026-08-01'],
    'the newer stray is cleared; the real start remains');

  const after = await calculatePeriodPredictions(uid, { referenceDate: '2026-08-23' });
  assert.equal(after.currentCycle.currentCycleDay, 23,
    'the day now counts from the real start');
});

/**
 * Onboarding history seeding is exempt: it writes several dated entries in one
 * pass -- possibly oldest last -- and must keep the newer ones.
 */
test('onboarding seeding keeps newer entries even when seeded oldest-last', async (t) => {
  const uid = `test_period_onb_${Date.now()}`;
  const coll = 'user_period_logs_woman';

  t.after(async () => {
    try {
      await db.collection(coll).deleteMany({ user_id: uid });
      await db.collection('users_woman').deleteMany({ user_id: uid });
    } catch (_) {}
  });

  await createOrUpdatePeriodEntry(uid, { periodStartDate: '2026-08-01', source: 'onboarding' });
  // Seeding an older date after a newer one must NOT clear the newer one.
  await createOrUpdatePeriodEntry(uid, { periodStartDate: '2026-06-01', source: 'onboarding' });

  const entries = (await getPeriodEntries(uid, 20)).map((e) => e.periodStartDate);
  assert.deepEqual(entries, ['2026-08-01', '2026-06-01'],
    'onboarding keeps every seeded date');
});

// The connection is opened on import and keeps the process alive; without this
// the file finishes its tests and then hangs, which stalls the whole suite.
test('teardown', async () => {
  await closeDb();
});
