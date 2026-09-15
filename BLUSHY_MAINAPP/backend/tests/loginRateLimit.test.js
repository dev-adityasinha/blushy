import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';

import { startTestServer, stopTestServer, api, getDb } from './helpers/testServer.js';

/**
 * The login limiter counts guesses, not sign-ins.
 *
 * It used to count every request to the endpoint. Signing in on a second
 * device, reinstalling, or simply signing out and back in spent the budget of
 * five without anybody mistyping anything -- and then a genuine attempt was
 * refused with "Too many login attempts. Please try again in 15 minutes."
 *
 * Two changes. A successful login no longer counts, and it clears whatever
 * failures came before it: a correct password is proof of the account's owner,
 * which is the one thing somebody guessing does not have.
 *
 * The limit is deliberately still five wrong passwords in fifteen minutes.
 * Narrowing what counts is not the same as loosening the limit, and the first
 * test here is what stops the second change from quietly becoming the first.
 */

before(async () => { await startTestServer(); });
after(async () => { await stopTestServer(); });

const PASSWORD = 'correct-horse-battery';
const WRONG = 'not-the-password';

/** A fresh address, so each test gets its own bucket. */
const freshEmail = () => `rl-${randomUUID()}@example.test`;

const login = (email, password) =>
  api('POST', '/auth/login-email', { body: { email, password } });

/// An account the login route can actually accept, hash and all.
async function accountWith(email) {
  await getDb().collection('users_woman').insertOne({
    user_id: `rl_${randomUUID().replace(/-/g, '').slice(0, 16)}`,
    email,
    display_name: 'Rate Limit',
    password_hash: await bcrypt.hash(PASSWORD, 8),
    role: 'woman',
    token_version: 1,
    email_verified_at: new Date(),
    onboarding_answers: {},
    created_at: new Date(),
    updated_at: new Date(),
  });
}

test('five wrong passwords still close the door', async () => {
  const email = freshEmail();

  for (let i = 1; i <= 5; i += 1) {
    const res = await login(email, WRONG);
    assert.notEqual(res.status, 429, `attempt ${i} should be allowed through`);
  }

  const blocked = await login(email, WRONG);
  assert.equal(blocked.status, 429, 'the sixth guess is refused');
  assert.match(String(blocked.body?.error?.message ?? ''), /too many/i);
});

test('the refusal says how many seconds are left, not which window', async () => {
  // The app words its message from this. Without it the only thing to show is
  // the policy window, which tells somebody fourteen minutes in to wait
  // fifteen more.
  const email = freshEmail();
  for (let i = 0; i < 6; i += 1) {
    await login(email, WRONG);
  }

  const blocked = await login(email, WRONG);
  assert.equal(blocked.status, 429);
  const retryAfter = Number(blocked.headers?.['retry-after']);
  assert.ok(
    Number.isFinite(retryAfter) && retryAfter > 0 && retryAfter <= 900,
    `Retry-After should be seconds remaining, got ${blocked.headers?.['retry-after']}`,
  );
});

test('signing in repeatedly does not count against you', async () => {
  // The failure people actually hit: nothing was ever typed wrong.
  const email = freshEmail();
  await accountWith(email);

  for (let i = 1; i <= 8; i += 1) {
    const res = await login(email, PASSWORD);
    assert.equal(res.status, 200, `sign-in ${i} should succeed`);
  }
});

test('getting it right forgives the tries before it', async () => {
  const email = freshEmail();
  await accountWith(email);

  // Four wrong, then the right one, and the slate is clean -- so four more
  // wrong ones are still allowed before the door closes.
  for (let i = 0; i < 4; i += 1) {
    await login(email, WRONG);
  }
  assert.equal((await login(email, PASSWORD)).status, 200);

  for (let i = 1; i <= 4; i += 1) {
    const res = await login(email, WRONG);
    assert.notEqual(
      res.status,
      429,
      `attempt ${i} after a success was refused; the count was not reset`,
    );
  }
});

test('one account being locked does not lock another', async () => {
  // The key is the address as well as where it came from, so a shared carrier
  // IP must not spread one person's lockout across everyone behind it.
  const locked = freshEmail();
  for (let i = 0; i < 6; i += 1) {
    await login(locked, WRONG);
  }
  assert.equal((await login(locked, WRONG)).status, 429);

  const other = await login(freshEmail(), WRONG);
  assert.notEqual(other.status, 429, 'a different account has its own budget');
});
