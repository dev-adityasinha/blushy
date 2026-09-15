import { randomUUID } from 'node:crypto';
import { db, findUserDocument } from '../utils/db.js';
import { normalizeLifeStage, LIFE_STAGES } from '../domain/lifeStages.js';

/**
 * Life stage state and branch context (spec §4, §23).
 *
 * The active stage plus branch context live in one document per user, and every
 * change is appended to a transition history so historical data is preserved
 * and the change is auditable.
 */

const STATE_COLLECTION = 'user_life_stage';
const HISTORY_COLLECTION = 'user_life_stage_transitions';

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

function mapState(row) {
  if (!row) return null;
  return {
    userId: row.user_id,
    lifeStage: row.life_stage,
    branchContext: row.branch_context ?? {},
    // Set when a pregnancy has ended, so pregnancy week content can never
    // resume for this user (spec §15).
    pregnancyContentBlocked: Boolean(row.pregnancy_content_blocked),
    ttcOptedIn: Boolean(row.ttc_opted_in),
    region: row.region ?? null,
    locale: row.locale ?? null,
    timezone: row.timezone ?? null,
    enteredStageAt: row.entered_stage_at ? new Date(row.entered_stage_at).toISOString() : null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

/**
 * Reads the life stage state, falling back to the legacy onboarding answers on
 * the user document so existing accounts keep working before they have written
 * a life stage row.
 */
export async function getLifeStageState(userId) {
  const uid = cleanUserId(userId);
  const row = await db.collection(STATE_COLLECTION).findOne({ user_id: uid });
  if (row) return mapState(row);

  const user = await findUserDocument({ user_id: uid });
  const answers = user?.onboarding_answers ?? {};
  const legacyStage = normalizeLifeStage(
    user?.life_stage ?? answers.life_stage ?? answers.lifeStage ?? answers.selected_stage,
    null,
  );

  return {
    userId: uid,
    lifeStage: legacyStage,
    branchContext: {},
    pregnancyContentBlocked: false,
    ttcOptedIn: legacyStage === LIFE_STAGES.TTC,
    region: user?.region ?? null,
    locale: user?.locale ?? null,
    timezone: user?.timezone ?? answers.timezone ?? null,
    enteredStageAt: null,
    createdAt: null,
    updatedAt: null,
    derivedFromLegacyProfile: true,
  };
}

export async function upsertLifeStageState(userId, patch = {}) {
  const uid = cleanUserId(userId);
  const now = new Date();

  const set = { updated_at: now };
  if (patch.lifeStage !== undefined) {
    set.life_stage = normalizeLifeStage(patch.lifeStage, null);
    set.entered_stage_at = now;
  }
  if (patch.branchContext !== undefined) set.branch_context = patch.branchContext;
  if (patch.pregnancyContentBlocked !== undefined) set.pregnancy_content_blocked = Boolean(patch.pregnancyContentBlocked);
  if (patch.ttcOptedIn !== undefined) set.ttc_opted_in = Boolean(patch.ttcOptedIn);
  if (patch.region !== undefined) set.region = patch.region;
  if (patch.locale !== undefined) set.locale = patch.locale;
  if (patch.timezone !== undefined) set.timezone = patch.timezone;

  await db.collection(STATE_COLLECTION).updateOne(
    { user_id: uid },
    { $set: set, $setOnInsert: { user_id: uid, created_at: now } },
    { upsert: true },
  );

  const row = await db.collection(STATE_COLLECTION).findOne({ user_id: uid });
  return mapState(row);
}

/**
 * Merges keys into branch context without dropping unrelated keys.
 */
export async function mergeBranchContext(userId, contextPatch = {}) {
  const uid = cleanUserId(userId);
  const now = new Date();
  const set = { updated_at: now };

  for (const [key, value] of Object.entries(contextPatch)) {
    if (value === undefined) continue;
    set[`branch_context.${key}`] = value;
  }

  await db.collection(STATE_COLLECTION).updateOne(
    { user_id: uid },
    { $set: set, $setOnInsert: { user_id: uid, created_at: now } },
    { upsert: true },
  );

  const row = await db.collection(STATE_COLLECTION).findOne({ user_id: uid });
  return mapState(row);
}

/**
 * Mirrors the active stage onto the legacy user document so services that still
 * read `user.life_stage` (notably the period prediction suppression rules) agree
 * with the life stage engine. Deliberately narrow: it must not touch
 * onboarding_completed_at or any onboarding answer.
 */
export async function syncLegacyProfileStage(userId, lifeStage) {
  const uid = cleanUserId(userId);
  const stage = normalizeLifeStage(lifeStage, null);
  if (!stage) return false;

  for (const collection of ['users_woman', 'users_man']) {
    const result = await db.collection(collection).updateOne(
      { user_id: uid },
      // A pipeline update, not a dotted $set. A dotted path can create a field
      // that is merely absent, but not one whose parent is explicitly null --
      // which is what a user who has never saved an answer has, and it failed
      // the whole transition with "Cannot create field 'life_stage' in element
      // {onboarding_answers: null}". Rebuilding the object covers null, absent
      // and wrongly-typed alike, while preserving every existing answer.
      [
        {
          $set: {
            life_stage: stage,
            updated_at: new Date(),
            onboarding_answers: {
              $mergeObjects: [
                {
                  $cond: [
                    { $eq: [{ $type: '$onboarding_answers' }, 'object'] },
                    '$onboarding_answers',
                    {},
                  ],
                },
                { life_stage: stage },
              ],
            },
          },
        },
      ],
    );
    if (result.matchedCount > 0) return true;
  }
  return false;
}

export async function recordTransition(userId, { fromStage, toStage, reason, confirmed, triggeredBy = 'user', metadata = null }) {
  const uid = cleanUserId(userId);
  const doc = {
    transition_id: randomUUID(),
    user_id: uid,
    from_stage: fromStage ?? null,
    to_stage: toStage,
    reason: reason ?? null,
    confirmed: Boolean(confirmed),
    triggered_by: triggeredBy,
    metadata: metadata ?? null,
    created_at: new Date(),
  };
  await db.collection(HISTORY_COLLECTION).insertOne(doc);
  return {
    transitionId: doc.transition_id,
    fromStage: doc.from_stage,
    toStage: doc.to_stage,
    reason: doc.reason,
    confirmed: doc.confirmed,
    triggeredBy: doc.triggered_by,
    createdAt: doc.created_at.toISOString(),
  };
}

export async function listTransitions(userId, limit = 50) {
  const rows = await db.collection(HISTORY_COLLECTION)
    .find({ user_id: cleanUserId(userId) })
    .sort({ created_at: -1 })
    .limit(Math.min(limit, 200))
    .toArray();

  return rows.map((row) => ({
    transitionId: row.transition_id,
    fromStage: row.from_stage,
    toStage: row.to_stage,
    reason: row.reason,
    confirmed: row.confirmed,
    triggeredBy: row.triggered_by,
    metadata: row.metadata ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  }));
}
