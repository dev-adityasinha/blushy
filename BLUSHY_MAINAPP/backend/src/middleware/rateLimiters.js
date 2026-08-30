import rateLimit from 'express-rate-limit';

import { createHttpError } from '../utils/httpError.js';
import { env } from '../utils/env.js';
import { createSharedRateLimitStore } from '../utils/redisStore.js';

const isDev = env.nodeEnv !== 'production';

export const ipRateLimiter = rateLimit({
  windowMs: Number(process.env.IP_RATE_LIMIT_WINDOW_MS ?? 5 * 60 * 1000),
  // 60 per five minutes was 0.2 requests a second, and the app spends seven of
  // them just filling the dashboard once. Opening the app, reading the feed and
  // writing a post went over the line easily, and the only thing the user saw
  // was "Failed to publish post" -- the endpoint itself was fine.
  //
  // It is also per IP, and mobile carriers here put many subscribers behind one
  // address, so a handful of unrelated users shared a single budget.
  //
  // Brute force is not what this limiter defends: login, OTP and password reset
  // each carry their own far tighter limits (5, 3 and 5 per fifteen minutes).
  // This one exists to stop scraping and runaway clients, and 2 requests a
  // second still does that.
  max: Number(process.env.IP_RATE_LIMIT_MAX ?? (isDev ? 3000 : 600)),
  standardHeaders: true,
  legacyHeaders: false,
  store: createSharedRateLimitStore('rl:ip:'),
  handler: () => {
    throw createHttpError(429, 'Too many requests from this IP. Please slow down.');
  },
});