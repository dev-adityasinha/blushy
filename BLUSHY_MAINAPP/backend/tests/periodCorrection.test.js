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

// The connection is opened on import and keeps the process alive; without this
// the file finishes its tests and then hangs, which stalls the whole suite.
test('teardown', async () => {
  await closeDb();
});
