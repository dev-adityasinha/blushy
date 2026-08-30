import { MongoMemoryServer } from 'mongodb-memory-server';

/**
 * Global test setup (`node --test --test-global-setup=...`).
 *
 * Starts one in-memory MongoDB for the whole run and exports its URI through
 * the environment, so every test file gets a real database without anyone
 * needing a local mongod. Test processes inherit these variables.
 *
 * Without this, any test file that imports `src/utils/db.js` hangs, because
 * that module connects at import time.
 */

let mongo = null;

export async function globalSetup() {
  mongo = await MongoMemoryServer.create();

  process.env.MONGODB_URI = `${mongo.getUri()}blushy_test`;
  process.env.JWT_SECRET = process.env.JWT_SECRET ?? 'test-secret-that-is-long-enough-for-local-tests';
  process.env.NODE_ENV = 'test';
  process.env.CORS_ORIGIN = '*';
  process.env.SEED_CONTENT_AUTO_APPROVE = 'true';
  // The suite issues far more than the dev default of 300 requests from a
  // single IP. Raised through the knob the middleware already reads, so the
  // limiter itself stays under test elsewhere rather than being disabled.
  process.env.IP_RATE_LIMIT_MAX = '100000';
  // Suppress the background schedulers; tests drive everything explicitly.
  process.env.COMMUNITY_CLEANUP_ENABLED = 'false';
  process.env.DAILY_CHAT_SUMMARY_ENABLED = 'false';
}

export async function globalTeardown() {
  if (mongo) {
    await mongo.stop();
    mongo = null;
  }
}
