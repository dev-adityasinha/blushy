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

export function createSharedRateLimitStore(prefix = 'rl:') {
  const redisUrl = env.redisUrl || process.env.REDIS_URL;
  if (!redisUrl) {
    return undefined; // express-rate-limit will use MemoryStore by default
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
