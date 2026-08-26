import http from 'node:http';
import assert from 'node:assert';
import { randomUUID } from 'node:crypto';
import jwt from 'jsonwebtoken';
import app from '../src/app.js';
import { db } from '../src/utils/db.js';
import { createOrUpdatePeriodEntry, getPeriodEntries, deletePeriodEntry } from '../src/repositories/periodRepository.js';
import { calculatePeriodPredictions } from '../src/services/periodPredictionService.js';
import { saveOnboardingAnswers } from '../src/repositories/userRepository.js';
import { env } from '../src/utils/env.js';

const JWT_SECRET = env.jwtSecret || 'blushy-super-secret-jwt-key-for-development-mode-only';

function generateToken(userId, role = 'woman') {
  return jwt.sign(
    { userId, role, aud: 'blushy_mobile_app', iss: 'blushy_api' },
    JWT_SECRET,
    { expiresIn: '1h' }
  );
}

function request(server, options, body = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        let parsed = null;
        try {
          parsed = data ? JSON.parse(data) : null;
        } catch {
          parsed = data;
        }
        resolve({ status: res.statusCode, headers: res.headers, body: parsed });
      });
    });
    req.on('error', reject);
    if (body) {
      req.write(typeof body === 'string' ? body : JSON.stringify(body));
    }
    req.end();
  });
}

