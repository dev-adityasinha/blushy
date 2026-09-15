/**
 * The real server on a throwaway in-memory MongoDB, for walking every
 * endpoint with real requests without touching the Atlas data.
 *
 * Same as dev_server_memorydb.js, plus: each one-time code the app would
 * have emailed is also appended to a file, so a walk can complete signup
 * and reset flows without an inbox. The email is still attempted for real,
 * so delivery is exercised and its outcome logged; a failure to deliver
 * does not stop the flow here, because the point is the endpoints.
 *
 *   PORT=3100 node scripts/live_walk_server.mjs
 */
import { MongoMemoryServer } from 'mongodb-memory-server';
import { appendFileSync } from 'node:fs';

const CODES = process.env.LIVE_WALK_CODES ?? 'live_walk_codes.log';

const mongo = await MongoMemoryServer.create();

process.env.MONGODB_URI = `${mongo.getUri()}blushy_walk`;
process.env.NODE_ENV = 'development';
process.env.PORT = process.env.PORT ?? '3100';
process.env.CORS_ORIGIN = '*';
process.env.SEED_CONTENT_AUTO_APPROVE = 'true';
process.env.COMMUNITY_CLEANUP_ENABLED = 'false';
process.env.DAILY_CHAT_SUMMARY_ENABLED = 'false';

const { emailService } = await import('../src/services/emailService.js');

function record(kind, email, code) {
  appendFileSync(CODES, `${new Date().toISOString()} ${kind} ${email} ${code}\n`);
}

for (const name of Object.keys(emailService)) {
  const fn = emailService[name];
  if (typeof fn !== 'function') continue;
  emailService[name] = async (...args) => {
    const email = args[0];
    const code = args.find((a, i) => i > 0 && typeof a === 'string' && /^\d{4,8}$/.test(a));
    if (code) record(name, email, code);
    try {
      return await fn.apply(emailService, args);
    } catch (err) {
      console.log(`[walk] ${name} to ${email} did not deliver: ${err?.message?.split('\n')[0]}`);
      return { delivered: false, walk: true };
    }
  };
}

console.log(`[walk] in-memory MongoDB at ${process.env.MONGODB_URI}; codes -> ${CODES}`);

await import('../src/server.js');

async function shutdown() {
  await mongo.stop().catch(() => {});
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
