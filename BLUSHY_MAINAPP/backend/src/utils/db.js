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

const client = new MongoClient(env.mongodbUri);

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

export async function findUserDocument(query) {
  let user = await db.collection('users_man').findOne(query);
  if (!user) {
    user = await db.collection('users_woman').findOne(query);
  }
  return user;
}

export async function findUserDocuments(query) {
  const men = await db.collection('users_man').find(query).toArray();
  const women = await db.collection('users_woman').find(query).toArray();
  return [...men, ...women];
}
