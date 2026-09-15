import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';
import { COMPLETION_STATES } from '../domain/carePlan.js';

/**
 * Care plan action state (spec §10 "CARE PLAN / RECOMMENDED ACTIONS").
 *
 * The action catalogue is deterministic and lives in the domain layer; this
 * store only records what was surfaced to whom and what the user did with it,
 * which is what drives the cooldown logic.
 */

const COLLECTION = 'user_care_plan_actions';

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

function mapRow(row) {
  if (!row) return null;
  return {
    recordId: row.record_id,
    actionId: row.action_id,
    userId: row.user_id,
    title: row.title,
    category: row.category,
    priority: row.priority,
    source: row.source,
    contentId: row.content_id ?? null,
    reason: row.reason ?? null,
    completionState: row.completion_state,
    surfacedAt: row.surfaced_at ? new Date(row.surfaced_at).toISOString() : null,
    completedAt: row.completed_at ? new Date(row.completed_at).toISOString() : null,
    dismissedAt: row.dismissed_at ? new Date(row.dismissed_at).toISOString() : null,
    validUntil: row.valid_until ? new Date(row.valid_until).toISOString() : null,
    rulesetVersion: row.ruleset_version ?? null,
  };
}

/**
 * Records that an action was shown. Re-surfacing the same action refreshes the
 * timestamp rather than creating a second row, so history stays readable.
 */
export async function recordSurfaced(userId, action) {
  const uid = cleanUserId(userId);
  const now = new Date();

  const existing = await db.collection(COLLECTION).findOne({
    user_id: uid,
    action_id: action.id,
    completion_state: COMPLETION_STATES.NOT_STARTED,
  });

  if (existing) {
    await db.collection(COLLECTION).updateOne(
      { _id: existing._id },
      { $set: { surfaced_at: now, valid_until: action.validUntil ? new Date(action.validUntil) : null, reason: action.reason ?? null } },
    );
    return mapRow({ ...existing, surfaced_at: now });
  }

  const doc = {
    record_id: randomUUID(),
    user_id: uid,
    action_id: action.id,
    title: action.title,
    category: action.category,
    priority: action.priority,
    source: action.source,
    content_id: action.contentId ?? null,
    reason: action.reason ?? null,
    completion_state: COMPLETION_STATES.NOT_STARTED,
    surfaced_at: now,
    completed_at: null,
    dismissed_at: null,
    valid_until: action.validUntil ? new Date(action.validUntil) : null,
    ruleset_version: action.rulesetVersion ?? null,
  };

  await db.collection(COLLECTION).insertOne(doc);
  return mapRow(doc);
}

export async function setCompletionState(userId, actionId, completionState) {
  const uid = cleanUserId(userId);
  const now = new Date();
  const set = { completion_state: completionState };
  if (completionState === COMPLETION_STATES.COMPLETED) set.completed_at = now;
  if (completionState === COMPLETION_STATES.DISMISSED) set.dismissed_at = now;

  const result = await db.collection(COLLECTION).findOneAndUpdate(
    { user_id: uid, action_id: actionId, completion_state: COMPLETION_STATES.NOT_STARTED },
    { $set: set },
    { sort: { surfaced_at: -1 }, returnDocument: 'after' },
  );

  const doc = result?.value ?? result;
  if (!doc || !doc.record_id) {
    // Nothing pending: record the completion anyway so the cooldown applies.
    const fallback = {
      record_id: randomUUID(),
      user_id: uid,
      action_id: actionId,
      title: null,
      category: null,
      priority: null,
      source: null,
      content_id: null,
      reason: null,
      completion_state: completionState,
      surfaced_at: now,
      completed_at: completionState === COMPLETION_STATES.COMPLETED ? now : null,
      dismissed_at: completionState === COMPLETION_STATES.DISMISSED ? now : null,
      valid_until: null,
      ruleset_version: null,
    };
    await db.collection(COLLECTION).insertOne(fallback);
    return mapRow(fallback);
  }

  return mapRow(doc);
}

export async function getHistory(userId, { limit = 100 } = {}) {
  const rows = await db.collection(COLLECTION)
    .find({ user_id: cleanUserId(userId) })
    .sort({ surfaced_at: -1 })
    .limit(Math.min(limit, 300))
    .toArray();
  return rows.map(mapRow);
}

export async function getActiveActions(userId) {
  const rows = await db.collection(COLLECTION)
    .find({ user_id: cleanUserId(userId), completion_state: COMPLETION_STATES.NOT_STARTED })
    .sort({ surfaced_at: -1 })
    .toArray();
  return rows.map(mapRow);
}

export async function purgeUserCarePlan(userId) {
  const result = await db.collection(COLLECTION).deleteMany({ user_id: cleanUserId(userId) });
  return result.deletedCount ?? 0;
}
