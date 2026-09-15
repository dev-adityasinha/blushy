import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

/**
 * The welcome email, and where it is sent from.
 *
 * It has to hang off the moment an account first exists, not the moment a code
 * is requested: at that point there is no account, and someone who never
 * finishes verification would be welcomed to a family they had not joined.
 */
const emailService = readFileSync(
  new URL('../src/services/emailService.js', import.meta.url), 'utf8');
const emailAuth = readFileSync(
  new URL('../src/services/emailAuthService.js', import.meta.url), 'utf8');
const googleAuth = readFileSync(
  new URL('../src/services/googleAuthService.js', import.meta.url), 'utf8');

test('the template carries both a plain-text and an HTML body', () => {
  // Some clients show only the text part; a mail with no text alternative
  // arrives blank for them.
  const start = emailService.indexOf('async function sendWelcome');
  const body = emailService.slice(start, emailService.indexOf('\n}', start));
  assert.match(body, /const text = \[/);
  assert.match(body, /const html = `/);
  assert.match(body, /deliver\(\{/, 'must use the shared transport');
});

test('it is sent after verification, where the account is created', () => {
  const start = emailAuth.indexOf('async function finalizePendingSignup');
  const body = emailAuth.slice(start, emailAuth.indexOf('\n}', start));
  assert.match(body, /sendWelcome/);

  // And never from the step that only sends the code.
  const requestStart = emailAuth.indexOf('async function sendEmailVerification');
  const requestBody = emailAuth.slice(
    requestStart, emailAuth.indexOf('\n}', requestStart));
  assert.equal(/sendWelcome/.test(requestBody), false,
    'welcoming someone who has not verified yet');
});

test('a first Google sign-in is welcomed too', () => {
  assert.match(googleAuth, /sendWelcome/);
  assert.match(googleAuth, /import \{ logger \}/, 'the catch path needs it');
});

test('a failed welcome cannot fail the signup', () => {
  for (const [name, source] of [['email', emailAuth], ['google', googleAuth]]) {
    const i = source.indexOf('sendWelcome');
    const around = source.slice(Math.max(0, i - 200), i + 300);
    assert.match(around, /try \{/, `${name}: not guarded`);
    assert.match(around, /catch/, `${name}: not guarded`);
  }
});
