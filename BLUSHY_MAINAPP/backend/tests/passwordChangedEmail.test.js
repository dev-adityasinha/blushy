import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

/**
 * The email that says a password was changed.
 *
 * Not a courtesy. A reset is otherwise silent, so an account taken over
 * through that path gives its owner no signal at all until they next try to
 * sign in — by which point the attacker has had however long they wanted.
 */
const emailService = fs.readFileSync('src/services/emailService.js', 'utf8');
const emailAuth = fs.readFileSync('src/services/emailAuthService.js', 'utf8');

test('the template exists and is exported', () => {
  assert.match(emailService, /async function sendPasswordChanged\(/);
  assert.match(emailService, /\n {2}sendPasswordChanged,/);
});

test('it says what happened in the first line, not after reassurance', () => {
  const start = emailService.indexOf('async function sendPasswordChanged');
  const body = emailService.slice(start, start + 3000);

  assert.match(body, /Your Blushy password was just changed/);
  // Someone who did not do this must not have to read to the end.
  const firstLine = body.indexOf('Your Blushy password was just changed');
  const wasNotYou = body.indexOf('If it was not you');
  assert.ok(firstLine < wasNotYou, 'the reassurance must not come first');
});

test('it tells her what to do if it was not her', () => {
  const start = emailService.indexOf('async function sendPasswordChanged');
  const body = emailService.slice(start, start + 3000);

  assert.match(body, /Reset your password again/);
  // The inbox is the thing that was compromised if this was not her: whoever
  // did it needed the emailed code.
  assert.match(body, /change\s*\n?\s*(?:your )?email password/i);
  assert.match(body, /signed out everywhere/);
});

test('it does not turn an IP into a place', () => {
  const start = emailService.indexOf('async function sendPasswordChanged');
  // The copy only: the comments above it explain why this rule exists and
  // naturally use the very words the copy must avoid.
  const body = emailService
    .slice(start, start + 3000)
    .split('\n')
    .filter((line) => !line.trim().startsWith('//'))
    .join('\n');

  // An IP is not a location, and naming a guessed city would be worse than
  // saying nothing at all.
  for (const word of ['city', 'country', 'location', 'near ']) {
    assert.ok(!body.toLowerCase().includes(word), `must not mention ${word}`);
  }
});

test('it is sent after the password has actually changed', () => {
  const at = emailAuth.indexOf('sendPasswordChanged');
  assert.ok(at > 0, 'the reset must send it');

  const updateAt = emailAuth.indexOf('updatePasswordAndPhone');
  assert.ok(updateAt < at,
    'sending before the write would announce a change that may not happen');
});

test('a delivery failure does not fail the reset', () => {
  // The password really has been changed by this point. Throwing here would
  // report failure for something that succeeded, and she would try again
  // against a password that is already the new one.
  const at = emailAuth.indexOf('sendPasswordChanged');
  const around = emailAuth.slice(at - 400, at + 500);

  assert.match(around, /try \{/);
  assert.match(around, /catch \(error\)/);
  assert.ok(!/throw/.test(around.slice(around.indexOf('catch'))),
    'the catch must not rethrow');
});

test('the reset still reports success when the email cannot be sent', () => {
  const at = emailAuth.indexOf('sendPasswordChanged');
  const after = emailAuth.slice(at, at + 900);
  assert.match(after, /Password reset successful/);
});
