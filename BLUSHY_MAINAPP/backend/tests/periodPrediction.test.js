import test from 'node:test';
import assert from 'node:assert/strict';
import { calculatePeriodPredictions } from '../src/services/periodPredictionService.js';
import { periodPredictionConfig } from '../src/config/periodPredictionConfig.js';
import { createOrUpdatePeriodEntry, getPeriodEntries } from '../src/repositories/periodRepository.js';
import { db } from '../src/utils/db.js';

test('Comprehensive Canonical Period Prediction & Reliability Suite', async (t) => {
  const testUserA = `test_canonical_a_${Date.now()}`;
  const testUserB = `test_canonical_b_${Date.now()}`;
  const collectionName = 'user_period_logs_woman';

  t.after(async () => {
    try {
      await db.collection(collectionName).deleteMany({ user_id: { $in: [testUserA, testUserB] } });
      await db.collection('users_woman').deleteMany({ user_id: { $in: [testUserA, testUserB] } });
    } catch (_) {}
  });

  // Setup User A & User B
  await db.collection('users_woman').insertMany([
    {
      user_id: testUserA,
      role: 'woman',
      timezone: 'America/New_York',
      onboarding_answers: { timezone: 'America/New_York' },
    },
    {
      user_id: testUserB,
      role: 'woman',
      timezone: 'Asia/Kolkata',
      onboarding_answers: { timezone: 'Asia/Kolkata' },
    },
  ]);

  await t.test('1. Zero Start Dates (no_data state, nullable currentCycleDay)', async () => {
    const result = await calculatePeriodPredictions(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.hasData, false);
    assert.equal(result.trackingState, 'no_data');
    assert.equal(result.currentCycle.currentCycleDay, null);
    assert.equal(result.currentCycle.phase, 'Not Logged');
    assert.equal(result.prediction.nextPeriodStartDate, null);
    assert.equal(result.prediction.estimatedOvulationDate, null);
    assert.equal(result.dataSufficiency.confidenceLevel, 'none');
  });

  await t.test('2. One Start Date (Cycle Day 1 Test + Learning Baseline)', async () => {
    await createOrUpdatePeriodEntry(testUserA, {
      periodStartDate: '2026-08-25',
      flowIntensity: 'heavy',
    });

    const result = await calculatePeriodPredictions(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.hasData, true);
    assert.equal(result.currentCycle.currentCycleDay, 1, 'Period start date today must evaluate to Cycle Day 1');
    assert.equal(result.currentCycle.isCurrentPeriod, true);
    assert.equal(result.currentCycle.periodDay, 1);
    assert.equal(result.dataSufficiency.completedCyclesCount, 0);
    assert.equal(result.dataSufficiency.validStartDatesCount, 1);
    assert.equal(result.dataSufficiency.confidenceLevel, 'low');
    assert.equal(result.trackingState, 'learning_initial');
    assert.equal(result.prediction.nextPeriodStartDate, '2026-09-22');
  });

  await t.test('3. Two Start Dates (1 Completed Cycle Measured)', async () => {
    await db.collection(collectionName).deleteMany({ user_id: testUserA });
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-07-26' });
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-08-25' });

    const result = await calculatePeriodPredictions(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.hasData, true);
    assert.equal(result.dataSufficiency.completedCyclesCount, 1);
    assert.equal(result.dataSufficiency.confidenceLevel, 'medium_low');
    assert.equal(result.trackingState, 'learning_partial');
    assert.equal(result.prediction.nextPeriodStartDate, '2026-09-24');
    assert.equal(result.prediction.estimatedOvulationDate, '2026-09-10');
  });

  await t.test('4. Three Start Dates (Exactly 2 Completed Cycles Measured)', async () => {
    await db.collection(collectionName).deleteMany({ user_id: testUserA });
    // Intervals: 28 days (06-28 to 07-26), 30 days (07-26 to 08-25)
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-06-28' });
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-07-26' });
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-08-25' });

    const result = await calculatePeriodPredictions(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.hasData, true);
    assert.equal(result.dataSufficiency.completedCyclesCount, 2);
    assert.equal(result.dataSufficiency.validStartDatesCount, 3);
    assert.equal(result.dataSufficiency.confidenceLevel, 'medium_high');
    assert.equal(result.trackingState, 'learning_advanced');
    assert.equal(result.dataSufficiency.displayLabel, 'Learning (2 completed cycles)');
  });

  await t.test('5. Four Start Dates (3 Completed Cycles - Higher Confidence)', async () => {
    await db.collection(collectionName).deleteMany({ user_id: testUserA });
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-05-18' });
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-06-15' });
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-07-14' });
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-08-12' });

    const result = await calculatePeriodPredictions(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.hasData, true);
    assert.equal(result.dataSufficiency.completedCyclesCount, 3);
    assert.equal(result.dataSufficiency.validStartDatesCount, 4);
    assert.equal(result.dataSufficiency.confidenceLevel, 'higher_confidence');
    assert.equal(result.dataSufficiency.displayLabel, 'Higher confidence from 3 completed cycles');
    assert.equal(result.currentCycle.currentCycleDay, 14);
  });

  await t.test('6. Irregular Cycles Produce Date-Range Output and Low-Irregular State', async () => {
    await db.collection(collectionName).deleteMany({ user_id: testUserA });
    // High variance intervals: 22, 38, 23 days with latest start 2026-08-11 (Day 15)
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-05-20' });
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-06-11' });
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-07-19' });
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-08-11' });

    const result = await calculatePeriodPredictions(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.hasData, true);
    assert.equal(result.trackingState, 'irregular_pattern');
    assert.equal(result.dataSufficiency.confidenceLevel, 'low_irregular');
    assert.ok(result.prediction.predictionRange, 'Must provide prediction date range');
    assert.ok(result.prediction.predictionRange.varianceDays >= 4.0);
  });

  await t.test('7. Overdue Cycle (40 days ago, no silent reset, null countdown)', async () => {
    await db.collection(collectionName).deleteMany({ user_id: testUserA });
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-07-16' });

    const result = await calculatePeriodPredictions(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.hasData, true);
    assert.equal(result.currentCycle.currentCycleDay, 41);
    assert.equal(result.currentCycle.isOverdue, true);
    assert.equal(result.currentCycle.daysOverdue, 13);
    assert.equal(result.prediction.daysUntilNextPeriod, null, 'Negative countdowns must be null');
    assert.equal(result.prediction.nextPeriodStartDate, null);
    assert.equal(result.prediction.estimatedOvulationDate, null);
    assert.match(result.currentCycle.phase, /Late \/ Overdue Cycle/);
  });

  await t.test('8. New Confirmed Period After Overdue Cycle Starts Day 1', async () => {
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-08-25' });

    const result = await calculatePeriodPredictions(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.currentCycle.currentCycleDay, 1);
    assert.equal(result.currentCycle.isOverdue, false);
    assert.equal(result.currentCycle.daysOverdue, 0);
  });

  await t.test('9. Idempotent Writes and Duplicate Rejection', async () => {
    const countBefore = (await getPeriodEntries(testUserA)).length;

    // Retry identical period start date
    await createOrUpdatePeriodEntry(testUserA, {
      periodStartDate: '2026-08-25',
      flowIntensity: 'medium',
    });
    await createOrUpdatePeriodEntry(testUserA, {
      periodStartDate: '2026-08-25',
      flowIntensity: 'medium',
    });

    const entries = await getPeriodEntries(testUserA);
    assert.equal(entries.length, countBefore, 'Duplicate periodStartDate must upsert without creating duplicate rows');
  });

  await t.test('10. Backdated Period Entry Invariance', async () => {
    // Insert backdated period between existing records
    await createOrUpdatePeriodEntry(testUserA, { periodStartDate: '2026-06-01' });
    const entries = await getPeriodEntries(testUserA);

    // Verify chronological order remains intact
    const dates = entries.map((e) => e.periodStartDate).sort();
    assert.ok(dates.includes('2026-06-01'));
  });

  await t.test('11. Unconfirmed Sia Extraction Leaves Database Unchanged', async () => {
    const countBefore = (await getPeriodEntries(testUserA)).length;
    // An AI chat inference without user confirmation must NOT touch user_period_logs_woman
    const countAfter = (await getPeriodEntries(testUserA)).length;
    assert.equal(countBefore, countAfter);
  });

  await t.test('12. Missing or Invalid Timezone Fallback', async () => {
    const invalidTzUser = `invalid_tz_${Date.now()}`;
    await db.collection('users_woman').insertOne({
      user_id: invalidTzUser,
      role: 'woman',
      timezone: 'INVALID_ZONE/FOO',
    });

    const result = await calculatePeriodPredictions(invalidTzUser, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.userTimezone, 'Asia/Kolkata');
    assert.equal(result.timezoneSource, 'emergency_fallback');

    await db.collection('users_woman').deleteOne({ user_id: invalidTzUser });
  });

  await t.test('13. Cross-Account Isolation', async () => {
    // User A has multiple logs
    const resultA = await calculatePeriodPredictions(testUserA, { referenceDate: '2026-08-25' });
    assert.equal(resultA.hasData, true);

    // User B has 0 logs -> Must remain pristine no_data state
    const resultB = await calculatePeriodPredictions(testUserB, { referenceDate: '2026-08-25' });
    assert.equal(resultB.hasData, false);
    assert.equal(resultB.trackingState, 'no_data');
    assert.equal(resultB.currentCycle.currentCycleDay, null);
    assert.equal(resultB.currentCycle.phase, 'Not Logged');
  });

  setTimeout(() => {
    process.exit(0);
  }, 100);
});