async function runPeriodHistoryE2ESuite() {
  console.log('======================================================================');
  console.log('🌸 RUNNING PERIOD HISTORY & MULTI-CYCLE PREDICTION E2E SUITE');
  console.log('======================================================================\n');

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;

  const testWomanId = `test_woman_${randomUUID().slice(0, 8)}`;
  const womanToken = generateToken(testWomanId, 'woman');

  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${womanToken}`,
  };

  try {
    // 0. Seed test user in users_woman
    await db.collection('users_woman').insertOne({
      user_id: testWomanId,
      email: `${testWomanId}@example.test`,
      display_name: 'Test Woman',
      role: 'woman',
      onboarding_answers: {
        preferred_name: 'Test Woman',
        life_stage: 'reproductiveYears',
        cycle_length: '28',
      },
      created_at: new Date(),
      updated_at: new Date(),
    });
    console.log(`[Setup] Disposable test user created: ${testWomanId} on port ${port}`);

    // --- TEST 1: Initial Empty State (0 Period Entries) ---
    console.log('\n[1/8] Testing Initial Empty State (0 Period Entries)...');
    const pred1 = await calculatePeriodPredictions(testWomanId);
    assert.strictEqual(pred1.hasData, false, 'Expected hasData: false when no period is logged');
    assert.strictEqual(pred1.currentCycleDay, 0, 'Expected currentCycleDay: 0');
    assert.strictEqual(pred1.confidence, 'none', 'Expected confidence: none');
    console.log('  ✅ PASSED: Empty state cleanly returns hasData: false and confidence: none');

    // --- TEST 2: Validation Guard Tests (400 Bad Request) ---
    console.log('\n[2/8] Testing Validation Guards (400 Bad Request)...');
    
    // 2a. Missing periodStartDate
    const res2a = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/period/entries',
      method: 'POST',
      headers,
    }, {});
    assert.strictEqual(res2a.status, 400, 'Missing start date must return 400');
    console.log('  ✅ PASSED: Missing periodStartDate rejected with 400');

    // 2b. Impossible calendar date (2026-02-31)
    const res2b = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/period/entries',
      method: 'POST',
      headers,
    }, { periodStartDate: '2026-02-31' });
    assert.strictEqual(res2b.status, 400, 'Impossible calendar date must return 400');
    console.log('  ✅ PASSED: Impossible calendar date (2026-02-31) rejected with 400');

    // 2c. Far future date
    const res2c = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/period/entries',
      method: 'POST',
      headers,
    }, { periodStartDate: '2030-01-01' });
    assert.strictEqual(res2c.status, 400, 'Future date must return 400');
    console.log('  ✅ PASSED: Future date rejected with 400');

    // 2d. End date before start date
    const res2d = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/period/entries',
      method: 'POST',
      headers,
    }, { periodStartDate: '2026-05-10', periodEndDate: '2026-05-05' });
    assert.strictEqual(res2d.status, 400, 'End date before start date must return 400');
    console.log('  ✅ PASSED: periodEndDate before periodStartDate rejected with 400');

    // 2e. Invalid flow intensity
    const res2e = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/period/entries',
      method: 'POST',
      headers,
    }, { periodStartDate: '2026-05-10', flowIntensity: 'extreme' });
    assert.strictEqual(res2e.status, 400, 'Invalid flowIntensity must return 400');
    console.log('  ✅ PASSED: Invalid flowIntensity rejected with 400');

    // --- TEST 3: Logging 1st Period Entry ---
    console.log('\n[3/8] Testing Logging 1st Period Entry (Baseline Projection)...');
    const res3 = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/period/entries',
      method: 'POST',
      headers,
    }, {
      periodStartDate: '2026-05-01',
      periodEndDate: '2026-05-06',
      flowIntensity: 'medium',
      source: 'manual_tracker',
    });
    assert.strictEqual(res3.status, 200, 'Logging period entry must return 200');
    assert.strictEqual(res3.body.data.periodStartDate, '2026-05-01');
    assert.strictEqual(res3.body.data.flowIntensity, 'medium');

    const pred3 = await calculatePeriodPredictions(testWomanId, new Date('2026-05-15T00:00:00Z'));
    assert.strictEqual(pred3.hasData, true);
    assert.strictEqual(pred3.currentCycleDay, 15);
    assert.strictEqual(pred3.cycleLengthDays, 28);
    assert.strictEqual(pred3.confidence, 'medium');
    console.log('  ✅ PASSED: 1st period logged and baseline 28-day prediction verified (Day 15, Confidence: medium)');

    // --- TEST 4: Logging 2nd Period Entry (1 Measured Completed Cycle) ---
    console.log('\n[4/8] Testing 2nd Period Entry (1 Measured Cycle Interval)...');
    // Log next period 30 days later: 2026-05-31
    await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/period/entries',
      method: 'POST',
      headers,
    }, { periodStartDate: '2026-05-31', flowIntensity: 'heavy' });

    const pred4 = await calculatePeriodPredictions(testWomanId, new Date('2026-06-10T00:00:00Z'));
    assert.strictEqual(pred4.completedCyclesCount, 1);
    assert.strictEqual(pred4.cycleLengthDays, 30, 'Cycle length should adapt to measured 30-day interval');
    assert.strictEqual(pred4.confidence, 'medium_high');
    console.log('  ✅ PASSED: 2nd period interval calculated as 30 days (Confidence: medium_high)');

    // --- TEST 5: Logging 3rd & 4th Period Entries (3 Completed Cycles - Weighted Moving Average) ---
    console.log('\n[5/8] Testing 3rd & 4th Period Entries (Weighted Multi-Cycle Average)...');
    // Interval 2: 2026-05-31 -> 2026-06-29 (29 days)
    await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/period/entries',
      method: 'POST',
      headers,
    }, { periodStartDate: '2026-06-29', flowIntensity: 'medium' });

    // Interval 3: 2026-06-29 -> 2026-07-28 (29 days)
    await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/period/entries',
      method: 'POST',
      headers,
    }, { periodStartDate: '2026-07-28', flowIntensity: 'medium' });

    const pred5 = await calculatePeriodPredictions(testWomanId, new Date('2026-08-10T00:00:00Z'));
    assert.strictEqual(pred5.completedCyclesCount, 3);
    assert.deepStrictEqual(pred5.historicalIntervals, [30, 29, 29]);
    // Weighted avg: 29*0.5 + 29*0.3 + 30*0.2 = 14.5 + 8.7 + 6.0 = 29.2 -> 29
    assert.strictEqual(pred5.cycleLengthDays, 29);
    assert.strictEqual(pred5.confidence, 'maximum');
    assert.ok(pred5.predictionWindow.earliestDate, 'Prediction window earliestDate should be present');
    assert.ok(pred5.predictionWindow.latestDate, 'Prediction window latestDate should be present');
    console.log('  ✅ PASSED: 3 completed cycles calculated weighted average of 29 days (Confidence: maximum, Variance calculated)');

    // --- TEST 6: Period History List & Deletion API ---
    console.log('\n[6/8] Testing GET /period/entries and DELETE /period/entries/:id...');
    const res6Get = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/period/entries',
      method: 'GET',
      headers,
    });
    assert.strictEqual(res6Get.status, 200);
    assert.strictEqual(res6Get.body.data.count, 4);
    assert.strictEqual(res6Get.body.data.entries[0].periodStartDate, '2026-07-28');
    assert.strictEqual(res6Get.body.data.entries[3].periodStartDate, '2026-05-01');

    const entryToDelete = res6Get.body.data.entries[0];
    const res6Del = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: `/period/entries/${entryToDelete.id}`,
      method: 'DELETE',
      headers,
    });
    assert.strictEqual(res6Del.status, 200);

    const res6AfterDel = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/period/entries',
      method: 'GET',
      headers,
    });
    assert.strictEqual(res6AfterDel.body.data.count, 3);
    assert.strictEqual(res6AfterDel.body.data.entries[0].periodStartDate, '2026-06-29');
    console.log('  ✅ PASSED: History fetched in descending order and entry deleted successfully');

    // --- TEST 7: Onboarding Batch History Seeding ---
    console.log('\n[7/8] Testing Onboarding Batch History Seeding...');
    const onboardingWomanId = `test_onboarding_${randomUUID().slice(0, 8)}`;
    await db.collection('users_woman').insertOne({
      user_id: onboardingWomanId,
      email: `${onboardingWomanId}@example.test`,
      display_name: 'Onboarding Test',
      role: 'woman',
      created_at: new Date(),
      updated_at: new Date(),
    });

    await saveOnboardingAnswers(onboardingWomanId, {
      preferred_name: 'Onboarding Test',
      life_stage: 'reproductiveYears',
      last_period: '2026-07-20',
      period_history: ['2026-07-20', '2026-06-21', '2026-05-23'],
      cycle_length: '29',
    });

    const entriesSeeded = await getPeriodEntries(onboardingWomanId);
    assert.strictEqual(entriesSeeded.length, 3);
    assert.strictEqual(entriesSeeded[0].periodStartDate, '2026-07-20');
    assert.strictEqual(entriesSeeded[1].periodStartDate, '2026-06-21');
    assert.strictEqual(entriesSeeded[2].periodStartDate, '2026-05-23');
    console.log('  ✅ PASSED: Onboarding period_history array automatically seeded 3 historical period records');

    // --- TEST 8: Lifecycle State Suppression ---
    console.log('\n[8/8] Testing Lifecycle State Suppression (Pregnancy / Menopause)...');
    await db.collection('users_woman').updateOne(
      { user_id: onboardingWomanId },
      { $set: { 'onboarding_answers.life_stage': 'pregnancy' } }
    );
    const pred8 = await calculatePeriodPredictions(onboardingWomanId);
    assert.strictEqual(pred8.trackingSuppressed, true);
    assert.strictEqual(pred8.confidence, 'suppressed');
    console.log('  ✅ PASSED: Pregnancy stage cleanly suppresses standard period predictions');

    console.log('\n======================================================================');
    console.log('🎉 ALL PERIOD HISTORY & PREDICTION E2E TESTS PASSED (8/8 PHASES)');
    console.log('======================================================================\n');
  } finally {
    // Teardown test users
    await db.collection('users_woman').deleteMany({
      user_id: { $in: [testWomanId, `test_onboarding_${testWomanId.slice(11)}`] },
    });
    await db.collection('user_period_logs_woman').deleteMany({
      user_id: { $in: [testWomanId, `test_onboarding_${testWomanId.slice(11)}`] },
    });
    server.close();
  }
}

runPeriodHistoryE2ESuite()
  .then(() => {
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ Period History E2E Test Suite Failed:', err);
    process.exit(1);
  });
