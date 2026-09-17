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

      const periodColl = `user_period_logs_${gender}`;
      await db.collection(periodColl).createIndex({ user_id: 1, period_start_date: -1 });
      await db.collection(periodColl).createIndex({ user_id: 1, period_start_date: 1 }, { unique: true });
    }

    await db.collection('user_state').createIndex({ user_id: 1, key: 1 }, { unique: true });
    await db.collection('identities').createIndex({ phone_hash: 1 }, { unique: true });
    await db.collection('auth_email_verifications').createIndex({ email_hash: 1 }, { unique: true });
    await db.collection('email_verifications').createIndex({ created_at: 1 }, { expireAfterSeconds: 1800 });
    await db.collection('auth_email_verifications').createIndex({ created_at: 1 }, { expireAfterSeconds: 1800 });
    await db.collection('auth_otps').createIndex({ phone_hash: 1 }, { unique: true });
    await db.collection('communities').createIndex({ community_id: 1 }, { unique: true });
    await db.collection('community_followers').createIndex({ community_id: 1, user_id: 1 }, { unique: true });
    await db.collection('posts').createIndex({ post_id: 1 }, { unique: true, sparse: true });
    await db.collection('posts').createIndex({ author_id: 1, created_at: -1 });
    await db.collection('posts').createIndex({ privacy: 1, created_at: -1 });
    await db.collection('posts').createIndex({ privacy: 1, score: -1 });
    await db.collection('posts').createIndex({ post_type: 1 });
    await db.collection('friendships').createIndex({ user_id_1: 1, user_id_2: 1 }, { unique: true });
    await db.collection('direct_messages').createIndex({ sender_id: 1, recipient_id: 1 });

    // ---- Spec-aligned collections (Blushy Backend & AI Feature Specification) ----
    // Health events: read paths are always (user, type, time) or (user, time).
    await db.collection('health_events').createIndex({ user_id: 1, timestamp: -1 });
    await db.collection('health_events').createIndex({ user_id: 1, event_type: 1, timestamp: -1 });
    await db.collection('health_events').createIndex({ event_id: 1 }, { unique: true });
    // Idempotent offline sync: one row per client-supplied event id per user.
    await db.collection('health_events').createIndex(
      { user_id: 1, client_event_id: 1 },
      { unique: true, partialFilterExpression: { client_event_id: { $type: 'string' } } },
    );

    await db.collection('user_life_stage').createIndex({ user_id: 1 }, { unique: true });
    await db.collection('user_life_stage_transitions').createIndex({ user_id: 1, created_at: -1 });

    await db.collection('user_insights').createIndex({ insight_id: 1 }, { unique: true });
    await db.collection('user_insights').createIndex({ user_id: 1, status: 1, confidence: -1 });
    await db.collection('user_insights').createIndex({ user_id: 1, dedupe_key: 1 });
    await db.collection('user_insights').createIndex({ user_id: 1, source_event_ids: 1 });
    await db.collection('user_insight_feedback').createIndex({ user_id: 1, insight_id: 1 });

    await db.collection('user_care_plan_actions').createIndex({ user_id: 1, action_id: 1, surfaced_at: -1 });
    await db.collection('user_reflections').createIndex({ user_id: 1, period_key: 1 }, { unique: true });
    await db.collection('user_screenings').createIndex({ user_id: 1, instrument_id: 1, completed_at: -1 });
    await db.collection('user_content_progress').createIndex({ user_id: 1, content_id: 1 }, { unique: true });
    await db.collection('user_content_progress').createIndex({ user_id: 1, bookmarked: 1 });

    await db.collection('medical_content').createIndex({ content_id: 1 }, { unique: true });
    await db.collection('medical_content').createIndex({ status: 1, life_stages: 1, audience: 1 });
    await db.collection('medical_content').createIndex({ status: 1, review_due_date: 1 });
    await db.collection('medical_content_audit').createIndex({ content_id: 1, created_at: -1 });

    await db.collection('partner_support_requests').createIndex({ request_id: 1 }, { unique: true });
    await db.collection('partner_support_requests').createIndex({ connection_id: 1, created_at: -1 });
    await db.collection('partner_support_requests').createIndex({ partner_user_id: 1, state: 1 });
    await db.collection('partner_permission_audit').createIndex({ connection_id: 1, created_at: -1 });

    await db.collection('notifications').createIndex({ notification_id: 1 }, { unique: true });
    await db.collection('notifications').createIndex({ user_id: 1, status: 1, scheduled_for: -1 });
    await db.collection('notifications').createIndex({ entity_type: 1, entity_id: 1 });
    await db.collection('notifications').createIndex(
      { user_id: 1, dedupe_key: 1 },
      { unique: true, partialFilterExpression: { dedupe_key: { $type: 'string' } } },
    );
    await db.collection('notification_preferences').createIndex({ user_id: 1 }, { unique: true });
    await db.collection('push_device_tokens').createIndex({ user_id: 1, token: 1 }, { unique: true });
    await db.collection('push_delivery_log').createIndex({ user_id: 1, created_at: -1 });

    await db.collection('safety_incident_audit').createIndex({ user_id: 1, created_at: -1 });
    await db.collection('safety_incident_audit').createIndex({ reviewed: 1, created_at: -1 });
    await db.collection('analytics_events').createIndex({ event_name: 1, created_at: -1 });
    await db.collection('analytics_events').createIndex({ pseudonymous_id: 1, created_at: -1 });
    await db.collection('doctor_summaries').createIndex({ user_id: 1, created_at: -1 });

    // Scheduler leadership. The unique key is what makes the race safe: two
    // instances starting together both try to insert, and exactly one wins.
    await db.collection('scheduler_leases').createIndex({ lease_id: 1 }, { unique: true });

    // AI spend. Queried as "what did feature X cost since date Y", and
    // occasionally per user. No TTL: this is the cost record, and throwing it
    // away is how the question became unanswerable in the first place.
    await db.collection('ai_usage_events').createIndex({ created_at: -1 });
    await db.collection('ai_usage_events').createIndex({ feature: 1, created_at: -1 });
    await db.collection('ai_usage_events').createIndex({ user_id: 1, created_at: -1 });

    // Discover's daily feed. The unique key is what makes two requests racing
    // to generate the same day converge on one row instead of duplicating, and
    // the TTL is what stops this growing forever -- the failing behaviour of
    // the in-memory Map it replaced.
    await db.collection('discover_daily_cache').createIndex({ cache_key: 1 }, { unique: true });
    await db.collection('discover_daily_cache').createIndex(
      { created_at: 1 },
      { expireAfterSeconds: 48 * 60 * 60 },
    );

    // Consent ledger. Every read is "this user's latest row", so the sort key
    // belongs in the index -- otherwise the check runs on every app launch and
    // scans the user's whole consent history to find one document. No TTL:
    // the record's purpose is to outlive the moment it describes.
    await db.collection('user_consents').createIndex({ user_id: 1, granted_at: -1 });
    await db.collection('user_consents').createIndex({ consent_id: 1 }, { unique: true });

    // Community moderation (spec §12, §22).
    await db.collection('posts').createIndex({ audience: 1, moderation_state: 1, created_at: -1 });
    await db.collection('posts').createIndex({ requires_human_review: 1, moderation_updated_at: 1 });
    await db.collection('community_blocks').createIndex(
      { blocker_user_id: 1, blocked_user_id: 1 },
      { unique: true },
    );
    await db.collection('community_blocks').createIndex({ blocked_user_id: 1 });
    await db.collection('community_moderation_audit').createIndex({ post_id: 1, created_at: -1 });
    await db.collection('comments').createIndex({ requires_human_review: 1, moderation_updated_at: 1 });
    await db.collection('comments').createIndex({ post_id: 1, moderation_state: 1 });

    // Partner chat. This had no index at all while being the fastest growing
    // collection in the database -- every read of a conversation, every unread
    // count and every cleanup scanned all messages for every connection.
    await db.collection('partner_chat_messages').createIndex({ connection_id: 1, created_at: -1 });
    // Unread counts filter on sender and read flag within a connection.
    await db.collection('partner_chat_messages').createIndex(
      { connection_id: 1, sender_user_id: 1, is_read: 1 },
    );
    // A viewer's vote on a post is read once per post in the feed.
    await db.collection('post_votes').createIndex({ user_id: 1, target_id: 1 });
    await db.collection('post_votes').createIndex({ target_id: 1 });

    // Partner invite rate limiting. The check counts recent events for a key,
    // and the collection had no index at all -- so every invite scanned it.
    await db.collection('partner_rate_limit_events').createIndex({ key: 1, created_at: -1 });
    // And nothing ever deleted the rows: events from weeks ago were still
    // being scanned to answer a question about the last ten minutes. The
    // longest window in use is 600s; an hour leaves ample margin.
    await db.collection('partner_rate_limit_events').createIndex(
      { created_at: 1 },
      { expireAfterSeconds: 3600 },
    );

    console.log('MongoDB database indexes initialized successfully!');
  } catch (error) {
    console.error('Error initializing MongoDB database indexes:', error);
  }
}
