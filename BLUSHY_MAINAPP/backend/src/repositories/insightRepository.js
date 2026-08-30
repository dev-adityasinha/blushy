import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';
import { INSIGHT_STATUS, isInsightExpired } from '../domain/patterns.js';

/**
 * Structured insight store (spec §7, §8 "PATTERNS & INSIGHTS -- FUNCTIONAL, NOT
 * STATIC", §9 "SIA NOTE / AI CARDS").
 *
 * Each insight persists its source event IDs, time window, confidence, status,
 * generation time and model/engine version so it can be traced, expired and
 * invalidated when its evidence is deleted.
 */

const COLLECTION = 'user_insights';
const FEEDBACK_COLLECTION = 'user_insight_feedback';

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

function mapRow(row) {
  if (!row) return null;
  return {
    id: row.insight_id,
    userId: row.user_id,
    type: row.type,
    title: row.title,
    description: row.description,
    reason: row.reason ?? null,
    sourceEventIds: row.source_event_ids ?? [],
    periodStart: row.period_start ? new Date(row.period_start).toISOString() : null,
    periodEnd: row.period_end ? new Date(row.period_end).toISOString() : null,
    confidence: row.confidence ?? null,
    strength: row.strength ?? null,
    direction: row.direction ?? null,
    observationCount: row.observation_count ?? null,
    status: row.status,
    generatedAt: row.generated_at ? new Date(row.generated_at).toISOString() : null,
    modelVersion: row.model_version ?? null,
    engineVersion: row.engine_version ?? null,
    source: row.source ?? 'rule',
    actionId: row.action_id ?? null,
    causalClaim: false,
    audience: row.audience ?? 'self',
    requiredGrants: row.required_grants ?? [],
    metadata: row.metadata ?? null,
    invalidatedReason: row.invalidated_reason ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

/**
 * Idempotent upsert keyed on (user, type, dedupeKey). Refreshing an insight
 * updates the existing row rather than creating an endless stream of duplicates
 * (spec §9: "Refreshing should not create endless duplicate insights").
 */
export async function upsertInsight(userId, insight) {
  const uid = cleanUserId(userId);
  const now = new Date();
  const dedupeKey = insight.dedupeKey ?? `${insight.type}:${insight.metadata?.symptom ?? 'default'}`;

  const existing = await db.collection(COLLECTION).findOne({
    user_id: uid,
    dedupe_key: dedupeKey,
    status: { $in: [INSIGHT_STATUS.ACTIVE, INSIGHT_STATUS.DISMISSED] },
  });

  const doc = {
    type: insight.type,
    title: insight.title,
    description: insight.description,
    reason: insight.reason ?? null,
    source_event_ids: insight.sourceEventIds ?? [],
    period_start: insight.periodStart ? new Date(insight.periodStart) : null,
    period_end: insight.periodEnd ? new Date(insight.periodEnd) : null,
    confidence: insight.confidence ?? null,
    strength: insight.strength ?? null,
    direction: insight.direction ?? null,
    observation_count: insight.observationCount ?? null,
    generated_at: now,
    model_version: insight.modelVersion ?? null,
    engine_version: insight.engineVersion ?? null,
    source: insight.source ?? 'rule',
    action_id: insight.actionId ?? null,
    audience: insight.audience ?? 'self',
    required_grants: insight.requiredGrants ?? [],
    metadata: insight.metadata ?? null,
    updated_at: now,
  };

  if (existing) {
    // A dismissed insight stays dismissed until its evidence materially
    // changes; otherwise a refresh would resurrect what the user rejected.
    const evidenceChanged =
      JSON.stringify(existing.source_event_ids ?? []) !== JSON.stringify(doc.source_event_ids);

    if (existing.status === INSIGHT_STATUS.DISMISSED && !evidenceChanged) {
      return mapRow(existing);
    }

    await db.collection(COLLECTION).updateOne(
      { _id: existing._id },
      { $set: { ...doc, status: INSIGHT_STATUS.ACTIVE, invalidated_reason: null } },
    );
    const updated = await db.collection(COLLECTION).findOne({ _id: existing._id });
    return mapRow(updated);
  }

  const inserted = {
    insight_id: randomUUID(),
    user_id: uid,
    dedupe_key: dedupeKey,
    status: INSIGHT_STATUS.ACTIVE,
    invalidated_reason: null,
    created_at: now,
    ...doc,
  };

  await db.collection(COLLECTION).insertOne(inserted);
  return mapRow(inserted);
}

export async function listInsights(userId, { status = INSIGHT_STATUS.ACTIVE, audience = 'self', types = null, limit = 20 } = {}) {
  const query = { user_id: cleanUserId(userId), audience };
  if (status) query.status = status;
  if (Array.isArray(types) && types.length > 0) query.type = { $in: types };

  const rows = await db.collection(COLLECTION)
    .find(query)
    .sort({ confidence: -1, generated_at: -1 })
    .limit(Math.min(limit, 100))
    .toArray();

  return rows.map(mapRow);
}

export async function getInsight(userId, insightId) {
  const row = await db.collection(COLLECTION).findOne({ user_id: cleanUserId(userId), insight_id: insightId });
  return mapRow(row);
}

export async function setInsightStatus(userId, insightId, status, invalidatedReason = null) {
  const uid = cleanUserId(userId);
  const result = await db.collection(COLLECTION).updateOne(
    { user_id: uid, insight_id: insightId },
    { $set: { status, invalidated_reason: invalidatedReason, updated_at: new Date() } },
  );
  if (result.matchedCount === 0) return null;
  const row = await db.collection(COLLECTION).findOne({ user_id: uid, insight_id: insightId });
  return mapRow(row);
}

/**
 * Invalidates every insight whose evidence includes one of the deleted events
 * (spec §7: "Deleted source logs must invalidate or recalculate dependent
 * insights").
 */
export async function invalidateInsightsForEvents(userId, deletedEventIds = []) {
  if (!Array.isArray(deletedEventIds) || deletedEventIds.length === 0) return 0;

  const result = await db.collection(COLLECTION).updateMany(
    {
      user_id: cleanUserId(userId),
      status: { $in: [INSIGHT_STATUS.ACTIVE, INSIGHT_STATUS.DISMISSED] },
      source_event_ids: { $in: deletedEventIds },
    },
    {
      $set: {
        status: INSIGHT_STATUS.INVALIDATED,
        invalidated_reason: 'source_event_deleted',
        updated_at: new Date(),
      },
    },
  );

  return result.modifiedCount ?? 0;
}

/**
 * Marks insights past their TTL as expired so stale cards stop being served
 * (spec §7: "Allow ... insight expiry/recalculation").
 */
export async function expireStaleInsights(userId, referenceDate = new Date()) {
  const uid = cleanUserId(userId);
  const rows = await db.collection(COLLECTION)
    .find({ user_id: uid, status: INSIGHT_STATUS.ACTIVE })
    .toArray();

  const expiredIds = rows
    .map(mapRow)
    .filter((insight) => isInsightExpired(insight, referenceDate))
    .map((insight) => insight.id);

  if (expiredIds.length === 0) return 0;

  const result = await db.collection(COLLECTION).updateMany(
    { user_id: uid, insight_id: { $in: expiredIds } },
    { $set: { status: INSIGHT_STATUS.EXPIRED, updated_at: new Date() } },
  );

  return result.modifiedCount ?? 0;
}

/**
 * Helpful / not helpful feedback (spec §9, §29 step 27-28). Feedback is stored
 * so future ranking can use it; it never rewrites the insight itself.
 */
export async function recordFeedback(userId, insightId, { helpful, note = null }) {
  const uid = cleanUserId(userId);
  const doc = {
    feedback_id: randomUUID(),
    user_id: uid,
    insight_id: insightId,
    helpful: Boolean(helpful),
    note: typeof note === 'string' ? note.slice(0, 300) : null,
    created_at: new Date(),
  };
  await db.collection(FEEDBACK_COLLECTION).insertOne(doc);

  if (!helpful) {
    await setInsightStatus(uid, insightId, INSIGHT_STATUS.DISMISSED, 'user_not_useful');
  }

  return {
    feedbackId: doc.feedback_id,
    insightId,
    helpful: doc.helpful,
    createdAt: doc.created_at.toISOString(),
  };
}

export async function getFeedbackSummary(userId) {
  const rows = await db.collection(FEEDBACK_COLLECTION)
    .find({ user_id: cleanUserId(userId) })
    .toArray();

  const byType = {};
  for (const row of rows) {
    const key = row.insight_id;
    byType[key] = byType[key] ?? { helpful: 0, notHelpful: 0 };
    if (row.helpful) byType[key].helpful += 1;
    else byType[key].notHelpful += 1;
  }
  return byType;
}

export async function purgeUserInsights(userId) {
  const uid = cleanUserId(userId);
  const a = await db.collection(COLLECTION).deleteMany({ user_id: uid });
  const b = await db.collection(FEEDBACK_COLLECTION).deleteMany({ user_id: uid });
  return (a.deletedCount ?? 0) + (b.deletedCount ?? 0);
}
