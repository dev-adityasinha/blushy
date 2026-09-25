import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import createHttpError from 'http-errors';
import { env } from '../utils/env.js';
import { userRepository } from '../repositories/userRepository.js';
import { signAccessToken } from './tokenService.js';
import { normalizeRole } from '../utils/role.js';
import { emailService } from './emailService.js';
import { logger } from '../utils/logger.js';

const APPLE_ISSUER = 'https://appleid.apple.com';
const APPLE_KEYS_URL = 'https://appleid.apple.com/auth/keys';

/**
 * The audiences this server will accept an Apple identity token for.
 *
 * Apple sets the token's `aud` to the client it was minted for: the app's
 * bundle id for the native iOS flow, or the Services id for the web/Android
 * redirect flow. A token is only proof of identity if it was minted for *us* --
 * anyone can obtain a valid Apple token for their own app -- so we pin these.
 */
const allowedAudiences = [
  env.appleBundleId,
  env.appleServiceId,
].filter(Boolean);

/**
 * Refuses to verify anything when nothing is configured.
 *
 * Verifying against an empty audience list switches the audience check off, so
 * with the env vars missing an Apple token issued to any other app would be
 * accepted. Failing closed turns a silent auth bypass into an obvious
 * misconfiguration, mirroring the Google path.
 */
function assertConfigured() {
  if (allowedAudiences.length === 0) {
    logger.error(
      'Apple sign-in is not configured: set APPLE_BUNDLE_ID and/or ' +
      'APPLE_SERVICE_ID to the client id(s) Apple mints the identity token for.',
    );
    throw createHttpError(503, 'Apple sign-in is not available right now.');
  }
}

// Apple's public keys, cached between requests. Apple rotates them, so a `kid`
// we do not recognise triggers a single refetch before the token is refused.
let cachedKeys = null;
let cachedAt = 0;
const KEYS_TTL_MS = 60 * 60 * 1000; // 1 hour

async function fetchAppleKeys() {
  // A timeout so a stalled keys request fails the sign-in in eight seconds
  // rather than hanging it, the same guard the Google fallback uses.
  const response = await fetch(APPLE_KEYS_URL, { signal: AbortSignal.timeout(8000) });
  if (!response.ok) {
    throw new Error(`Apple keys endpoint returned HTTP ${response.status}`);
  }
  const data = await response.json();
  if (!data || !Array.isArray(data.keys) || data.keys.length === 0) {
    throw new Error('Apple keys endpoint returned no keys');
  }
  cachedKeys = data.keys;
  cachedAt = Date.now();
  return cachedKeys;
}

async function getApplePublicKey(kid) {
  const fresh = cachedKeys && (Date.now() - cachedAt) < KEYS_TTL_MS;
  let keys = fresh ? cachedKeys : await fetchAppleKeys();
  let jwk = keys.find((k) => k.kid === kid);
  if (!jwk) {
    // The key may have rotated since the cache was filled; refetch once.
    keys = await fetchAppleKeys();
    jwk = keys.find((k) => k.kid === kid);
  }
  if (!jwk) {
    throw new Error(`no Apple signing key matches kid ${kid}`);
  }
  return crypto.createPublicKey({ key: jwk, format: 'jwk' });
}

async function verifyIdentityToken(identityToken) {
  assertConfigured();

  if (typeof identityToken !== 'string' || identityToken.split('.').length !== 3) {
    throw createHttpError(401, 'Apple identity token is malformed.');
  }

  const decoded = jwt.decode(identityToken, { complete: true });
  const kid = decoded?.header?.kid;
  const alg = decoded?.header?.alg;
  // Apple signs identity tokens with RS256. Pinning the algorithm here (and
  // again in jwt.verify) refuses a token that tries to downgrade to "none" or
  // to an HMAC alg the public key would be misused as a shared secret for.
  if (!kid || alg !== 'RS256') {
    throw createHttpError(401, 'Apple identity token has an unexpected header.');
  }

  let publicKey;
  try {
    publicKey = await getApplePublicKey(kid);
  } catch (e) {
    logger.warn(`appleLogin: could not resolve Apple signing key (${e.message})`);
    throw createHttpError(401, `Invalid Apple identity token: ${e.message}`);
  }

  try {
    const payload = jwt.verify(identityToken, publicKey, {
      algorithms: ['RS256'],
      audience: allowedAudiences,
      issuer: APPLE_ISSUER,
    });
    logger.info('appleLogin: identity token verified');
    return payload;
  } catch (e) {
    logger.warn(`appleLogin: identity token rejected (${e.message})`);
    throw createHttpError(401, `Invalid Apple identity token: ${e.message}`);
  }
}

