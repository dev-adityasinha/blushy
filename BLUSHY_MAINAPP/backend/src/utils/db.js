import dns from 'node:dns';

import { MongoClient } from 'mongodb';
import { env } from './env.js';

if (!env.mongodbUri) {
  throw new Error('Missing required environment variable: MONGODB_URI');
}

// A `mongodb+srv://` URI is resolved through a DNS SRV lookup, and some
// networks refuse SRV queries outright -- the driver then reports
// `querySrv ECONNREFUSED`, which reads like the cluster is down when in fact
// the resolver never asked it anything. Pointing at a public resolver is the
// fix, but only where it is needed, so this stays opt-in:
//
//   DNS_SERVERS=8.8.8.8,1.1.1.1
//
// Hosted environments resolve SRV correctly and should leave this unset.
if (env.dnsServers.length > 0) {
  dns.setServers(env.dnsServers);
  console.log(`Using DNS servers: ${env.dnsServers.join(', ')}`);
}

// Connection pool bounds.
//
// The driver's defaults are maxPoolSize 100, waitQueueTimeoutMS 0 and
// maxIdleTimeMS 0, and all three are wrong for a shared cluster reached from
// several small instances. Measured on this deployment: the cluster allows
// **500 connections in total**, so at 100 per process a sixth instance cannot
// connect at all -- it does not run slowly, it fails to start.
//
// Each is overridable, because the right numbers depend on the plan the
// cluster is on and these are sized for the current one.
const client = new MongoClient(env.mongodbUri, {
  // How many queries one instance may run at once. 20 leaves room for 25
  // instances inside 500. It is generous for the CPU an instance actually has:
  // a Node process on a fraction of a core cannot usefully drive 100
  // concurrent queries, so the extra 80 were never capacity, only claim.
  maxPoolSize: env.mongoMaxPoolSize,

  // What happens to a query that finds every connection busy. The default is
  // to wait for ever, which turns a saturated pool into a hang with no error
  // and no log -- and the AI routes here can hold a connection for tens of
  // seconds, which is exactly when it would bite. A bounded wait makes the
  // same situation a `MongoWaitQueueTimeoutError` that can be caught, logged
  // and answered with a 503.
  waitQueueTimeoutMS: env.mongoWaitQueueTimeoutMs,

  // When an idle connection is handed back. The default keeps every connection
  // opened during a burst for the lifetime of the process, so instances sitting
  // idle overnight still hold the whole budget and a new instance cannot start.
  maxIdleTimeMS: env.mongoMaxIdleTimeMs,
});

let connected = false;
for (let attempt = 1; attempt <= 5; attempt++) {
  try {
    await client.connect();
    console.log('Connected successfully to MongoDB');
    connected = true;
    break;
  } catch (error) {
    console.error(`MongoDB connection attempt ${attempt} failed:`, error.message);
    if (attempt < 5) {
      await new Promise((res) => setTimeout(res, 2000));
    }
  }
}

if (!connected) {
  throw new Error('Failed to connect to MongoDB after multiple attempts');
}

const dbName = new URL(env.mongodbUri).pathname.replace('/', '') || 'blushy';
export const db = client.db(dbName);

/**
 * Closes the shared client. Used by the test harness and graceful shutdown so
 * the process is not held open by an idle connection pool.
 */
export async function closeDb() {
  await client.close();
}

export async function withTransaction(executor) {
  return executor(db);
}

/**
 * Finds one user without knowing which collection they are in.
 *
 * The two probes run together rather than one after the other. Sequentially,
 * every woman's record cost two round trips because the men's collection was
 * always checked and missed first -- and this sits under nearly every request,
 * so the cost was paid everywhere.
 *
 * A hit in `users_man` still wins, which is the order the sequential version
 * resolved in.
 */
export async function findUserDocument(query) {
  const [man, woman] = await Promise.all([
    db.collection('users_man').findOne(query),
    db.collection('users_woman').findOne(query),
  ]);
  return man ?? woman ?? null;
}

/** Batch form of the above; both collections are read at once. */
export async function findUserDocuments(query) {
  const [men, women] = await Promise.all([
    db.collection('users_man').find(query).toArray(),
    db.collection('users_woman').find(query).toArray(),
  ]);
  return [...men, ...women];
}
