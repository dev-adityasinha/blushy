import test from 'node:test';
import assert from 'node:assert/strict';

import { calculateMonthlyInsights } from '../src/services/monthlyInsightsService.js';
import { createEvent } from '../src/repositories/healthEventRepository.js';
import { closeDb, db } from '../src/utils/db.js';

/**
 * A check-in counts wherever it was recorded.
 *
 * The count came from `user_daily_logs_*` alone, and the app does not write
 * there — it records check-ins as health events, and `ApiCheckinService`, the
 * only client for the daily-log route, is called from nowhere. So the monthly
 * reflection reported "0 check-ins" however diligently someone logged.
 *
 * Found by driving 637 generated events through the pipeline and watching the
 * count come back 0.
 */
test('check-ins recorded as events are counted', async (t) => {
  const uid = `test_monthly_events_${Date.now()}`;

  t.after(async () => {
    try {
      await db.collection('health_events').deleteMany({ user_id: uid });
      await db.collection('users_woman').deleteMany({ user_id: uid });
    } catch (_) {}
  });

  await db.collection('users_woman').insertOne({
    user_id: uid, role: 'woman', timezone: 'Asia/Kolkata',
    created_at: new Date('2026-05-01'),
  });

  // Six separate days in the reporting month, logged the way the app logs.
  for (const day of ['05', '06', '07', '08', '09', '10']) {
    const r = await createEvent(uid, {
      eventType: 'mood_logged',
      payload: { mood: 'good' },
      timestamp: `2026-07-${day}T09:00:00.000Z`,
      source: 'manual',
    });
    assert.ok(r.ok, r.error);
  }

  const result = await calculateMonthlyInsights(uid, { referenceDate: '2026-08-15' });

  assert.equal(result.reportingMonth, '2026-07');
  assert.equal(result.metrics.checkinCount, 6,
    'events must count, or the reflection reports nothing for everyone');
  assert.equal(result.dataState, 'sufficient_data');
});

test('several events on one day are still one check-in', async (t) => {
  const uid = `test_monthly_oneday_${Date.now()}`;

  t.after(async () => {
    try {
      await db.collection('health_events').deleteMany({ user_id: uid });
      await db.collection('users_woman').deleteMany({ user_id: uid });
    } catch (_) {}
  });

  await db.collection('users_woman').insertOne({
    user_id: uid, role: 'woman', timezone: 'Asia/Kolkata',
    created_at: new Date('2026-05-01'),
  });

  // One morning's check-in writes a handful of events at once.
  for (const type of ['mood_logged', 'energy_logged', 'stress_logged']) {
    await createEvent(uid, {
      eventType: type,
      payload: type === 'mood_logged' ? { mood: 'okay' } : { level: 3 },
      timestamp: '2026-07-14T09:00:00.000Z',
      source: 'manual',
    });
  }

  const result = await calculateMonthlyInsights(uid, { referenceDate: '2026-08-15' });
  assert.equal(result.metrics.checkinCount, 1, 'counted by distinct date');
});

test('a month with a period but no check-ins is not a rhythm being built', async (t) => {
  const uid = `test_monthly_zero_${Date.now()}`;

  t.after(async () => {
    try {
      await db.collection('user_period_logs_woman').deleteMany({ user_id: uid });
      await db.collection('users_woman').deleteMany({ user_id: uid });
    } catch (_) {}
  });

  await db.collection('users_woman').insertOne({
    user_id: uid, role: 'woman', timezone: 'Asia/Kolkata',
    created_at: new Date('2026-05-01'),
  });
  await db.collection('user_period_logs_woman').insertOne({
    user_id: uid, period_start_date: '2026-07-06',
    created_at: new Date(), updated_at: new Date(),
  });

  const result = await calculateMonthlyInsights(uid, { referenceDate: '2026-08-15' });

  assert.equal(result.metrics.checkinCount, 0);
  assert.equal(result.dataState, 'no_data',
    'it read as learning_state, whose summary congratulates her for logging nothing');
  assert.doesNotMatch(result.reflection.summaryText, /began building your daily wellness rhythm/);
});

// The connection is opened on import and keeps the process alive.
test('teardown', async () => {
  await closeDb();
});
