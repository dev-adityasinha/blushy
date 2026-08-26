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
