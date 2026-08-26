import { createServer } from 'node:http';
import jwt from 'jsonwebtoken';
import http from 'node:http';
import { WebSocket } from 'ws';

import app from '../src/app.js';
import { env } from '../src/utils/env.js';
import { initDatabase } from '../src/utils/initDatabase.js';
import { initRealtimeHub, isUserOnline } from '../src/utils/realtimeHub.js';
import { userRepository } from '../src/repositories/userRepository.js';
import { db } from '../src/utils/db.js';

const TEST_PORT = 3099;
const BASE_URL = `http://localhost:${TEST_PORT}`;
const WS_URL = `ws://localhost:${TEST_PORT}/ws`;
const JWT_SECRET = env.jwtSecret;

function generateTestToken(userId, email, role = 'woman') {
  return jwt.sign(
    { userId, email, role, tokenVersion: 1 },
    JWT_SECRET,
    { algorithm: 'HS256', expiresIn: '1h' }
  );
}

function request(path, options = {}, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const reqOptions = {
      method: options.method || 'GET',
      headers: options.headers || {},
    };

    const req = http.request(url, reqOptions, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        let json = null;
        try {
          json = JSON.parse(data);
        } catch (_) {}
        resolve({
          method: reqOptions.method,
          url: url.href,
          headers: reqOptions.headers,
          requestBody: body,
          statusCode: res.statusCode,
          responseHeaders: res.headers,
          body: json || data,
        });
      });
    });

    req.on('error', reject);

    if (body) {
      if (typeof body === 'object') {
        req.setHeader('Content-Type', 'application/json');
        req.write(JSON.stringify(body));
      } else {
        req.write(body);
      }
    }
    req.end();
  });
}

