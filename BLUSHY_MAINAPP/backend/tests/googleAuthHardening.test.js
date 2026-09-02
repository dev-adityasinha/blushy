import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

/**
 * Google sign-in only proves who someone is if the token was minted for us,
 * and if Google vouches for the address on it.
 *
 * Source-level rather than behavioural: exercising the real path needs a live
 * Google token, and these three properties are the ones whose absence is a
 * silent auth bypass rather than a visible failure.
 */
const source = readFileSync(
  new URL('../src/services/googleAuthService.js', import.meta.url), 'utf8');

test('it fails closed when no client id is configured', () => {
  // It used to fall back to `new OAuth2Client()` and verify against an empty
  // audience, which switches the audience check off entirely.
  assert.equal(source.includes('clients.push(new OAuth2Client())'), false,
    'the unconfigured fallback client is back');
  assert.match(source, /function assertConfigured/);
  assert.match(source, /allowedAudiences\.length === 0/);
});

test('every token path checks the audience', () => {
  assert.match(source, /audience: allowedAudiences/,
    'the ID token path must pin the audience');
  assert.match(source, /allowedAudiences\.includes\(data\.aud\)/,
    'the access token fallback must pin it too');
});

test('an unverified Google email cannot claim an existing account', () => {
  const start = source.indexOf('let user = await userRepository.getUserByGoogleId');
  const body = source.slice(start, start + 700);
  assert.match(body, /emailIsVerified/,
    'linking by email without a verified address is account takeover');
  assert.match(source, /email_verified/);
});

test('the access token fallback rejects an unverified email', () => {
  assert.match(source, /String\(data\.email_verified\) !== 'true'/);
});
