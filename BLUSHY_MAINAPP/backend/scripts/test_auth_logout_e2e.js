import http from 'node:http';
import assert from 'node:assert';
import { randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';
import app from '../src/app.js';
import { db } from '../src/utils/db.js';
import { signAccessToken, signRefreshToken } from '../src/services/tokenService.js';

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

async function runLogoutE2ETestSuite() {
  console.log('======================================================================');
  console.log('🔒 RUNNING BACKEND LOGOUT & TOKEN REVOCATION E2E TEST SUITE');
  console.log('======================================================================\n');

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;

  const testUserId = `user_logout_test_${randomUUID().slice(0, 8)}`;
  const testEmail = `logout_test_${randomUUID().slice(0, 8)}@example.test`;
  const rawPassword = 'SecurePassword123!';
  const passwordHash = await bcrypt.hash(rawPassword, 10);

  try {
    // 1. Seed verified user
    console.log('[1/8] Seeding verified test user in MongoDB...');
    await db.collection('users_woman').insertOne({
      user_id: testUserId,
      email: testEmail,
      phone_number: '+919876543210',
      password_hash: passwordHash,
      role: 'woman',
      token_version: 1,
      email_verified_at: new Date(),
      created_at: new Date(),
      updated_at: new Date(),
    });
    console.log(`  ✅ User seeded with token_version = 1 (userId: ${testUserId})`);

    // 2. User logs in with email and password
    console.log('\n[2/8] Logging in with email and password...');
    const loginRes = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/login-email',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, { email: testEmail, password: rawPassword });

    assert.strictEqual(loginRes.status, 200);
    const accessToken = loginRes.body.token;
    const refreshToken = loginRes.body.refreshToken;
    assert.ok(accessToken, 'Access token must be returned on login');
    assert.ok(refreshToken, 'Refresh token must be returned on login');
    console.log('  ✅ Login successful: access token and refresh token received');

    // 3. User accesses authenticated endpoint
    console.log('\n[3/8] Accessing authenticated endpoint with valid token...');
    const meRes = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/me',
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
    });
    assert.strictEqual(meRes.status, 200);
    assert.strictEqual(meRes.body.user.email, testEmail);
    console.log('  ✅ Successfully accessed /auth/me with Bearer token');

    // 4. User logs out via POST /auth/logout
    console.log('\n[4/8] Executing POST /auth/logout with Bearer token...');
    const logoutRes = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/logout',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
    });
    assert.strictEqual(logoutRes.status, 200);
    assert.strictEqual(logoutRes.body.success, true);
    assert.strictEqual(logoutRes.body.message, 'Logged out successfully.');
    console.log('  ✅ Logout successful: received 200 OK and success confirmation');

    // 5. Verify database token_version incremented
    console.log('\n[5/8] Verifying token_version increment in database...');
    const updatedUser = await db.collection('users_woman').findOne({ user_id: testUserId });
    assert.strictEqual(updatedUser.token_version, 2, 'token_version should increment from 1 to 2');
    console.log(`  ✅ Database confirmed: token_version incremented to ${updatedUser.token_version}`);

    // 6. Verify old access token is revoked on subsequent calls
    console.log('\n[6/8] Verifying old access token is rejected on /auth/me...');
    const revokedRes = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/me',
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
    });
    assert.strictEqual(revokedRes.status, 401);
    console.log('  ✅ PASSED: Old access token rejected with 401 Unauthorized');

    // 7. Verify old refresh token cannot create new session
    console.log('\n[7/8] Verifying old refresh token is rejected on /auth/refresh...');
    const refreshRes = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/refresh',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, { refreshToken });
    assert.strictEqual(refreshRes.status, 401);
    console.log('  ✅ PASSED: Old refresh token rejected with 401 Unauthorized');

    // 8. Verify idempotent repeated logout without credentials
    console.log('\n[8/8] Testing unauthenticated / repeated logout idempotency...');
    const idempotentLogoutRes = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/logout',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    });
    assert.strictEqual(idempotentLogoutRes.status, 200);
    assert.strictEqual(idempotentLogoutRes.body.success, true);
    console.log('  ✅ PASSED: Repeated logout is safe and returns 200 OK');

    console.log('\n======================================================================');
    console.log('🎉 ALL BACKEND LOGOUT & TOKEN REVOCATION TESTS PASSED (8/8)');
    console.log('======================================================================\n');
  } finally {
    await db.collection('users_woman').deleteMany({ user_id: testUserId });
    server.close();
  }
}

runLogoutE2ETestSuite()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Logout E2E Test Suite Failed:', err);
    process.exit(1);
  });
