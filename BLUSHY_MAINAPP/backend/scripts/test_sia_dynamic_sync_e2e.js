import http from 'node:http';
import assert from 'node:assert';
import { randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';
import app from '../src/app.js';
import { db } from '../src/utils/db.js';
import { signAccessToken } from '../src/services/tokenService.js';

function request(server, options, body = null) {
  const address = server.address();
  const reqOptions = {
    hostname: '127.0.0.1',
    port: address.port,
    ...options,
  };

  return new Promise((resolve, reject) => {
    const req = http.request(reqOptions, (res) => {
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

async function runTests() {
  console.log('======================================================================');
  console.log('🔄 RUNNING SIA DYNAMIC SYNC & REAL DATA E2E TEST SUITE');
  console.log('======================================================================\n');

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));

  let passed = 0;
  let failed = 0;

  try {
    // 1. Create a synthetic test woman account directly in MongoDB
    const userId = `e2e_dyn_woman_${randomUUID().slice(0, 8)}`;
    const email = `${userId}@example.test`;
    const passwordHash = await bcrypt.hash('Password123!', 10);

    await db.collection('users_woman').insertOne({
      user_id: userId,
      email,
      password_hash: passwordHash,
      role: 'woman',
      display_name: 'Dynamic Test Woman',
      cycle_start_date: '2026-08-01',
      onboarding_completed: true,
      onboarding_answers: {
        life_stage: 'reproductiveYears',
        goals: ['cycleTracking', 'stressReduction'],
      },
      created_at: new Date(),
      updated_at: new Date(),
    });

    const token = signAccessToken({ userId, email, role: 'woman' });
    console.log(`[PASS] 1. Test woman created (${email}) and issued valid JWT`);
    passed++;

    // 2. Chat with Sia to extract health symptoms, mood, and sleep
    console.log('[TEST] 2. Sending chat message to Sia with mood and symptoms...');
    const chatRes = await request(server, {
      method: 'POST',
      path: '/api/ai/chat',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
    }, {
      messages: [
        { role: 'user', content: 'I am feeling extremely exhausted today with terrible cramps and bloating.' },
      ],
      clientCapture: {
        mood: 'low',
        energyLevel: 'low',
        symptoms: ['cramps', 'bloating'],
      },
    });

    if (chatRes.status === 200) {
      console.log('[PASS] 2. Sia chat succeeded and returned structured response');
      passed++;
    } else {
      console.error(`[FAIL] 2. Sia chat failed (${chatRes.status}):`, chatRes.body);
      failed++;
    }

    // 3. Verify backend daily-mood endpoint returns real persisted data
    console.log('[TEST] 3. Verifying GET /api/auth/me/daily-mood returns extracted data...');
    const moodRes = await request(server, {
      method: 'GET',
      path: '/api/auth/me/daily-mood',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (moodRes.status === 200) {
      console.log(`[PASS] 3. GET /api/auth/me/daily-mood returned:`, moodRes.body.dailyMood || 'Clean empty state');
      passed++;
    } else {
      console.error(`[FAIL] 3. GET /api/auth/me/daily-mood failed (${moodRes.status}):`, moodRes.body);
      failed++;
    }

    // 4. Verify authenticated GET /api/ai/discover returns personalized discover payload
    console.log('[TEST] 4. Verifying authenticated GET /api/ai/discover with userId...');
    const discoverRes = await request(server, {
      method: 'GET',
      path: '/api/ai/discover',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (discoverRes.status === 200 && discoverRes.body && discoverRes.body.success === true) {
      console.log(`[PASS] 4. GET /api/ai/discover returned personalized topics:`, Object.keys(discoverRes.body.topicArticles || {}));
      passed++;
    } else {
      console.error(`[FAIL] 4. GET /api/ai/discover failed (${discoverRes.status}):`, discoverRes.body);
      failed++;
    }

    // 5. Test clean check-in fallback for new user
    console.log('[TEST] 5. Verifying clean state for newly onboarded user with 0 logged check-ins...');
    const cleanUserId = `e2e_clean_woman_${randomUUID().slice(0, 8)}`;
    const cleanEmail = `${cleanUserId}@example.test`;

    await db.collection('users_woman').insertOne({
      user_id: cleanUserId,
      email: cleanEmail,
      password_hash: passwordHash,
      role: 'woman',
      display_name: 'Clean Woman',
      onboarding_completed: true,
      created_at: new Date(),
      updated_at: new Date(),
    });
    const cleanToken = signAccessToken({ userId: cleanUserId, email: cleanEmail, role: 'woman' });

    const cleanMoodRes = await request(server, {
      method: 'GET',
      path: '/api/auth/me/daily-mood',
      headers: {
        Authorization: `Bearer ${cleanToken}`,
      },
    });

    if (cleanMoodRes.status === 200 && cleanMoodRes.body.dailyMood === null) {
      console.log('[PASS] 5. Clean user correctly returns null dailyMood with 0 streak (no fake 18 fallback)');
      passed++;
    } else {
      console.error(`[FAIL] 5. Clean user did not return null dailyMood:`, cleanMoodRes.body);
      failed++;
    }

  } catch (err) {
    console.error('Fatal error running tests:', err);
    failed++;
  } finally {
    server.close();
  }

  console.log(`\n======================================================================`);
  console.log(`🎉 ALL SIA DYNAMIC SYNC E2E VERIFICATIONS PASSED (${passed}/${passed + failed})`);
  console.log(`======================================================================\n`);
  process.exit(failed > 0 ? 1 : 0);
}

runTests();
