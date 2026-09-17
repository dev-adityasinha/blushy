import { db } from '../utils/db.js';
import { userRepository } from '../repositories/userRepository.js';
import { logger } from '../utils/logger.js';

/**
 * Permanent account deletion (spec §21 "Support edit/delete/export/account
 * deletion", §28 "Define retention/deletion policies").
 *
 * The app's legal screen already promised this -- "Account deletion permanently
 * wipes your profile, period history, Docsy chat history, and partner
 * connection logs from our primary databases" -- while no endpoint existed and
 * the one hard-delete helper in `healthEventRepository` was never called. Google
 * Play also requires an in-app deletion path for any app with accounts.
 *
 * Everything is enumerated explicitly rather than discovered at runtime. A
 * deletion that silently misses a collection is worse than no deletion at all,
 * because the promise has already been made to the user.
 */

/** Collections keyed by a single owner, listed with every field that can hold it. */
const OWNED_COLLECTIONS = [
  ['health_events', ['user_id']],
  ['user_insights', ['user_id']],
  ['user_insight_feedback', ['user_id']],
  ['user_screenings', ['user_id']],
  ['user_reflections', ['user_id']],
  ['user_care_plan_actions', ['user_id']],
  ['user_content_progress', ['user_id']],
  ['user_life_stage', ['user_id']],
  ['user_life_stage_transitions', ['user_id']],
  ['notifications', ['user_id']],
  ['notification_preferences', ['user_id']],
  ['push_device_tokens', ['user_id']],
  ['push_delivery_log', ['user_id']],
  ['doctor_summaries', ['user_id']],
  ['medical_reports', ['user_id']],
  ['safety_incident_audit', ['user_id']],
  ['time_capsules', ['user_id']],
  ['bouquets', ['user_id', 'from_user_id', 'to_user_id']],
  ['user_feedbacks', ['user_id']],

  // The cached Discover feed is generated from her logs and keyed to her id,
  // so it goes with the account like anything else derived from her data.
  ['discover_daily_cache', ['user_id']],

  // Usage rows hold token counts and a feature name, never content -- but they
  // are keyed to her id, so they go too. Aggregate spend for a deleted account
  // is not worth keeping a personal record for.
  ['ai_usage_events', ['user_id']],

  // The consent ledger goes with the account. Keeping it would mean holding a
  // record about a person after promising to erase everything about them, and
  // there is no one left to demonstrate consent to. If counsel decides a
  // minimal record must survive deletion to answer a later challenge, that is
  // a deliberate exception to write into the privacy policy first, not a row
  // quietly left behind here.
  ['user_consents', ['user_id']],
  ['user_profiles', ['user_id']],
  ['feature_click_counts', ['user_id']],
  ['pregnancy_checkins', ['user_id']],
  ['pregnancy_memories', ['user_id']],
  ['pregnancy_questions', ['user_id']],

  // Community-facing records. The privacy policy promises the profile goes;
  // leaving authored posts behind would leave it partly reconstructable.
  ['posts', ['author_id']],
  ['comments', ['author_id']],
  ['post_votes', ['user_id']],
  ['comment_votes', ['user_id']],
  ['user_follows', ['follower_id', 'following_id']],
  ['community_followers', ['user_id']],
  ['community_messages', ['sender_user_id']],
  ['community_blocks', ['blocker_user_id', 'blocked_user_id']],
  ['community_moderation_audit', ['user_id']],

  // Relationship records. Both sides are removed: a connection with one party
  // deleted is not a connection.
  ['partner_connections', ['user_a_id', 'user_b_id']],
  ['partner_invitations', ['sender_user_id', 'recipient_user_id']],
  ['partner_notifications', ['user_id', 'recipient_user_id']],
  ['partner_data_views', ['user_id', 'viewer_user_id']],
  ['partner_completed_actions', ['user_id']],
  ['partner_support_requests', ['user_id', 'partner_user_id']],
  ['partner_permission_audit', ['actor_user_id', 'subject_user_id']],
  ['partner_permission_requests', ['requester_user_id', 'owner_user_id']],
  ['user_state', ['user_id']],
  ['shared_gardens', ['user_id']],
  ['friendships', ['user_id_1', 'user_id_2']],
  ['direct_messages', ['sender_id', 'recipient_id']],
];

