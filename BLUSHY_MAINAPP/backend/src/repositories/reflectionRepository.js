import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';

/**
 * Monthly / cycle reflections (spec §12 "REFLECTIONS", §13 TTC).
 *
 * Reflection prompts are data driven, responses are persisted, and responses
 * are private by default - never shared with a partner without an explicit
 * permission grant.
 */

const COLLECTION = 'user_reflections';

export const REFLECTION_STATES = Object.freeze({
  POSITIVE: 'positive',
  NEUTRAL: 'neutral',
  DIFFICULT: 'difficult',
  PREGNANCY_CONFIRMED: 'pregnancy_confirmed',
  CYCLE_COMPLETED_NO_PREGNANCY: 'cycle_completed_without_pregnancy',
  INCOMPLETE: 'incomplete_or_unknown',
});

export const REFLECTION_STATE_VALUES = Object.freeze(Object.values(REFLECTION_STATES));

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

function mapRow(row) {
  if (!row) return null;
  return {
    reflectionId: row.reflection_id,
    userId: row.user_id,
    periodKey: row.period_key,
    lifeStage: row.life_stage ?? null,
    promptId: row.prompt_id ?? null,
    prompt: row.prompt ?? null,
    state: row.state ?? null,
    response: row.response ?? null,
    // Private by default (spec §12).
    sharedWithPartner: Boolean(row.shared_with_partner),
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

/**
 * `periodKey` is the month (`2026-08`) or cycle identifier the reflection
 * belongs to, which keeps one reflection per period and makes edits natural.
 */
export async function upsertReflection(userId, { periodKey, lifeStage, promptId, prompt, state, response, sharedWithPartner }) {
  const uid = cleanUserId(userId);
  const now = new Date();

  const set = { updated_at: now };
  if (lifeStage !== undefined) set.life_stage = lifeStage;
  if (promptId !== undefined) set.prompt_id = promptId;
  if (prompt !== undefined) set.prompt = prompt;
  if (state !== undefined) set.state = state;
  if (response !== undefined) set.response = typeof response === 'string' ? response.slice(0, 5000) : null;
  if (sharedWithPartner !== undefined) set.shared_with_partner = Boolean(sharedWithPartner);

  const setOnInsert = {
    reflection_id: randomUUID(),
    user_id: uid,
    period_key: periodKey,
    created_at: now,
  };

  // Mongo rejects a field that appears in both $set and $setOnInsert, so the
  // private-by-default value is only seeded when the caller did not supply one.
  if (set.shared_with_partner === undefined) {
    setOnInsert.shared_with_partner = false;
  }

  await db.collection(COLLECTION).updateOne(
    { user_id: uid, period_key: periodKey },
    { $set: set, $setOnInsert: setOnInsert },
    { upsert: true },
  );

  const row = await db.collection(COLLECTION).findOne({ user_id: uid, period_key: periodKey });
  return mapRow(row);
}

export async function getReflection(userId, periodKey) {
  const row = await db.collection(COLLECTION).findOne({ user_id: cleanUserId(userId), period_key: periodKey });
  return mapRow(row);
}

export async function listReflections(userId, { limit = 24 } = {}) {
  const rows = await db.collection(COLLECTION)
    .find({ user_id: cleanUserId(userId) })
    .sort({ period_key: -1 })
    .limit(Math.min(limit, 60))
    .toArray();
  return rows.map(mapRow);
}

export async function purgeUserReflections(userId) {
  const result = await db.collection(COLLECTION).deleteMany({ user_id: cleanUserId(userId) });
  return result.deletedCount ?? 0;
}
