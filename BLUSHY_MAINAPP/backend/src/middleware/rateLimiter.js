import rateLimit from 'express-rate-limit';
import { createSharedRateLimitStore } from '../utils/redisStore.js';

function buildAuthKey(req) {
  const email = typeof req.body?.email === 'string' ? req.body.email.trim().toLowerCase() : '';
  const ip = req.ip || req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown-ip';
  return `${ip}_${email}`;
}

export const loginRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: buildAuthKey,
  // Only wrong passwords count. This used to count every request, so signing
  // in on a second device, or reinstalling, spent the budget without anybody
  // mistyping anything -- and then the next genuine attempt was refused. What
  // this limiter defends against is made of failures; successes are noise in
  // it, and expensive noise for the person locked out.
  skipSuccessfulRequests: true,
  store: createSharedRateLimitStore('rl:auth:login:'),
  message: {
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many login attempts. Please try again in 15 minutes.',
    },
  },
});

export const otpRequestRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 3,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: buildAuthKey,
  store: createSharedRateLimitStore('rl:auth:otpreq:'),
  message: {
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many verification code requests. Please wait 15 minutes before trying again.',
    },
  },
});

export const otpConfirmRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: buildAuthKey,
  // Same reasoning as the login limiter: a code that was right is not an
  // attempt to guess one. Deliberately NOT set on otpRequestRateLimiter,
  // where each success sends an email and counting them is the whole point.
  skipSuccessfulRequests: true,
  store: createSharedRateLimitStore('rl:auth:otpconf:'),
  message: {
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many code verification attempts. Please wait 15 minutes before trying again.',
    },
  },
});

export const passwordResetRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: buildAuthKey,
  store: createSharedRateLimitStore('rl:auth:pwdreset:'),
  message: {
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many password reset attempts. Please try again in 15 minutes.',
    },
  },
});

/**
 * Wipes the failed-attempt record for whoever just signed in.
 *
 * `skipSuccessfulRequests` stops a success from adding to the count, but it
 * does not clear the failures already there: mistype four times, get it right
 * on the fifth, and the next quarter of an hour still starts four deep. A
 * correct password is proof this is the account's owner, which is exactly the
 * thing an attacker does not have -- so it is safe to forget the failures, and
 * unkind not to.
 *
 * Never throws. Failing to reset a counter must not fail a login that has
 * already succeeded.
 */
export async function clearLoginAttempts(req) {
  try {
    await loginRateLimiter.resetKey(buildAuthKey(req));
  } catch {
    // The store is shared and may be unreachable; the login still stands.
  }
}
