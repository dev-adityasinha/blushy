import rateLimit from 'express-rate-limit';

import { createHttpError } from '../utils/httpError.js';
import { env } from '../utils/env.js';
import { createSharedRateLimitStore } from '../utils/redisStore.js';

const isDev = env.nodeEnv !== 'production';

export const ipRateLimiter = rateLimit({
  windowMs: Number(process.env.IP_RATE_LIMIT_WINDOW_MS ?? 5 * 60 * 1000),
  max: Number(process.env.IP_RATE_LIMIT_MAX ?? (isDev ? 300 : 60)),
  standardHeaders: true,
  legacyHeaders: false,
  store: createSharedRateLimitStore('rl:ip:'),
  handler: () => {
    throw createHttpError(429, 'Too many requests from this IP. Please slow down.');
  },
});