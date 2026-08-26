import { MongoClient } from 'mongodb';
import dotenv from 'dotenv';

dotenv.config();

const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/blushy';
const client = new MongoClient(uri);

async function run() {
  try {
    await client.connect();
    const db = client.db();

    for (const gender of ['man', 'woman']) {
      const collName = `user_journals_${gender}`;
      const coll = db.collection(collName);
      const docs = await coll.find({}).toArray();
      console.log(`\n--- Collection: ${collName} (count: ${docs.length}) ---`);
      if (docs.length > 0) {
        console.dir(docs, { depth: null });
      }
    }
  } catch (err) {
    console.error(err);
  } finally {
    await client.close();
  }
}

run();
