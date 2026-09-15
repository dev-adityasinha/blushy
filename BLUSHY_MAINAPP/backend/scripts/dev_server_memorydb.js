/**
 * Runs the real server against a throwaway in-memory MongoDB.
 *
 * Useful for local development and for smoke-testing the API without
 * installing mongod. Everything else - routes, middleware, seeding - is
 * exactly the production path.
 *
 *   node scripts/dev_server_memorydb.js
 */

import { MongoMemoryServer } from 'mongodb-memory-server';

const mongo = await MongoMemoryServer.create();

process.env.MONGODB_URI = `${mongo.getUri()}blushy_dev`;
process.env.JWT_SECRET = process.env.JWT_SECRET ?? 'local-development-secret-at-least-32-chars';
process.env.NODE_ENV = process.env.NODE_ENV ?? 'development';
process.env.PORT = process.env.PORT ?? '3000';
process.env.CORS_ORIGIN = process.env.CORS_ORIGIN ?? '*';
// Non-production only: lets the seeded clinical content be served without a
// manual approval pass. contentSeedService refuses this in production.
process.env.SEED_CONTENT_AUTO_APPROVE = process.env.SEED_CONTENT_AUTO_APPROVE ?? 'true';
process.env.COMMUNITY_CLEANUP_ENABLED = 'false';
process.env.DAILY_CHAT_SUMMARY_ENABLED = 'false';

console.log(`[dev] in-memory MongoDB at ${process.env.MONGODB_URI}`);

await import('../src/server.js');

async function shutdown() {
  await mongo.stop().catch(() => {});
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
