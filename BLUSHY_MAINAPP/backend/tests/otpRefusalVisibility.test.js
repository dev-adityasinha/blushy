import test, { before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

import { startTestServer, stopTestServer, createTestUser, api } from './helpers/testServer.js';
import { logger } from '../src/utils/logger.js';

/**
 * A refused signup code has to say why, and the SMTP test route has to be shut.
 *
 * Both came out of reading production logs on 2026-09-14.
 *
 * One address asked for a code seven times in ninety seconds. Six of those
 * requests got past "validation passed" and never reached "sending email", and
 * nothing in between said a word -- so a user who was refused and a user whose
 * mail failed left an identical trace. You could not tell, from the server,
 * which had happened.
 *
 * And `POST /auth/admin/test-smtp` had no guard on it at all: any stranger
 * could make production send a Blushy-branded verification email to any
 * address, from the verified sender, on the global IP budget.
 */

before(async () => { await startTestServer(); });
after(async () => { await stopTestServer(); });

/// Collects what the service writes while a request runs.
let lines = [];
let originalWarn;

beforeEach(() => {
  lines = [];
  originalWarn = logger.warn;
  logger.warn = (...args) => { lines.push(args.map(String).join(' ')); };
});

afterEach(() => { logger.warn = originalWarn; });

const uniqueEmail = () => `otp_${randomUUID().slice(0, 8)}@example.com`;

const askForCode = (body) =>
  api('POST', '/auth/send-email-verification', { body });

/// The one line that used to be missing.
const refusalFor = (reason) =>
  lines.find((line) => line.includes('sendEmailVerification: refused') && line.includes(reason));

test('an address that already has an account is refused out loud', async () => {
  const taken = uniqueEmail();
  await createTestUser({ role: 'woman', email: taken });

  const res = await askForCode({
    email: taken,
    password: 'a-long-enough-password',
    mode: 'signup',
  });

  assert.equal(res.status, 409);
  const line = refusalFor('account_already_exists');
  assert.ok(line, `no refusal logged; saw: ${JSON.stringify(lines)}`);
  assert.ok(line.includes(taken), 'the line names which address');
  assert.ok(line.includes('no email sent'), 'and says plainly that nothing went out');
});

test('a password too short to accept is refused out loud', async () => {
  const res = await askForCode({
    email: uniqueEmail(),
    password: 'short',
    mode: 'signup',
  });

  assert.equal(res.status, 400);
  assert.ok(refusalFor('password_too_short'), JSON.stringify(lines));
});

test('a request that is not a signup is refused out loud', async () => {
  const res = await askForCode({
    email: uniqueEmail(),
    password: 'a-long-enough-password',
    mode: 'login',
  });

  assert.equal(res.status, 400);
  assert.ok(refusalFor('mode_not_signup'), JSON.stringify(lines));
});

test('a request with no usable address is refused out loud', async () => {
  // This one threw before the first log line existed, so it left no trace at
  // all -- not even the address it was asked about.
  const res = await askForCode({ password: 'a-long-enough-password', mode: 'signup' });

  assert.equal(res.status, 400);
  assert.ok(
    lines.some((line) => line.includes('email_missing_or_unparseable')),
    JSON.stringify(lines),
  );
});

test('the reason never carries the password', async () => {
  // Distinctive strings, so a match is a leak and not a coincidence with a
  // reason tag -- "short" would have collided with `password_too_short`.
  const weak = 'Zq7';
  const strong = 'Vx9-quokka-lantern-parade';
  await askForCode({ email: uniqueEmail(), password: weak, mode: 'signup' });
  await askForCode({ email: uniqueEmail(), password: strong, mode: 'login' });

  for (const line of lines) {
    assert.ok(!line.includes(weak), `a password reached the log: ${line}`);
    assert.ok(!line.includes(strong), `a password reached the log: ${line}`);
  }
});

test('a stranger cannot make the server send mail', async () => {
  // The whole of the old guard was nothing.
  const res = await api('POST', '/auth/admin/test-smtp', {
    body: { email: 'victim@example.com' },
  });

  assert.equal(res.status, 401, JSON.stringify(res.body));
});

test('nor can a signed-in user who is not an admin', async () => {
  const user = await createTestUser({ role: 'woman' });

  const res = await api('POST', '/auth/admin/test-smtp', {
    token: user.token,
    body: { email: 'victim@example.com' },
  });

  assert.equal(res.status, 403, JSON.stringify(res.body));
});

test('and an admin cannot aim it at someone else', async () => {
  // An admin asking for an arbitrary recipient is still a relay, just one
  // with a login. Only addresses that are already ours are allowed.
  const admin = await createTestUser({ role: 'admin' });

  const res = await api('POST', '/auth/admin/test-smtp', {
    token: admin.token,
    body: { email: 'victim@example.com' },
  });

  assert.equal(res.status, 403, JSON.stringify(res.body));
  assert.match(JSON.stringify(res.body), /own account address|configured test recipient/i);
});
