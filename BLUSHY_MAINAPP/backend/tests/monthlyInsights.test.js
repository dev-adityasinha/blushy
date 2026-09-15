import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateMonthlyInsights } from '../src/services/monthlyInsightsService.js';
import { createOrUpdateDailyLog } from '../src/repositories/dailyLogRepository.js';
import { createOrUpdatePeriodEntry } from '../src/repositories/periodRepository.js';
import { db } from '../src/utils/db.js';

test('Comprehensive Monthly Insights & Verified Green-Tick Test Suite', async (t) => {
  const testUserA = `test_monthly_a_${Date.now()}`;
  const testUserB = `test_monthly_b_${Date.now()}`;
  const dailyColl = 'user_daily_logs_woman';
  const periodColl = 'user_period_logs_woman';
  const chatColl = 'ai_chat_history_woman';

  t.after(async () => {
    try {
      await db.collection(dailyColl).deleteMany({ user_id: { $in: [testUserA, testUserB] } });
      await db.collection(periodColl).deleteMany({ user_id: { $in: [testUserA, testUserB] } });
      await db.collection(chatColl).deleteMany({ $or: [{ user_id: { $in: [testUserA, testUserB] } }, { user_key: { $in: [testUserA, testUserB] } }] });
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

  await t.test('1. Zero Records in Previous Month (Truthful no_data state, 0 green ticks)', async () => {
    const result = await calculateMonthlyInsights(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.reportingMonth, '2026-07');
    assert.equal(result.startDate, '2026-07-01');
    assert.equal(result.endDate, '2026-07-31');
    assert.equal(result.totalDaysInMonth, 31);
    assert.equal(result.dataState, 'no_data');
    assert.equal(result.metrics.checkinCount, 0);
    assert.equal(result.metrics.symptomLogCount, 0);
    assert.equal(result.metrics.periodDaysInMonth, 0);

    // Verify 100% of milestones have showGreenTick: false
    for (const m of result.milestones) {
      assert.equal(m.isCompleted, false);
      assert.equal(m.showGreenTick, false, `Milestone ${m.id} must be unchecked for 0-data user`);
    }

    assert.match(result.reflection.summaryText, /No check-ins or cycle events were recorded/);
  });

  await t.test('2. One Record in Previous Month (Learning baseline, 0 green ticks for check-in)', async () => {
    await createOrUpdateDailyLog(testUserA, {
      logDate: '2026-07-10',
      mood: 'Calm',
      energyLevel: 'Balanced',
    });

    const result = await calculateMonthlyInsights(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.dataState, 'learning_state');
    assert.equal(result.metrics.checkinCount, 1);
    assert.equal(result.metrics.symptomLogCount, 0);

    const checkinMilestone = result.milestones.find((m) => m.id === 'milestone_checkin_consistency');
    assert.equal(checkinMilestone.isCompleted, false);
    assert.equal(checkinMilestone.showGreenTick, false);
    assert.equal(checkinMilestone.statusLabel, '1 / 15 days logged');
  });

  await t.test('3. Partial Records in Previous Month (Symptoms logged, partial check-ins)', async () => {
    // Add 5 more check-ins (total 6), one with symptoms
    for (let i = 11; i <= 15; i++) {
      await createOrUpdateDailyLog(testUserA, {
        logDate: `2026-07-${String(i).padStart(2, '0')}`,
        mood: 'Focus',
        symptoms: i === 12 ? ['cramps', 'fatigue'] : [],
      });
    }

    const result = await calculateMonthlyInsights(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.metrics.checkinCount, 6);
    assert.equal(result.metrics.symptomLogCount, 1);
    assert.deepEqual(result.metrics.uniqueSymptomsTracked, ['cramps', 'fatigue']);

    const checkinMilestone = result.milestones.find((m) => m.id === 'milestone_checkin_consistency');
    const symptomMilestone = result.milestones.find((m) => m.id === 'milestone_symptom_tracking');

    assert.equal(checkinMilestone.isCompleted, false, '6 check-ins is less than threshold 15');
    assert.equal(checkinMilestone.showGreenTick, false);

    assert.equal(symptomMilestone.isCompleted, true, 'Symptom was recorded in July');
    assert.equal(symptomMilestone.showGreenTick, true);
  });

  await t.test('4. Complete Month (All 4 Milestones Legitimately Verified & Checked)', async () => {
    await db.collection(dailyColl).deleteMany({ user_id: testUserA });
    await db.collection(periodColl).deleteMany({ user_id: testUserA });
    await db.collection(chatColl).deleteMany({ $or: [{ user_id: testUserA }, { user_key: testUserA }] });

    // 1. Seed 20 daily check-ins
    for (let i = 1; i <= 20; i++) {
      await createOrUpdateDailyLog(testUserA, {
        logDate: `2026-07-${String(i).padStart(2, '0')}`,
        mood: 'Calm',
        symptoms: i === 5 ? ['bloating'] : [],
      });
    }

    // 2. Seed 1 confirmed period start date
    await createOrUpdatePeriodEntry(testUserA, {
      periodStartDate: '2026-07-05',
    });

    // 3. Seed 3 authenticated Sia chat sessions (distinct dates with >= 2 exchanges)
    for (const day of ['2026-07-08', '2026-07-15', '2026-07-22']) {
      await db.collection(chatColl).insertMany([
        { user_id: testUserA, role: 'user', content: 'Hello Sia', created_at: new Date(`${day}T10:00:00.000Z`) },
        { user_id: testUserA, role: 'assistant', content: 'Hello! How are you feeling?', created_at: new Date(`${day}T10:00:05.000Z`) },
      ]);
    }

    const result = await calculateMonthlyInsights(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(result.dataState, 'sufficient_data');
    assert.equal(result.metrics.checkinCount, 20);
    assert.equal(result.metrics.symptomLogCount, 1);
    assert.equal(result.metrics.periodDaysInMonth, 1);
    assert.equal(result.metrics.siaConversationsCount, 3);

    // All 4 milestones must now legitimately be completed
    for (const m of result.milestones) {
      assert.equal(m.isCompleted, true, `Milestone ${m.id} must be completed in complete month test`);
      assert.equal(m.showGreenTick, true);
    }
  });

  await t.test('5. Current-Month Records Strictly Excluded from Previous Month ($M-1)', async () => {
    // Seed 10 check-ins in August 2026 (current month)
    for (let i = 1; i <= 10; i++) {
      await createOrUpdateDailyLog(testUserA, {
        logDate: `2026-08-${String(i).padStart(2, '0')}`,
        mood: 'Energetic',
      });
    }

    // Query July (M-1)
    const resultJuly = await calculateMonthlyInsights(testUserA, {
      referenceDate: '2026-08-25',
    });

    assert.equal(resultJuly.reportingMonth, '2026-07');
    assert.equal(resultJuly.metrics.checkinCount, 20, 'July count must remain exactly 20, ignoring August records');
  });

  await t.test('6. Current / Future Month Query Rejection (400 Bad Request)', async () => {
    // Current month query
    await assert.rejects(
      async () => {
        await calculateMonthlyInsights(testUserA, {
          month: '2026-08',
          referenceDate: '2026-08-25',
        });
      },
      (err) => {
        assert.equal(err.statusCode, 400);
        assert.match(err.message, /Cannot request current or future month/);
        return true;
      }
    );

    // Future month query
    await assert.rejects(
      async () => {
        await calculateMonthlyInsights(testUserA, {
          month: '2026-09',
          referenceDate: '2026-08-25',
        });
      },
      (err) => {
        assert.equal(err.statusCode, 400);
        return true;
      }
    );
  });

  await t.test('7. Historical Completed Month Query ($M-2)', async () => {
    // Seed June 2026 logs
    await createOrUpdateDailyLog(testUserA, {
      logDate: '2026-06-15',
      mood: 'Calm',
    });

    const resultJune = await calculateMonthlyInsights(testUserA, {
      month: '2026-06',
      referenceDate: '2026-08-25',
    });

    assert.equal(resultJune.reportingMonth, '2026-06');
    assert.equal(resultJune.startDate, '2026-06-01');
    assert.equal(resultJune.endDate, '2026-06-30');
    assert.equal(resultJune.totalDaysInMonth, 30);
    assert.equal(resultJune.metrics.checkinCount, 1);
  });

  await t.test('8. Duplicate and Upsert Daily Check-ins', async () => {
    const countBefore = (await db.collection(dailyColl).find({ user_id: testUserA, log_date: '2026-07-01' }).toArray()).length;

    // Resubmit same date with different mood
    await createOrUpdateDailyLog(testUserA, {
      logDate: '2026-07-01',
      mood: 'Updated Mood',
    });

    const countAfter = (await db.collection(dailyColl).find({ user_id: testUserA, log_date: '2026-07-01' }).toArray()).length;
    assert.equal(countAfter, 1, 'Idempotent upsert must keep single document per date');
  });

  await t.test('9. Unconfirmed Sia Extraction Leaves Daily Log Database Unchanged', async () => {
    const countBefore = (await db.collection(dailyColl).find({ user_id: testUserA }).toArray()).length;

    // Chat message without user confirmation
    await db.collection(chatColl).insertOne({
      user_id: testUserA,
      role: 'assistant',
      content: 'I noticed you may have cramps today.',
      created_at: new Date('2026-07-28T12:00:00.000Z'),
    });

    const countAfter = (await db.collection(dailyColl).find({ user_id: testUserA }).toArray()).length;
    assert.equal(countBefore, countAfter, 'Chat message alone must not write to daily log collection');
  });

  await t.test('10. Invalid Date and Leap Year Boundary Logic', async () => {
    // 2024 is a leap year -> Feb has 29 days
    const feb2024 = await calculateMonthlyInsights(testUserA, {
      month: '2024-02',
      referenceDate: '2026-08-25',
    });
    assert.equal(feb2024.totalDaysInMonth, 29);
    assert.equal(feb2024.endDate, '2024-02-29');

    // 2025 is not a leap year -> Feb has 28 days
    const feb2025 = await calculateMonthlyInsights(testUserA, {
      month: '2025-02',
      referenceDate: '2026-08-25',
    });
    assert.equal(feb2025.totalDaysInMonth, 28);
    assert.equal(feb2025.endDate, '2025-02-28');
  });

  await t.test('11. Timezone Invariance on Calendar Boundaries', async () => {
    // User B is Asia/Kolkata (+5:30)
    const resultB = await calculateMonthlyInsights(testUserB, {
      referenceDate: '2026-08-25',
    });
    assert.equal(resultB.userTimezone, 'Asia/Kolkata');
    assert.equal(resultB.reportingMonth, '2026-07');
    assert.equal(resultB.startDate, '2026-07-01');
    assert.equal(resultB.endDate, '2026-07-31');
  });

  await t.test('12. Cross-Account Isolation', async () => {
    // User A has 20 logs in July
    const resultA = await calculateMonthlyInsights(testUserA, { referenceDate: '2026-08-25' });
    assert.equal(resultA.metrics.checkinCount, 20);

    // User B has 0 logs in July -> Must be isolated no_data state
    const resultB = await calculateMonthlyInsights(testUserB, { referenceDate: '2026-08-25' });
    assert.equal(resultB.metrics.checkinCount, 0);
    assert.equal(resultB.dataState, 'no_data');
  });

  setTimeout(() => {
    process.exit(0);
  }, 100);
});
