import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { MongoMemoryServer } from 'mongodb-memory-server';

/**
 * Integration test harness.
 *
 * Boots an in-memory MongoDB and the real Express app on an ephemeral port, so
 * tests exercise the actual routes, middleware and repositories rather than
 * mocks. MONGODB_URI must be set before `app.js` is imported, because
 * `utils/db.js` connects at module load, so every import here is dynamic.
 */

let mongo = null;
let server = null;
let baseUrl = null;
let db = null;
let closeDb = null;

export async function startTestServer() {
  if (server) return { baseUrl, db };

  // Reuse the run-wide database from globalSetup when there is one; only start
  // a private instance for a standalone run of this file.
  if (!process.env.MONGODB_URI || process.env.MONGODB_URI.includes('27017')) {
    mongo = await MongoMemoryServer.create();
    process.env.MONGODB_URI = `${mongo.getUri()}blushy_integration_test`;
  }

  process.env.JWT_SECRET = process.env.JWT_SECRET ?? 'test-secret-that-is-long-enough-for-local-tests';
  process.env.NODE_ENV = 'test';
  process.env.CORS_ORIGIN = '*';
  // Content must be servable for the read paths under test; the flag is refused
  // in production by contentSeedService.
  // The suite issues far more than the dev default of 300 requests from a
  // single IP. Raised through the knob the middleware already reads, so the
  // limiter itself stays under test elsewhere rather than being disabled.
  process.env.IP_RATE_LIMIT_MAX = '100000';
  // No AI provider in tests: the suite must never make a live API call, and
  // several tests assert that safety guidance still works when the model is
  // unreachable. Cleared explicitly rather than relying on the developer's
  // .env happening to be empty -- when it was not, those tests silently
  // started calling the real provider.
  // Set to empty rather than deleted: dotenv only skips keys already present,
  // so a deleted key is repopulated from .env when app.js loads.
  for (const key of [
    'AI_CHAT_API_KEY', 'OPENROUTER_API_KEY', 'GROK_API_KEY',
    'SPEECH_TO_TEXT_API_KEY', 'GROQ_API_KEY',
    // Same reasoning for mail: with a real SMTP_HOST configured the suite
    // opens actual connections to the mail server, which is slow and sends
    // real messages. Blank means emailService takes its dev fallback.
    'SMTP_HOST', 'EMAIL_FROM', 'SMTP_USER', 'SMTP_PASSWORD',
  ]) {
    process.env[key] = '';
  }
  process.env.SEED_CONTENT_AUTO_APPROVE = 'true';

  const { default: app } = await import('../../src/app.js');
  const { initDatabase } = await import('../../src/utils/initDatabase.js');
  const { bootstrapMedicalContent } = await import('../../src/services/contentSeedService.js');
  const dbModule = await import('../../src/utils/db.js');

  db = dbModule.db;
  closeDb = dbModule.closeDb;
  await initDatabase();
  await bootstrapMedicalContent();

  server = createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  baseUrl = `http://127.0.0.1:${port}`;

  return { baseUrl, db };
}

export async function stopTestServer() {
  if (server) {
    await new Promise((resolve) => server.close(resolve));
    server = null;
  }
  if (closeDb) {
    // The Mongo connection pool would otherwise hold the test process open.
    await closeDb().catch(() => {});
    closeDb = null;
  }
  if (mongo) {
    await mongo.stop();
    mongo = null;
  }
  baseUrl = null;
  db = null;
}

/**
 * Creates a user directly in the collection the auth middleware reads, and
 * returns a token minted with the same claims the real login flow uses.
 */
export async function createTestUser({ role = 'woman', email = null, displayName = 'Test User', onboardingAnswers = {} } = {}) {
  const userId = `test_${randomUUID().replace(/-/g, '').slice(0, 16)}`;
  const collection = role === 'man' ? 'users_man' : 'users_woman';

  await db.collection(collection).insertOne({
    user_id: userId,
    email: email ?? `${userId}@example.test`,
    display_name: displayName,
    password_hash: 'not-a-real-hash',
    role,
    token_version: 1,
    onboarding_answers: onboardingAnswers,
    created_at: new Date(),
    updated_at: new Date(),
  });

  const token = jwt.sign(
    { userId, role, tokenVersion: 1 },
    process.env.JWT_SECRET,
    { algorithm: 'HS256', expiresIn: '1h' },
  );

  return { userId, token, role, collection };
}

export async function createAdminUser() {
  return createTestUser({ role: 'admin' });
}

/**
 * Minimal fetch wrapper that returns { status, body } so assertions stay short.
 */
export async function api(method, path, { token = null, body = null, headers = {} } = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    body: body === null ? undefined : JSON.stringify(body),
  });

  const text = await response.text();
  let parsed = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = text;
  }

  return { status: response.status, body: parsed };
}

export function getDb() {
  return db;
}
