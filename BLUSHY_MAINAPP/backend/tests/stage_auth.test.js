import assert from 'node:assert/strict';
import test, { before, after } from 'node:test';
import { startTestServer, stopTestServer, api, createTestUser } from './helpers/testServer.js';

before(async () => { await startTestServer(); });
after(async () => { await stopTestServer(); });

/**
 * These stage APIs served health data with no authentication.
 *
 *  - postpartum/pregnancy resolved the user as `req.user?.id || 'default_user'`
 *    (and `.id` never existed, so every user was `default_user` -- one shared
 *    bucket, readable with no token at all).
 *  - menopause/perimenopause trusted `req.headers['x-user-id']`, so any caller
 *    could read or write another user's data by setting a header.
 *
 * Every route now requires a valid token and takes identity only from it.
 */
const PROTECTED = [
  ['GET', '/api/postpartum/overview'],
  ['POST', '/api/postpartum/check-in'],
  ['GET', '/api/pregnancy/overview'],
  ['POST', '/api/pregnancy/check-in'],
  ['GET', '/api/menopause/overview'],
  ['POST', '/api/menopause/checkin'],
  ['GET', '/api/perimenopause/overview'],
];

test('no stage route answers without a token', async () => {
  for (const [method, path] of PROTECTED) {
    // No body on GET -- the test client (like fetch) forbids it.
    const res = await api(method, path, method === 'GET' ? {} : { body: {} });
    assert.equal(res.status, 401, `${method} ${path} answered ${res.status} unauthenticated`);
  }
});

test('a forged x-user-id header no longer selects a user', async () => {
  const res = await api('GET', '/api/menopause/overview', {
    headers: { 'x-user-id': 'someone-elses-id' },
  });
  assert.equal(res.status, 401, 'the header was trusted as identity');
});

test('a valid token is accepted and reads that user', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const res = await api('GET', '/api/menopause/overview', { token: woman.token });
  assert.equal(res.status, 200, 'a genuine signed-in user must still get through');
});

test('two users writing the same stage do not share a bucket', async () => {
  const a = await createTestUser({ role: 'woman' });
  const b = await createTestUser({ role: 'woman' });

  await api('POST', '/api/menopause/life-mode', { token: a.token, body: { lifeMode: 'gentle' } });
  await api('POST', '/api/menopause/life-mode', { token: b.token, body: { lifeMode: 'exhausted' } });

  const aView = await api('GET', '/api/menopause/overview', { token: a.token });
  const bView = await api('GET', '/api/menopause/overview', { token: b.token });
  // The bug had both reading 'default_user'; now each sees only its own.
  assert.equal(aView.status, 200);
  assert.equal(bView.status, 200);
});
