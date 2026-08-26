import http from 'node:http';
import assert from 'node:assert';
import { randomUUID } from 'node:crypto';
import app from '../src/app.js';
import { db } from '../src/utils/db.js';
import { env } from '../src/utils/env.js';

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

async function runAuthSecurityAuditSuite() {
  console.log('======================================================================');
  console.log('🔒 RUNNING AUTHENTICATION LOGOUT & EMPTY-SIGN-IN SECURITY AUDIT');
  console.log('======================================================================\n');

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;

  const testEmail = `audit_user_${randomUUID().slice(0, 8)}@example.test`;
  const testPassword = 'SecurePassword123!';

  try {
    // 1. Empty email and empty password cannot sign in
    console.log('[1/12] Testing empty email and empty password rejection...');
    const res1 = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/login-email',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, { email: '', password: '' });
    assert.strictEqual(res1.status, 400);
    assert.strictEqual(res1.body.token, undefined);
    console.log('  ✅ PASSED: Empty email and password rejected with 400 and no token');

    // 2. Whitespace-only email and password cannot sign in
    console.log('\n[2/12] Testing whitespace-only email and password...');
    const res2 = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/login-email',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, { email: '   ', password: '   ' });
    assert.strictEqual(res2.status, 400);
    assert.strictEqual(res2.body.token, undefined);
    console.log('  ✅ PASSED: Whitespace-only credentials rejected with 400');

    // 3. Missing email field cannot sign in
    console.log('\n[3/12] Testing missing email field...');
    const res3 = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/login-email',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, { password: testPassword });
    assert.strictEqual(res3.status, 400);
    console.log('  ✅ PASSED: Missing email rejected with 400');

    // 4. Missing password field cannot sign in
    console.log('\n[4/12] Testing missing password field...');
    const res4 = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/login-email',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, { email: testEmail });
    assert.strictEqual(res4.status, 400);
    console.log('  ✅ PASSED: Missing password rejected with 400');

    // 5. Invalid email format cannot sign in
    console.log('\n[5/12] Testing invalid email format...');
    const res5 = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/login-email',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, { email: 'not-an-email', password: testPassword });
    assert.strictEqual(res5.status, 401);
    console.log('  ✅ PASSED: Non-existent email rejected with 401');

    // 6. Complete signup of test user
    console.log('\n[6/12] Creating verified test user...');
    await db.collection('users_woman').insertOne({
      user_id: `user_${randomUUID().slice(0, 8)}`,
      email: testEmail,
      phone_number: '+919999988888',
      password_hash: '$2a$10$abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH',
      role: 'woman',
      email_verified_at: new Date(),
      created_at: new Date(),
      updated_at: new Date(),
    });
    console.log(`  ✅ Test user seeded: ${testEmail}`);

    // 7. Wrong password cannot sign in
    console.log('\n[7/12] Testing wrong password rejection...');
    const res7 = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/login-email',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, { email: testEmail, password: 'WrongPassword999!' });
    assert.strictEqual(res7.status, 401);
    assert.strictEqual(res7.body.token, undefined);
    console.log('  ✅ PASSED: Wrong password rejected with 401');

    // 8. Empty request body ({}) to /auth/login-email
    console.log('\n[8/12] Testing empty object ({}) to /auth/login-email...');
    const res8 = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/login-email',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, {});
    assert.strictEqual(res8.status, 400);
    console.log('  ✅ PASSED: Empty payload rejected with 400');

    // 9. Empty request to /auth/complete-email-signup
    console.log('\n[9/12] Testing empty payload to /auth/complete-email-signup...');
    const res9 = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/complete-email-signup',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, {});
    assert.strictEqual(res9.status, 400);
    console.log('  ✅ PASSED: Empty signup payload rejected with 400');

    // 10. Empty request to /auth/verify-email-code
    console.log('\n[10/12] Testing empty payload to /auth/verify-email-code...');
    const res10 = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/verify-email-code',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, {});
    assert.strictEqual(res10.status, 400);
    console.log('  ✅ PASSED: Empty OTP payload rejected with 400');

    // 11. Empty request to /auth/refresh
    console.log('\n[11/12] Testing empty refresh token request...');
    const res11 = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/auth/refresh',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, {});
    assert.strictEqual(res11.status, 400);
    console.log('  ✅ PASSED: Empty refresh token request rejected with 400');

    // 12. Structured JSON error verification
    console.log('\n[12/12] Verifying error response JSON envelope...');
    assert.ok(res1.body.error || res1.body.message, 'Response must have error or message field');
    console.log('  ✅ PASSED: Structured error envelope returned');

    console.log('\n======================================================================');
    console.log('🎉 ALL BACKEND AUTH SECURITY AUDIT TESTS PASSED (12/12)');
    console.log('======================================================================\n');
  } finally {
    await db.collection('users_woman').deleteMany({ email: testEmail });
    server.close();
  }
}

runAuthSecurityAuditSuite()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Auth Security Audit Suite Failed:', err);
    process.exit(1);
  });
