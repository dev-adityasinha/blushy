import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';

/**
 * Screening results (spec §16 "POSTPARTUM FUNCTIONAL REQUIREMENTS": "store
 * instrument/version/checkpoint/score").
 *
 * Raw item responses are stored so a clinician handoff can be accurate, but
 * they are never exposed to partners, AI context or analytics.
 */

const COLLECTION = 'user_screenings';

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

function mapRow(row, { includeResponses = false } = {}) {
  if (!row) return null;
  const mapped = {
    screeningId: row.screening_id,
    userId: row.user_id,
    instrumentId: row.instrument_id,
    instrumentName: row.instrument_name,
    instrumentVersion: row.instrument_version,
    engineVersion: row.engine_version,
    checkpointDay: row.checkpoint_day ?? null,
    totalScore: row.total_score,
    maxScore: row.max_score,
    outcome: row.outcome,
    crisisItemPositive: Boolean(row.crisis_item_positive),
    requiresProfessionalSupport: Boolean(row.requires_professional_support),
    isDiagnosis: false,
    source: row.source ?? 'medical_reference',
    completedAt: row.completed_at ? new Date(row.completed_at).toISOString() : null,
    handoffSharedWith: row.handoff_shared_with ?? null,
    handoffSharedAt: row.handoff_shared_at ? new Date(row.handoff_shared_at).toISOString() : null,
  };
  if (includeResponses) {
    mapped.itemScores = row.item_scores ?? [];
    mapped.rawResponses = row.raw_responses ?? [];
  }
  return mapped;
}

export async function saveScreening(userId, result, { checkpointDay = null, rawResponses = [] } = {}) {
  const uid = cleanUserId(userId);
  const doc = {
    screening_id: randomUUID(),
    user_id: uid,
    instrument_id: result.instrumentId,
    instrument_name: result.instrumentName,
    instrument_version: result.instrumentVersion,
    engine_version: result.engineVersion,
    checkpoint_day: checkpointDay,
    item_scores: result.itemScores,
    raw_responses: rawResponses,
    total_score: result.totalScore,
    max_score: result.maxScore,
    outcome: result.outcome,
    crisis_item_positive: result.crisisItemPositive,
    requires_professional_support: result.requiresProfessionalSupport,
    source: 'medical_reference',
    completed_at: new Date(),
    handoff_shared_with: null,
    handoff_shared_at: null,
  };

  await db.collection(COLLECTION).insertOne(doc);
  return mapRow(doc);
}

export async function listScreenings(userId, { instrumentId = null, limit = 20 } = {}) {
  const query = { user_id: cleanUserId(userId) };
  if (instrumentId) query.instrument_id = instrumentId;

  const rows = await db.collection(COLLECTION)
    .find(query)
    .sort({ completed_at: -1 })
    .limit(Math.min(limit, 60))
    .toArray();

  return rows.map((row) => mapRow(row));
}

export async function getLatestScreening(userId, instrumentId) {
  const row = await db.collection(COLLECTION)
    .find({ user_id: cleanUserId(userId), instrument_id: instrumentId })
    .sort({ completed_at: -1 })
    .limit(1)
    .next();
  return mapRow(row);
}

export async function getCompletedCheckpointDays(userId, instrumentId) {
  const rows = await db.collection(COLLECTION)
    .find({ user_id: cleanUserId(userId), instrument_id: instrumentId, checkpoint_day: { $ne: null } })
    .toArray();
  return rows.map((row) => row.checkpoint_day);
}

/**
 * Records a handoff to a trusted person or provider (spec §16).
 */
export async function recordHandoff(userId, screeningId, sharedWith) {
  const uid = cleanUserId(userId);
  const result = await db.collection(COLLECTION).updateOne(
    { user_id: uid, screening_id: screeningId },
    { $set: { handoff_shared_with: String(sharedWith).slice(0, 200), handoff_shared_at: new Date() } },
  );
  if (result.matchedCount === 0) return null;
  const row = await db.collection(COLLECTION).findOne({ user_id: uid, screening_id: screeningId });
  return mapRow(row);
}

export async function purgeUserScreenings(userId) {
  const result = await db.collection(COLLECTION).deleteMany({ user_id: cleanUserId(userId) });
  return result.deletedCount ?? 0;
}
