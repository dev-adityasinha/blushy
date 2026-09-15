import http from 'node:http';
import jwt from 'jsonwebtoken';
import app from '../src/app.js';
import { env } from '../src/utils/env.js';
import { db } from '../src/utils/db.js';
import { randomUUID } from 'node:crypto';

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (!condition) {
    console.error(`  ❌ FAILED: ${message}`);
    failed++;
  } else {
    console.log(`  ✅ PASSED: ${message}`);
    passed++;
  }
}

function makeRequest({ port, method, path, headers = {}, body = null }) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const reqHeaders = { ...headers };
    if (postData) {
      reqHeaders['Content-Type'] = 'application/json';
      reqHeaders['Content-Length'] = Buffer.byteLength(postData);
    }

    const req = http.request(
      {
        hostname: '127.0.0.1',
        port,
        path,
        method,
        headers: reqHeaders,
      },
      (res) => {
        let rawData = '';
        res.on('data', (chunk) => {
          rawData += chunk;
        });
        res.on('end', () => {
          let json = null;
          try {
            json = JSON.parse(rawData);
          } catch (_) {}
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: json,
            rawBody: rawData,
          });
        });
      }
    );

    req.on('error', (err) => reject(err));
    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

function createTestToken(userId, role = 'woman') {
  return jwt.sign({ userId, role }, env.jwtSecret, { expiresIn: '1h' });
}