async function runTests() {
  console.log('================================================================');
  console.log('STARTING SIA CROSS-ACCOUNT DATA ISOLATION E2E TEST SUITE');
  console.log(`Environment: Staging Ephemeral Test Server (${BASE_URL})`);
  console.log('Date: ' + new Date().toISOString());
  console.log('================================================================\n');

  await initDatabase();
  const server = createServer(app);
  initRealtimeHub(server);
  await new Promise((resolve) => server.listen(TEST_PORT, resolve));

  let passed = 0;
  let failed = 0;

  function assert(name, condition, extra = '') {
    if (condition) {
      console.log(`[PASS] ${name} ${extra ? '(' + extra + ')' : ''}`);
      passed++;
    } else {
      console.error(`[FAIL] ${name} ${extra ? '(' + extra + ')' : ''}`);
      failed++;
    }
  }

  let userA_Id, userB_Id, userC_Id;

  try {
    // Generate disposable test identities in staging database
    const uniqueSuffix = Date.now();
    const emailA = `test_user_a_${uniqueSuffix}@staging.local`;
    const emailB = `test_user_b_${uniqueSuffix}@staging.local`;
    const emailC = `test_user_c_${uniqueSuffix}@staging.local`;

    const userA = await userRepository.createUser({
      email: emailA,
      role: 'woman',
      passwordHash: 'dummy_hash_for_testing',
      onboardingAnswers: { preferred_name: 'User A Staging' },
    });
    userA_Id = userA.userId;

    const userB = await userRepository.createUser({
      email: emailB,
      role: 'woman',
      passwordHash: 'dummy_hash_for_testing',
      onboardingAnswers: { preferred_name: 'User B Staging' },
    });
    userB_Id = userB.userId;

    const userC = await userRepository.createUser({
      email: emailC,
      role: 'woman',
      passwordHash: 'dummy_hash_for_testing',
      onboardingAnswers: { preferred_name: 'User C Staging' },
    });
    userC_Id = userC.userId;

    const tokenA = generateTestToken(userA_Id, emailA);
    const tokenB = generateTestToken(userB_Id, emailB);
    const tokenC = generateTestToken(userC_Id, emailC);
    const invalidToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.invalid.token';

    console.log('--- 1. REQUEST-LEVEL EVIDENCE: ENDPOINT-BY-ENDPOINT 401 UNAUTHENTICATED TESTS ---');
    const privateEndpoints = [
      { method: 'POST', path: '/api/ai/chat', body: { message: 'Hello' } },
      { method: 'GET', path: '/api/ai/history' },
      { method: 'DELETE', path: '/api/ai/history' },
      { method: 'GET', path: '/api/ai/memory-summary' },
      { method: 'GET', path: '/api/ai/health-insights' },
      { method: 'POST', path: '/api/ai/transcribe', body: {} },
      { method: 'POST', path: '/api/ai/voice/session', body: {} },
      { method: 'GET', path: '/api/ai/medical-reports' },
      { method: 'GET', path: '/api/ai/onboarding-audit' },
      { method: 'POST', path: '/api/ai/profile-memory', body: { message: 'test' } },
      { method: 'GET', path: '/api/ai/partner-suggestions/conn_123' },
      { method: 'GET', path: '/api/ai/decode-partner-message/conn_123' },
    ];

    for (const ep of privateEndpoints) {
      const res = await request(ep.path, { method: ep.method }, ep.body);
      const resStr = JSON.stringify(res.body);
      console.log(`[Evidence] ${ep.method} ${ep.path} -> Status: ${res.statusCode} | Body: ${resStr.slice(0, 80)}`);
      assert(
        `Unauthenticated ${ep.method} ${ep.path} returns 401`,
        res.statusCode === 401,
        `Status: ${res.statusCode}`
      );
    }

    console.log('\n--- 2. INVALID / MALFORMED JWT TESTS (401) ---');
    const resInvalid = await request('/api/ai/history', {
      method: 'GET',
      headers: { Authorization: `Bearer ${invalidToken}` },
    });
    console.log(`[Evidence] GET /api/ai/history with invalid token -> Status: ${resInvalid.statusCode}`);
    assert(
      'Invalid Bearer token on GET /api/ai/history returns 401',
      resInvalid.statusCode === 401,
      `Status: ${resInvalid.statusCode}`
    );

    console.log('\n--- 3. GUEST DISCOVER ISOLATION (NON-PERSONALIZED PUBLIC ACCESS) ---');
    const resGuestDiscover = await request('/api/ai/discover', { method: 'GET' });
    console.log(`[Evidence] Guest GET /api/ai/discover -> Status: ${resGuestDiscover.statusCode} | isPersonalized: ${resGuestDiscover.body?.isPersonalized}`);
    assert(
      'GET /api/ai/discover allows guest access with 200 OK',
      resGuestDiscover.statusCode === 200,
      `Status: ${resGuestDiscover.statusCode}`
    );
    assert(
      'Guest Discover payload is explicitly not personalized',
      resGuestDiscover.body?.isPersonalized === false,
      `isPersonalized: ${resGuestDiscover.body?.isPersonalized}`
    );

    console.log('\n--- 4. TWO-USER & THREE-USER DATA ISOLATION TRACE ---');
    // Step 1: User A sends chat message
    console.log(`[Action] User A (${userA_Id}) posts chat marker: "USER_A_TEST_ONLY_MARKER"`);
    const chatResA = await request('/api/ai/chat', {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokenA}` },
    }, {
      message: 'USER_A_TEST_ONLY_MARKER: I am experiencing cramps and anxiety.',
      messages: [{ role: 'user', content: 'USER_A_TEST_ONLY_MARKER: I am experiencing cramps and anxiety.' }],
      role: 'woman',
    });
    console.log(`[Evidence] User A POST /api/ai/chat -> Status: ${chatResA.statusCode}`);
    assert('User A chat request succeeds', chatResA.statusCode === 200, `Status: ${chatResA.statusCode}`);

    // Step 2: User A verifies history contains marker
    const histResA = await request('/api/ai/history', {
      method: 'GET',
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    const userAHasMarker = Array.isArray(histResA.body?.history) &&
      histResA.body.history.some(h => JSON.stringify(h).includes('USER_A_TEST_ONLY_MARKER'));
    console.log(`[Evidence] User A GET /api/ai/history -> Count: ${histResA.body?.history?.length || 0}`);
    assert('User A history contains User A marker', userAHasMarker, `Count: ${histResA.body?.history?.length || 0}`);

    // Step 3: User B logs in and fetches history
    console.log(`[Action] User B (${userB_Id}) fetches history`);
    const histResB = await request('/api/ai/history', {
      method: 'GET',
      headers: { Authorization: `Bearer ${tokenB}` },
    });
    const userBHasMarkerA = Array.isArray(histResB.body?.history) &&
      histResB.body.history.some(h => JSON.stringify(h).includes('USER_A_TEST_ONLY_MARKER'));
    console.log(`[Evidence] User B GET /api/ai/history -> Count: ${histResB.body?.history?.length || 0} | Marker Leak: ${userBHasMarkerA}`);
    assert(
      'User B history contains ZERO User A markers',
      !userBHasMarkerA && histResB.statusCode === 200,
      `User B History Size: ${histResB.body?.history?.length || 0}, Contains Marker: ${userBHasMarkerA}`
    );

    // Step 4: User C attempts to access history
    console.log(`[Action] User C (${userC_Id}) fetches history`);
    const histResC = await request('/api/ai/history', {
      method: 'GET',
      headers: { Authorization: `Bearer ${tokenC}` },
    });
    const userCHasMarkerA = Array.isArray(histResC.body?.history) &&
      histResC.body.history.some(h => JSON.stringify(h).includes('USER_A_TEST_ONLY_MARKER'));
    console.log(`[Evidence] User C GET /api/ai/history -> Count: ${histResC.body?.history?.length || 0} | Marker Leak: ${userCHasMarkerA}`);
    assert(
      'User C receives zero User A records',
      !userCHasMarkerA && histResC.statusCode === 200,
      `Contains Marker: ${userCHasMarkerA}`
    );

    // Step 5: User A deletes history
    console.log(`[Action] User A (${userA_Id}) clears history`);
    const delResA = await request('/api/ai/history', {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    console.log(`[Evidence] User A DELETE /api/ai/history -> Status: ${delResA.statusCode}`);
    assert('User A clear history succeeds', delResA.statusCode === 200, `Status: ${delResA.statusCode}`);

    const histResA2 = await request('/api/ai/history', {
      method: 'GET',
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    assert('User A history is now empty', (histResA2.body?.history?.length || 0) === 0, `Count: ${histResA2.body?.history?.length}`);

    console.log('\n--- 5. REAL WEBSOCKET AUTHENTICATION & LOGOUT DISCONNECT TRACE ---');
    // Sub-test 5.1: Unauthenticated WS connection rejected
    const unauthWs = new WebSocket(WS_URL);
    const unauthClosed = await new Promise((resolve) => {
      unauthWs.on('close', (code, reason) => resolve({ code, reason: reason.toString() }));
    });
    console.log(`[Evidence] Unauthenticated WS connection closed -> Code: ${unauthClosed.code}, Reason: "${unauthClosed.reason}"`);
    assert('Unauthenticated WebSocket connection rejected with code 1008', unauthClosed.code === 1008, `Code: ${unauthClosed.code}`);

    // Sub-test 5.2: Authenticated WS connection for User A
    const wsA = new WebSocket(`${WS_URL}?token=${tokenA}`);
    const wsAConnected = await new Promise((resolve) => {
      wsA.on('message', (data) => {
        try {
          const parsed = JSON.parse(data.toString());
          if (parsed.event === 'realtime.connected') resolve(parsed);
        } catch (_) {}
      });
    });
    console.log(`[Evidence] User A WS connected -> Event: ${wsAConnected.event}, UserId: ${wsAConnected.userId}`);
    assert('User A WebSocket authenticated and online', isUserOnline(userA_Id), `Online: ${isUserOnline(userA_Id)}`);

    // Sub-test 5.3: User A disconnects (Logout simulator)
    wsA.close();
    await new Promise((r) => setTimeout(r, 100));
    console.log(`[Evidence] User A WS closed. isUserOnline: ${isUserOnline(userA_Id)}`);
    assert('User A WebSocket state cleaned up on disconnect', !isUserOnline(userA_Id), `Online: ${isUserOnline(userA_Id)}`);

    // Teardown test users
    console.log('\n--- 6. TEARDOWN DISPOSABLE STAGING USERS ---');
    await db.collection('users_woman').deleteMany({
      user_id: { $in: [userA_Id, userB_Id, userC_Id] }
    });
    await db.collection('ai_chat_history_woman').deleteMany({
      user_id: { $in: [userA_Id, userB_Id, userC_Id] }
    });
    console.log('[PASS] Staging database disposable test records cleaned up successfully.');

  } finally {
    server.close();
  }

  console.log('\n================================================================');
  console.log(`TOTAL TESTS: ${passed + failed} | PASSED: ${passed} | FAILED: ${failed}`);
  console.log('================================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Test Suite Runner Error:', err);
  process.exit(1);
});
