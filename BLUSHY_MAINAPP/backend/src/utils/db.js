import { MongoClient } from 'mongodb';
import { env } from './env.js';

if (!env.mongodbUri) {
  throw new Error('Missing required environment variable: MONGODB_URI');
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