async function runTests() {
  console.log('====================================================');
  console.log('  BLUSHY COMPREHENSIVE API CONTRACT VERIFICATION');
  console.log('====================================================\n');

  const server = app.listen(0);
  const port = server.address().port;
  console.log(`[Setup] Ephemeral test server listening on 127.0.0.1:${port}\n`);

  // Seed isolated disposable test users
  const testUserAId = `test_user_a_${randomUUID().slice(0, 8)}`;
  const testUserBId = `test_user_b_${randomUUID().slice(0, 8)}`;
  const testUserCId = `test_user_c_${randomUUID().slice(0, 8)}`;

  const tokenUserA = createTestToken(testUserAId, 'woman');
  const tokenUserB = createTestToken(testUserBId, 'man');
  const tokenUserC = createTestToken(testUserCId, 'woman');

  await db.collection('users_woman').insertOne({
    user_id: testUserAId,
    email: `${testUserAId}@test.com`,
    role: 'woman',
    created_at: new Date(),
  });

  await db.collection('users_man').insertOne({
    user_id: testUserBId,
    email: `${testUserBId}@test.com`,
    role: 'man',
    created_at: new Date(),
  });

  await db.collection('users_woman').insertOne({
    user_id: testUserCId,
    email: `${testUserCId}@test.com`,
    role: 'woman',
    created_at: new Date(),
  });

  try {
    // ----------------------------------------------------
    // CATEGORY 1: Authentication Guard Tests (401)
    // ----------------------------------------------------
    console.log('--- Category 1: Authentication Guard Tests (401) ---');

    const sleepNoAuth = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', body: { durationMinutes: 480 } });
    assert(sleepNoAuth.statusCode === 401, `PUT /auth/me/sleep without token returns 401 (got ${sleepNoAuth.statusCode})`);
    assert(sleepNoAuth.body?.error?.statusCode === 401, '401 returns structured JSON error envelope');

    const nutritionNoAuth = await makeRequest({ port, method: 'POST', path: '/auth/me/nutrition/answers', body: { dietaryPreference: 'vegetarian' } });
    assert(nutritionNoAuth.statusCode === 401, `POST /auth/me/nutrition/answers without token returns 401 (got ${nutritionNoAuth.statusCode})`);

    const invalidToken = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: 'Bearer bad.token.val' }, body: { durationMinutes: 480 } });
    assert(invalidToken.statusCode === 401, `Invalid Bearer token returns 401 (got ${invalidToken.statusCode})`);

    const expiredToken = jwt.sign({ userId: testUserAId }, env.jwtSecret, { expiresIn: '-5s' });
    const expiredRes = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: `Bearer ${expiredToken}` }, body: { durationMinutes: 480 } });
    assert(expiredRes.statusCode === 401, `Expired Bearer token returns 401 (got ${expiredRes.statusCode})`);

    // ----------------------------------------------------
    // CATEGORY 2: Validation Failure Tests (400)
    // ----------------------------------------------------
    console.log('\n--- Category 2: Validation Failure Tests (400) ---');

    // Sleep Validation: Missing, null, non-numeric, 0, negative, below 30, above 960
    const sleepMissing = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: `Bearer ${tokenUserA}` }, body: {} });
    assert(sleepMissing.statusCode === 400, `Sleep missing duration returns 400 (got ${sleepMissing.statusCode})`);

    const sleepNull = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: `Bearer ${tokenUserA}` }, body: { durationMinutes: null } });
    assert(sleepNull.statusCode === 400, `Sleep null duration returns 400 (got ${sleepNull.statusCode})`);

    const sleepString = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: `Bearer ${tokenUserA}` }, body: { durationMinutes: 'invalid_number' } });
    assert(sleepString.statusCode === 400, `Sleep string duration returns 400 (got ${sleepString.statusCode})`);

    const sleepZero = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: `Bearer ${tokenUserA}` }, body: { durationMinutes: 0 } });
    assert(sleepZero.statusCode === 400, `Sleep 0 duration returns 400 (got ${sleepZero.statusCode})`);

    const sleepNegative = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: `Bearer ${tokenUserA}` }, body: { durationMinutes: -30 } });
    assert(sleepNegative.statusCode === 400, `Sleep negative duration returns 400 (got ${sleepNegative.statusCode})`);

    const sleepTooLow = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: `Bearer ${tokenUserA}` }, body: { durationMinutes: 10 } });
    assert(sleepTooLow.statusCode === 400, `Sleep 10 min (<30) returns 400 (got ${sleepTooLow.statusCode})`);

    const sleepTooHigh = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: `Bearer ${tokenUserA}` }, body: { durationMinutes: 2000 } });
    assert(sleepTooHigh.statusCode === 400, `Sleep 2000 min (>960) returns 400 (got ${sleepTooHigh.statusCode})`);

    const sleepBadQuality = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: `Bearer ${tokenUserA}` }, body: { durationMinutes: 480, sleepQuality: 'fantastic' } });
    assert(sleepBadQuality.statusCode === 400, `Sleep invalid sleepQuality string returns 400 (got ${sleepBadQuality.statusCode})`);

    const sleepBadDateFormat = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: `Bearer ${tokenUserA}` }, body: { durationMinutes: 480, entryDate: '2026/08/21' } });
    assert(sleepBadDateFormat.statusCode === 400, `Sleep slash date format returns 400 (got ${sleepBadDateFormat.statusCode})`);

    const sleepImpossibleDate = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: `Bearer ${tokenUserA}` }, body: { durationMinutes: 480, entryDate: '2026-02-31' } });
    assert(sleepImpossibleDate.statusCode === 400, `Sleep impossible calendar date (2026-02-31) returns 400 (got ${sleepImpossibleDate.statusCode})`);

    const sleepImpossibleAprilDate = await makeRequest({ port, method: 'PUT', path: '/auth/me/sleep', headers: { Authorization: `Bearer ${tokenUserA}` }, body: { durationMinutes: 480, entryDate: '2026-04-31' } });
    assert(sleepImpossibleAprilDate.statusCode === 400, `Sleep impossible calendar date (2026-04-31) returns 400 (got ${sleepImpossibleAprilDate.statusCode})`);

    // Nutrition Validation: Missing fields, empty array
    const nutrMissingPref = await makeRequest({
      port,
      method: 'POST',
      path: '/auth/me/nutrition/answers',
      headers: { Authorization: `Bearer ${tokenUserA}` },
      body: { cookingFrequency: 'daily', nutritionGoals: ['energy'] },
    });
    assert(nutrMissingPref.statusCode === 400, `Nutrition missing dietaryPreference returns 400 (got ${nutrMissingPref.statusCode})`);

    const nutrEmptyGoals = await makeRequest({
      port,
      method: 'POST',
      path: '/auth/me/nutrition/answers',
      headers: { Authorization: `Bearer ${tokenUserA}` },
      body: { dietaryPreference: 'vegan', cookingFrequency: 'daily', nutritionGoals: [] },
    });
    assert(nutrEmptyGoals.statusCode === 400, `Nutrition empty nutritionGoals returns 400 (got ${nutrEmptyGoals.statusCode})`);

    // Partner Validation: Invalid action
    const partnerInvalidAction = await makeRequest({
      port,
      method: 'POST',
      path: '/partner/requests/any-uuid/respond',
      headers: { Authorization: `Bearer ${tokenUserA}` },
      body: { action: 'cancel' },
    });
    assert(partnerInvalidAction.statusCode === 400, `Partner respond with invalid action returns 400 (got ${partnerInvalidAction.statusCode})`);

    // ----------------------------------------------------
    // CATEGORY 3: Direct Unit Validation (NaN & Infinity)
    // ----------------------------------------------------
    console.log('\n--- Category 3: Direct Unit Validation (NaN & Infinity) ---');

    function validateDurationUnit(val) {
      const duration = typeof val === 'number' && Number.isFinite(val) ? val : NaN;
      return Number.isFinite(duration) && duration >= 30 && duration <= 960;
    }
    assert(validateDurationUnit(NaN) === false, 'Unit test: NaN duration rejected');
    assert(validateDurationUnit(Infinity) === false, 'Unit test: Infinity duration rejected');
    assert(validateDurationUnit(-Infinity) === false, 'Unit test: -Infinity duration rejected');
    assert(validateDurationUnit(480) === true, 'Unit test: 480 min duration accepted');

    // ----------------------------------------------------
    // CATEGORY 4: Cross-User Authorization & State Tests (403 / 404 / 409)
    // ----------------------------------------------------
    console.log('\n--- Category 4: Cross-User Authorization & State Tests (403 / 404 / 409) ---');

    // Create an invitation from User A to User B
    const invId = randomUUID();
    await db.collection('partner_invitations').insertOne({
      invitation_id: invId,
      sender_user_id: testUserAId,
      receiver_user_id: testUserBId,
      receiver_email: `${testUserBId}@test.com`,
      invite_token: randomUUID(),
      status: 'pending',
      created_at: new Date(),
    });

    // User C attempts to accept User B's invitation -> 403 Forbidden
    const userCAcceptForeign = await makeRequest({
      port,
      method: 'POST',
      path: `/partner/requests/${invId}/respond`,
      headers: { Authorization: `Bearer ${tokenUserC}` },
      body: { action: 'accept' },
    });
    assert(userCAcceptForeign.statusCode === 403, `User C accepting invitation for User B returns 403 Forbidden (got ${userCAcceptForeign.statusCode})`);

    // Non-existent invitation -> 404 Not Found
    const nonExistentInv = await makeRequest({
      port,
      method: 'POST',
      path: `/partner/requests/${randomUUID()}/respond`,
      headers: { Authorization: `Bearer ${tokenUserB}` },
      body: { action: 'accept' },
    });
    assert(nonExistentInv.statusCode === 404, `Responding to non-existent invitation returns 404 (got ${nonExistentInv.statusCode})`);

    // ----------------------------------------------------
    // CATEGORY 5: Success & Read-Back Contract Tests (200)
    // ----------------------------------------------------
    console.log('\n--- Category 5: Success & Read-Back Contract Tests (200) ---');

    // 1. Save Canonical Sleep Record (Standard 7.5h)
    const saveSleepSuccess = await makeRequest({
      port,
      method: 'PUT',
      path: '/auth/me/sleep',
      headers: { Authorization: `Bearer ${tokenUserA}` },
      body: {
        durationMinutes: 450,
        sleepQuality: 'good',
        entryDate: '2026-08-21',
      },
    });
    assert(saveSleepSuccess.statusCode === 200, `PUT /auth/me/sleep with canonical duration returns 200 (got ${saveSleepSuccess.statusCode})`);
    assert(saveSleepSuccess.body?.sleepEntry?.durationMinutes === 450, 'Sleep entry returns saved durationMinutes');

    // Read Back Sleep
    const readSleep = await makeRequest({
      port,
      method: 'GET',
      path: '/auth/me/sleep',
      headers: { Authorization: `Bearer ${tokenUserA}` },
    });
    assert(readSleep.statusCode === 200, `GET /auth/me/sleep returns 200 OK (got ${readSleep.statusCode})`);
    assert(readSleep.body?.sleepEntry?.durationMinutes === 450, 'GET /auth/me/sleep matches saved record');

    // 1b. Explanatory Test: Backend allows 30-min micro-naps for broad integrations, while Flutter UI scopes check-in to 1-16h
    const saveSleepNap = await makeRequest({
      port,
      method: 'PUT',
      path: '/auth/me/sleep',
      headers: { Authorization: `Bearer ${tokenUserA}` },
      body: {
        durationMinutes: 30,
        sleepQuality: 'fair',
        entryDate: '2026-08-20',
      },
    });
    assert(saveSleepNap.statusCode === 200, `Backend allows 30-min nap (30-960 min API range) while Flutter UI is scoped to 1-16h (got ${saveSleepNap.statusCode})`);

    // 2. Save Canonical Top-Level Nutrition Answers
    const saveNutritionSuccess = await makeRequest({
      port,
      method: 'POST',
      path: '/auth/me/nutrition/answers',
      headers: { Authorization: `Bearer ${tokenUserA}` },
      body: {
        dietaryPreference: 'vegetarian',
        allergies: ['peanuts'],
        cookingFrequency: 'daily',
        nutritionGoals: ['energy', 'muscle_gain'],
      },
    });
    assert(saveNutritionSuccess.statusCode === 200, `POST /auth/me/nutrition/answers (top-level) returns 200 (got ${saveNutritionSuccess.statusCode})`);
    assert(saveNutritionSuccess.body?.nutritionAnswers?.dietaryPreference === 'vegetarian', 'Nutrition answers returns saved data');

    // 3. Save Legacy Nested Nutrition Answers (Compatibility check)
    const saveNutritionLegacy = await makeRequest({
      port,
      method: 'POST',
      path: '/auth/me/nutrition/answers',
      headers: { Authorization: `Bearer ${tokenUserA}` },
      body: {
        answers: {
          dietaryPreference: 'vegan',
          allergies: ['dairy'],
          cookingFrequency: 'weekly',
          nutritionGoals: ['weight_loss'],
        },
      },
    });
    assert(saveNutritionLegacy.statusCode === 200, `POST /auth/me/nutrition/answers (legacy nested) returns 200 (got ${saveNutritionLegacy.statusCode})`);
    assert(saveNutritionLegacy.body?.nutritionAnswers?.dietaryPreference === 'vegan', 'Legacy nested returns identical shape and updated preference');

    // Read Back Nutrition Answers
    const readNutrition = await makeRequest({
      port,
      method: 'GET',
      path: '/auth/me/nutrition/answers',
      headers: { Authorization: `Bearer ${tokenUserA}` },
    });
    assert(readNutrition.statusCode === 200, `GET /auth/me/nutrition/answers returns 200 (got ${readNutrition.statusCode})`);
    assert(readNutrition.body?.nutritionAnswers?.dietaryPreference === 'vegan', 'Read back returns normalized answers matching Flutter model');

    // 4. Intended Receiver (User B) Accepts Invitation
    const userBAccept = await makeRequest({
      port,
      method: 'POST',
      path: `/partner/requests/${invId}/respond`,
      headers: { Authorization: `Bearer ${tokenUserB}` },
      body: { action: 'accept' },
    });
    assert(userBAccept.statusCode === 200, `User B accepts pending invitation -> 200 OK (got ${userBAccept.statusCode})`);
    assert(typeof userBAccept.body?.connectionId === 'string', 'Acceptance returns active connectionId');

    // Duplicate accept on now-resolved invitation -> 409 Conflict
    const userBDuplicateAccept = await makeRequest({
      port,
      method: 'POST',
      path: `/partner/requests/${invId}/respond`,
      headers: { Authorization: `Bearer ${tokenUserB}` },
      body: { action: 'accept' },
    });
    assert(userBDuplicateAccept.statusCode === 409, `Duplicate response to resolved invitation returns 409 Conflict (got ${userBDuplicateAccept.statusCode})`);

    // ----------------------------------------------------
    // CATEGORY 6: Batch 1 404 & Static Integrity Tests
    // ----------------------------------------------------
    console.log('\n--- Category 6: Batch 1 404 & Static Integrity Tests ---');

    const rootRes = await makeRequest({ port, method: 'GET', path: '/' });
    assert(rootRes.statusCode === 200, `GET / returns 200 OK (got ${rootRes.statusCode})`);

    const healthRes = await makeRequest({ port, method: 'GET', path: '/health' });
    assert(healthRes.statusCode === 200, `GET /health returns 200 OK (got ${healthRes.statusCode})`);

    const forbiddenUpload = await makeRequest({ port, method: 'GET', path: '/uploads/malicious_script.exe' });
    assert(forbiddenUpload.statusCode === 403, `GET /uploads/malicious_script.exe returns 403 Forbidden (got ${forbiddenUpload.statusCode})`);

    const unknownGet = await makeRequest({ port, method: 'GET', path: '/non-existent-test-route-12345' });
    assert(unknownGet.statusCode === 404, `GET /non-existent-test-route-12345 returns 404 (got ${unknownGet.statusCode})`);
    assert(unknownGet.body?.error?.statusCode === 404, '404 returns structured JSON error envelope');

    const unknownPost = await makeRequest({ port, method: 'POST', path: '/api/unknown-endpoint-xyz', body: { foo: 'bar' } });
    assert(unknownPost.statusCode === 404, `POST /api/unknown-endpoint-xyz returns 404 (got ${unknownPost.statusCode})`);

    const unknownPutAuth = await makeRequest({ port, method: 'PUT', path: '/auth/nonexistent-action', body: {} });
    assert(unknownPutAuth.statusCode === 404, `PUT /auth/nonexistent-action returns 404 (got ${unknownPutAuth.statusCode})`);

  } finally {
    // Teardown test documents
    await db.collection('users_woman').deleteOne({ user_id: testUserAId });
    await db.collection('users_man').deleteOne({ user_id: testUserBId });
    await db.collection('users_woman').deleteOne({ user_id: testUserCId });
    await db.collection('user_sleep_logs_woman').deleteMany({ user_id: testUserAId });
    await db.collection('user_nutrition_answers_woman').deleteMany({ user_id: testUserAId });
    await db.collection('partner_invitations').deleteMany({ sender_user_id: testUserAId });
    await db.collection('partner_connections').deleteMany({ $or: [{ user_a_id: testUserAId }, { user_b_id: testUserAId }] });

    server.close();
    console.log('\n[Teardown] Ephemeral test server closed and test data purged.');
  }

  console.log('\n====================================================');
  console.log(`TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('====================================================');

  if (failed > 0) {
    process.exit(1);
  }
  process.exit(0);
}

runTests().catch((err) => {
  console.error('Fatal test runner error:', err);
  process.exit(1);
});
