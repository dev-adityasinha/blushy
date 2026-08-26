import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import authRoutes from './routes/authRoutes.js';
import aiRoutes from './routes/aiRoutes.js';
import swiggyRoutes from './routes/swiggyRoutes.js';
import communityRoutes from './routes/communityRoutes.js';
import partnerRoutes from './routes/partnerRoutes.js';
import featureRoutes from './routes/featureRoutes.js';
import adminRoutes from './routes/adminRoutes.js';
import postRoutes from './routes/postRoutes.js';
import friendRoutes from './routes/friendRoutes.js';
import directMessageRoutes from './routes/directMessageRoutes.js';
import onboardingRoutes from './routes/onboardingRoutes.js';
import { httpErrorHandler } from './middleware/errorHandler.js';
import { ipRateLimiter } from './middleware/rateLimiters.js';
import { env } from './utils/env.js';

const app = express();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const configuredOrigins = (env.corsOrigin ?? '*')
  .split(',')
  .map((value) => value.trim())
  .filter((value) => value.length > 0);

function isLocalDevOrigin(origin) {
  return /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin);
}

function isAllowedOrigin(origin) {
  if (configuredOrigins.includes('*')) {
    return true;
  }

  if (configuredOrigins.includes(origin)) {
    return true;
  }

  return isLocalDevOrigin(origin);
}

if (env.nodeEnv === 'production') {
  if (!env.corsOrigin || env.corsOrigin === '*') {
    throw new Error('FATAL SECURITY ERROR: CORS_ORIGIN environment variable must be explicitly defined in production and cannot be wildcard "*".');
  }
}

app.set('trust proxy', 1);

app.use(
  helmet({
    hsts: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: env.hstsPreloadEnabled,
    },
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'none'"],
        styleSrc: ["'unsafe-inline'"],
        scriptSrc: ["'none'"],
        imgSrc: ["'self'", 'data:'],
        frameAncestors: ["'none'"],
      },
    },
    frameguard: {
      action: 'deny',
    },
  })
);

app.use((_req, res, next) => {
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()');
  next();
});

app.use(
  cors({
    origin(origin, callback) {
      if (!origin || isAllowedOrigin(origin) || env.nodeEnv !== 'production') {
        callback(null, true);
        return;
      }
      callback(null, false);
    },
    credentials: true,
  }),
);
app.use(express.json({ limit: '32kb' }));

app.get('/', (_, res) => {
  res.status(200).json({
    ok: true,
    service: 'blushy-auth-backend',
    message: 'Backend is running. Use /health for status checks.',
  });
});

app.get('/health', (_, res) => {
  res.json({ ok: true, service: 'blushy-auth-backend' });
});

app.use('/uploads', (req, res, next) => {
  const ext = path.extname(req.path).toLowerCase();
  const allowedImageExts = ['.png', '.jpg', '.jpeg', '.webp', '.svg', '.gif'];
  if (req.path !== '/' && ext && !allowedImageExts.includes(ext)) {
    return res.status(403).json({
      error: {
        code: 'FORBIDDEN_FILE_TYPE',
        message: 'Access denied. Only public image assets are served via this static path.',
      },
    });
  }
  next();
});

app.use('/uploads', express.static(path.resolve(__dirname, '../uploads'), {
  setHeaders: (res, filePath) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    if (/\.(webm|mp3|wav|m4a|ogg)$/i.test(filePath)) {
      res.setHeader('Accept-Ranges', 'bytes');
    }
  },
}));

app.use('/auth', ipRateLimiter, authRoutes);
app.use('/api/auth', ipRateLimiter, authRoutes);
app.use('/ai', ipRateLimiter, aiRoutes);
app.use('/swiggy', ipRateLimiter, swiggyRoutes);
app.use('/community', ipRateLimiter, communityRoutes);
app.use('/partner', ipRateLimiter, partnerRoutes);
app.use('/features', ipRateLimiter, featureRoutes);
app.use('/admin', ipRateLimiter, adminRoutes);
app.use('/posts', ipRateLimiter, postRoutes);
app.use('/friends', ipRateLimiter, friendRoutes);
app.use('/dms', ipRateLimiter, directMessageRoutes);
app.use('/onboarding', ipRateLimiter, onboardingRoutes);
app.use('/api/onboarding', ipRateLimiter, onboardingRoutes);
app.use(httpErrorHandler);

export default app;