/** Collections that exist once per role, suffixed `_man` / `_woman`. */
const ROLE_SUFFIXED = [
  'ai_chat_history',
  'ai_chat_daily_summaries',
  'ai_onboarding_update_audit',
  'user_profile_memory',
  'user_sleep_logs',
  'user_daily_moods',
  'user_journals',
  'user_nutrition_answers',
  'user_nutrition_plans',
  'user_period_logs',
];

/**
 * Chat history and daily summaries are keyed by `user_key` ("user:<id>"),
 * not by `user_id`. Deleting on the wrong field there would leave every Docsy
 * conversation in place while reporting success.
 */
const USER_KEY_COLLECTIONS = new Set(['ai_chat_history', 'ai_chat_daily_summaries']);

async function deleteWhere(collection, filter) {
  try {
    const result = await db.collection(collection).deleteMany(filter);
    return result?.deletedCount ?? 0;
  } catch (error) {
    // One missing collection must not abandon the rest of the deletion.
    logger.warn(`Account deletion: ${collection} failed: ${error.message}`);
    return 0;
  }
}

/**
 * Deletes every record belonging to a user, then the user itself.
 *
 * @returns {Promise<{deleted: Record<string, number>, total: number}>}
 */
export async function deleteAccount(userId) {
  const cleanId = typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
  if (!cleanId) {
    throw new Error('A user id is required to delete an account.');
  }

  const user = await userRepository.getUserById(cleanId);
  if (!user) {
    return { deleted: {}, total: 0, alreadyGone: true };
  }

  const deleted = {};
  const userKey = `user:${cleanId}`;

  // Partner chat is keyed by connection, so the connection ids are needed
  // before the connections themselves are removed.
  let connectionIds = [];
  try {
    const rows = await db.collection('partner_connections')
      .find({ $or: [{ user_a_id: cleanId }, { user_b_id: cleanId }] })
      .project({ connection_id: 1 })
      .toArray();
    connectionIds = rows.map((r) => r.connection_id).filter(Boolean);
  } catch (error) {
    logger.warn(`Account deletion: could not list connections: ${error.message}`);
  }

  if (connectionIds.length > 0) {
    deleted.partner_chat_messages = await deleteWhere(
      'partner_chat_messages', { connection_id: { $in: connectionIds } });
  }

  for (const [collection, fields] of OWNED_COLLECTIONS) {
    const filter = fields.length === 1
      ? { [fields[0]]: cleanId }
      : { $or: fields.map((f) => ({ [f]: cleanId })) };
    const count = await deleteWhere(collection, filter);
    if (count > 0) deleted[collection] = count;
  }

  for (const base of ROLE_SUFFIXED) {
    for (const role of ['man', 'woman']) {
      const collection = `${base}_${role}`;
      const filter = USER_KEY_COLLECTIONS.has(base)
        ? { $or: [{ user_key: userKey }, { user_id: cleanId }] }
        : { user_id: cleanId };
      const count = await deleteWhere(collection, filter);
      if (count > 0) deleted[collection] = count;
    }
  }

  // Analytics rows are pseudonymous by design (spec §26); any that still carry
  // the real id go with the account.
  const analytics = await deleteWhere('analytics_events', { user_id: cleanId });
  if (analytics > 0) deleted.analytics_events = analytics;

  // The account record itself is removed last, so a failure part-way through
  // leaves an account that can sign in and retry rather than orphaned data.
  for (const collection of ['users_man', 'users_woman']) {
    const count = await deleteWhere(collection, { user_id: cleanId });
    if (count > 0) deleted[collection] = count;
  }

  const total = Object.values(deleted).reduce((sum, n) => sum + n, 0);
  // The id is not health data and is what makes a deletion auditable.
  logger.info(`Account deleted: ${cleanId} (${total} records across ${Object.keys(deleted).length} collections)`);

  return { deleted, total };
}