/**
 * Apple sends the user's name only in the *first* authorization's request body
 * (never in the identity token), as `{givenName, familyName}` from the Flutter
 * `sign_in_with_apple` plugin or a plain string. It is untrusted display text,
 * used only to fill a blank name when the account is first created.
 */
function normalizeName(fullName) {
  if (!fullName) {
    return null;
  }
  if (typeof fullName === 'string') {
    const s = fullName.trim();
    return s.length > 0 ? s : null;
  }
  if (typeof fullName === 'object') {
    const parts = [fullName.givenName, fullName.familyName]
      .filter((p) => typeof p === 'string' && p.trim().length > 0)
      .map((p) => p.trim());
    return parts.length > 0 ? parts.join(' ') : null;
  }
  return null;
}

export async function signInWithApple(identityToken, { role = 'woman', fullName = null, email: emailFromClient = null } = {}) {
  if (typeof identityToken !== 'string' || identityToken.trim().length === 0) {
    logger.warn('appleLogin: request arrived with no token');
    throw createHttpError(400, 'Apple identity token is required.');
  }

  const requestedRole = normalizeRole(role, 'woman');
  logger.info(`appleLogin: attempt received (role=${requestedRole})`);

  const payload = await verifyIdentityToken(identityToken);
  const appleId = payload.sub;
  if (!appleId) {
    throw createHttpError(400, 'Apple identity token payload is missing the user subject ID.');
  }

  // The email lives in the token; the name never does, so it comes from the
  // client (first sign-in only). Apple reports email_verified/is_private_email
  // as either booleans or the strings "true"/"false" depending on the flow.
  const email = payload.email ?? emailFromClient ?? null;
  const emailIsVerified = payload.email_verified === true ||
    String(payload.email_verified) === 'true';
  const displayName = normalizeName(fullName) || 'Blushy User';

  let user = await userRepository.getUserByAppleId(appleId);

  // Only an address Apple has verified may be matched to an existing account,
  // mirroring the Google path: linking by an unverified address would let a
  // token bearing someone else's email be joined straight into their account.
  if (!user && email && emailIsVerified) {
    const existingUser = await userRepository.getUserByEmail(email);
    if (existingUser) {
      user = await userRepository.linkAppleId(existingUser.user_id, appleId);
    }
  }

  if (user) {
    const accountRole = normalizeRole(user.role, 'woman');
    if (requestedRole && requestedRole !== accountRole) {
      const accountRoleLabel = accountRole === 'woman' ? "a Woman's" : "a Partner/Man's";
      const correctExperience = accountRole === 'woman' ? 'Woman' : 'Partner';
      throw createHttpError(
        403,
        `This account is registered as ${accountRoleLabel} account. Please switch to the ${correctExperience} experience to sign in.`,
        { accountRole, requestedRole },
      );
    }
  } else {
    user = await userRepository.createUser({
      email,
      displayName,
      role: requestedRole,
      appleId,
      // Apple vouches for the address itself, so a verified email needs no OTP
      // step; an unverified/relay address is stored without a verified marker.
      emailVerifiedAt: emailIsVerified ? new Date().toISOString() : null,
    });

    if (email) {
      try {
        await emailService.sendWelcome({ to: email, name: displayName ?? null });
      } catch (error) {
        logger.warn(`appleLogin: welcome email failed for ${email}: ${error?.message ?? error}`);
      }
    }
  }

  const token = signAccessToken({ userId: user.user_id });

  return {
    message: 'Apple login successful.',
    token,
    tokenType: 'Bearer',
    expiresIn: 604800,
    userId: user.user_id,
    role: user.role,
    email: user.email,
    displayName: user.displayName,
    cycleStartDate: user.cycleStartDate,
    onboardingCompleted: Boolean(user.onboardingCompletedAt || (user.onboardingAnswers && Object.keys(user.onboardingAnswers).length > 0) || user.cycleStartDate),
  };
}

export const appleAuthService = {
  signInWithApple,
};
