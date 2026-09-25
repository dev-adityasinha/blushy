import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

/**
 * Sign in with Apple only proves who someone is if the identity token was
 * signed by Apple, minted for us, and not downgraded to a weaker algorithm.
 *
 * Source-level rather than behavioural: exercising the real path needs a live
 * Apple identity token (and Apple's rotating keys), and these are the
 * properties whose absence is a silent auth bypass rather than a visible
 * failure. Mirrors googleAuthHardening.test.js.
 */
const source = readFileSync(
  new URL('../src/services/appleAuthService.js', import.meta.url), 'utf8');

test('it fails closed when no audience is configured', () => {
  assert.match(source, /function assertConfigured/);
  assert.match(source, /allowedAudiences\.length === 0/,
    'with no bundle/service id, verification must refuse rather than accept any token');
});

test('the token signature is verified against Apple keys, pinning issuer and audience', () => {
  assert.match(source, /appleid\.apple\.com\/auth\/keys/,
    'the public keys must come from Apple');
  assert.match(source, /jwt\.verify\(/, 'the signature must be verified');
  assert.match(source, /audience: allowedAudiences/, 'the audience must be pinned');
  assert.match(source, /issuer: APPLE_ISSUER/, 'the issuer must be pinned to Apple');
});

test('the signing algorithm is pinned to RS256', () => {
  // Refusing anything but RS256 blocks an "alg: none" token and an attempt to
  // have the RSA public key verified as an HMAC shared secret.
  assert.match(source, /alg !== 'RS256'/);
  assert.match(source, /algorithms: \['RS256'\]/);
});

test('an unverified Apple email cannot claim an existing account', () => {
  const start = source.indexOf('let user = await userRepository.getUserByAppleId');
  const body = source.slice(start, start + 700);
  assert.match(body, /emailIsVerified/,
    'linking by email without a verified address is account takeover');
  assert.match(source, /email_verified/);
});

test('the name is never read from the token', () => {
  // Apple only sends the name in the first authorization request body, so it is
  // taken from the client, not trusted from the token payload.
  assert.match(source, /function normalizeName/);
  assert.doesNotMatch(source, /payload\.name/,
    'the display name must not be read from the identity token');
});
