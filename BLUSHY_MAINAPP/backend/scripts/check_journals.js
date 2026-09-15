import { MongoClient } from 'mongodb';
import dotenv from 'dotenv';

dotenv.config();

const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/blushy';
const client = new MongoClient(uri);

async function run() {
  try {
    await client.connect();
    const db = client.db();
    const userId = '5dd0c97e-0f4b-4175-89e7-f36dbb1b0072';
    
    console.log(`Checking data for user: ${userId}`);

    const collections = [
      'users_woman',
      'user_journals_woman',
      'user_daily_moods_woman',
      'user_sleep_logs_woman',
      'ai_chat_daily_summaries_woman'
    ];

    for (const name of collections) {
      const coll = db.collection(name);
      const docs = await coll.find({
        $or: [
          { user_id: userId },
          { _id: userId }
        ]
      }).toArray();
      console.log(`\n--- Collection: ${name} (count: ${docs.length}) ---`);
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
