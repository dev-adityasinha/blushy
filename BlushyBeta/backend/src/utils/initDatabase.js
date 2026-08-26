import { db } from './db.js';

export async function initDatabase() {
  console.log('Initializing MongoDB database indexes...');

  try {
    const genders = ['man', 'woman'];

    for (const gender of genders) {
      const usersColl = `users_${gender}`;
      await db.collection(usersColl).createIndex(
        { email: 1 },
        { 
          unique: true, 
          partialFilterExpression: { email: { $type: "string" } } 
        }
      );
      await db.collection(usersColl).createIndex({ user_id: 1 }, { unique: true });

      const historyColl = `ai_chat_history_${gender}`;
      await db.collection(historyColl).createIndex({ user_key: 1 });

      const summariesColl = `ai_chat_daily_summaries_${gender}`;
      await db.collection(summariesColl).createIndex({ user_key: 1, summary_date_ist: 1 }, { unique: true });

      const memoryColl = `user_profile_memory_${gender}`;
      await db.collection(memoryColl).createIndex({ user_id: 1 }, { unique: true });

      const sleepColl = `user_sleep_logs_${gender}`;
      await db.collection(sleepColl).createIndex({ user_id: 1, entry_date: 1 });

      const moodColl = `user_daily_moods_${gender}`;
      await db.collection(moodColl).createIndex({ user_id: 1, entry_date: 1 });

      const journalColl = `user_journals_${gender}`;
      await db.collection(journalColl).createIndex({ user_id: 1, entry_date: 1 }, { unique: true });

      const nutritionAnsColl = `user_nutrition_answers_${gender}`;
      await db.collection(nutritionAnsColl).createIndex({ user_id: 1 });

      const nutritionPlanColl = `user_nutrition_plans_${gender}`;
      await db.collection(nutritionPlanColl).createIndex({ user_id: 1 });

      const auditColl = `ai_onboarding_update_audit_${gender}`;
      await db.collection(auditColl).createIndex({ user_id: 1 });
    }

    await db.collection('identities').createIndex({ phone_hash: 1 }, { unique: true });
    await db.collection('auth_email_verifications').createIndex({ email_hash: 1 }, { unique: true });
    await db.collection('email_verifications').createIndex({ created_at: 1 }, { expireAfterSeconds: 1800 });
    await db.collection('auth_email_verifications').createIndex({ created_at: 1 }, { expireAfterSeconds: 1800 });
    await db.collection('auth_otps').createIndex({ phone_hash: 1 }, { unique: true });
    await db.collection('communities').createIndex({ community_id: 1 }, { unique: true });
    await db.collection('community_followers').createIndex({ community_id: 1, user_id: 1 }, { unique: true });
    await db.collection('community_messages').createIndex({ community_id: 1, created_at: 1 });
    await db.collection('posts').createIndex({ author_id: 1, created_at: -1 });
    await db.collection('friendships').createIndex({ user_id_1: 1, user_id_2: 1 }, { unique: true });
    await db.collection('direct_messages').createIndex({ sender_id: 1, recipient_id: 1 });

    console.log('MongoDB database indexes initialized successfully!');
  } catch (error) {
    console.error('Error initializing MongoDB database indexes:', error);
  }
}
