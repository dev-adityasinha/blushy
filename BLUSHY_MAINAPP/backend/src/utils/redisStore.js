import { RedisStore } from 'rate-limit-redis';
import { createClient } from 'redis';

import { env } from './env.js';
import { logger } from './logger.js';

let redisClient = null;
let redisConnecting = null;

async function getRedisClient() {
  const redisUrl = env.redisUrl || process.env.REDIS_URL;
  if (!redisUrl) {
    return null;
  }

  if (redisClient && redisClient.isOpen) {
    return redisClient;
  }

  if (redisConnecting) {
    return redisConnecting;
  }

  redisConnecting = (async () => {
    try {
      const client = createClient({ url: redisUrl });
      client.on('error', (err) => {
        logger.error('Redis rate-limiter client error:', { error: err.message });
      });
      await client.connect();
      redisClient = client;
      logger.info('Connected to shared Redis store for rate limiting.');
      return redisClient;
    } catch (err) {
      logger.error('Failed to connect to Redis for rate limiting; falling back to in-memory store', { error: err.message });
      redisClient = null;
      return null;
    } finally {
      redisConnecting = null;
    }
  })();

  return redisConnecting;
}

/** Warned once rather than once per limiter -- there are five of them. */
let warnedAboutMemoryStore = false;

export function createSharedRateLimitStore(prefix = 'rl:') {
  const redisUrl = env.redisUrl || process.env.REDIS_URL;
  if (!redisUrl) {
    // Falling back to express-rate-limit's in-memory store, which counts per
    // process. That is fine for one process and actively unsafe for several:
    // "5 login attempts per 15 minutes" silently becomes 5 per worker, so four
    // workers give an attacker twenty. The limit looks unchanged in the code
    // and is four times weaker in practice.
    const workers = Math.max(1, Number(process.env.WEB_CONCURRENCY ?? 1));

    if (workers > 1) {
      throw new Error(
        `REDIS_URL is not set but WEB_CONCURRENCY is ${workers}. Rate limits would be counted `
        + 'per process, multiplying every limit by the number of workers -- including the login '
        + 'and OTP limits. Set REDIS_URL, or run a single process.',
      );
    }

    if (!warnedAboutMemoryStore) {
      warnedAboutMemoryStore = true;
      logger.warn(
        'REDIS_URL is not set: rate limits are counted in this process only. Fine for a single '
        + 'process; set REDIS_URL before running more than one, or limits multiply by process count.',
      );
    }

    return undefined;
  }

  return new RedisStore({
    prefix,
    sendCommand: async (...args) => {
      const client = await getRedisClient();
      if (!client || !client.isOpen) {
        throw new Error('Redis client unavailable for rate limiter');
      }
      return client.sendCommand(args);
    },
  });
}

/**
 * A fresh Redis connection, or null when REDIS_URL is not configured.
 *
 * Pub/sub needs its own connections: a subscribed client cannot issue ordinary
 * commands, so the realtime hub must not share the rate limiter's client. Each
 * caller owns what it creates, including closing it.
 */
export async function createRedisConnection(label = 'redis') {
  const redisUrl = env.redisUrl || process.env.REDIS_URL;
  if (!redisUrl) return null;

  try {
    const client = createClient({ url: redisUrl });
    client.on('error', (err) => {
      logger.error(`Redis ${label} client error:`, { error: err.message });
    });
    await client.connect();
    return client;
  } catch (error) {
    logger.error(`Redis ${label} connection failed: ${error.message}`);
    return null;
  }
}
