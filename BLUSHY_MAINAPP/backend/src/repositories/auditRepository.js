import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';

/**
 * Permission, safety and analytics audit trails
 * (spec §10 "Permission changes are auditable", §26 "Analytics",
 * §27 "Audit logs for safety and clinical changes", §28 "Do not log raw health
 * content").
 *
 * Nothing here stores raw health content, journal text or Sia conversation
 * bodies - only the fact that something happened, to what entity, and when.
 */

const PERMISSION_AUDIT = 'partner_permission_audit';
const SAFETY_AUDIT = 'safety_incident_audit';
const ANALYTICS = 'analytics_events';

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

/* ------------------------------------------------------------------ *
 * Partner permission audit
 * ------------------------------------------------------------------ */

export async function recordPermissionChange({ connectionId, actorUserId, subjectUserId, changes, previous, next }) {
  const doc = {
    audit_id: randomUUID(),
    connection_id: connectionId,
    actor_user_id: cleanUserId(actorUserId),
    subject_user_id: cleanUserId(subjectUserId),
    changes,
    previous,
    next,
    created_at: new Date(),
  };
  await db.collection(PERMISSION_AUDIT).insertOne(doc);
  return {
    auditId: doc.audit_id,
    connectionId,
    changes,
    createdAt: doc.created_at.toISOString(),
  };
}

export async function listPermissionAudit(connectionId, { limit = 50 } = {}) {
  const rows = await db.collection(PERMISSION_AUDIT)
    .find({ connection_id: connectionId })
    .sort({ created_at: -1 })
    .limit(Math.min(limit, 200))
    .toArray();

  return rows.map((row) => ({
    auditId: row.audit_id,
    connectionId: row.connection_id,
    actorUserId: row.actor_user_id,
    changes: row.changes,
    previous: row.previous,
    next: row.next,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  }));
}

/* ------------------------------------------------------------------ *
 * Safety incident audit
 * ------------------------------------------------------------------ */

/**
 * Records that a red flag fired. Stores rule IDs and versions, never the
 * user's words.
 */
export async function recordSafetyIncident(userId, { ruleIds, level, rulesetVersion, surface, suppressedWellness, modelVersion = null }) {
  const doc = {
    incident_id: randomUUID(),
    user_id: cleanUserId(userId),
    rule_ids: ruleIds,
    level,
    ruleset_version: rulesetVersion,
    surface,
    suppressed_wellness: Boolean(suppressedWellness),
    model_version: modelVersion,
    reviewed: false,
    created_at: new Date(),
  };
  await db.collection(SAFETY_AUDIT).insertOne(doc);
  return { incidentId: doc.incident_id, createdAt: doc.created_at.toISOString() };
}

export async function listSafetyIncidents({ userId = null, reviewed = null, limit = 100 } = {}) {
  const query = {};
  if (userId) query.user_id = cleanUserId(userId);
  if (reviewed !== null) query.reviewed = reviewed;

  const rows = await db.collection(SAFETY_AUDIT)
    .find(query)
    .sort({ created_at: -1 })
    .limit(Math.min(limit, 300))
    .toArray();

  return rows.map((row) => ({
    incidentId: row.incident_id,
    userId: row.user_id,
    ruleIds: row.rule_ids,
    level: row.level,
    rulesetVersion: row.ruleset_version,
    surface: row.surface,
    suppressedWellness: Boolean(row.suppressed_wellness),
    modelVersion: row.model_version ?? null,
    reviewed: Boolean(row.reviewed),
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  }));
}

export async function markIncidentReviewed(incidentId, reviewerId, notes = null) {
  const result = await db.collection(SAFETY_AUDIT).updateOne(
    { incident_id: incidentId },
    { $set: { reviewed: true, reviewer_id: reviewerId, review_notes: notes ? String(notes).slice(0, 1000) : null, reviewed_at: new Date() } },
  );
  return result.modifiedCount > 0;
}

/* ------------------------------------------------------------------ *
 * Analytics (spec §26)
 * ------------------------------------------------------------------ */

/**
 * The only analytics events Blushy records. Anything not on this list is
 * rejected, which is what stops health content leaking into analytics.
 */
export const ANALYTICS_EVENTS = Object.freeze([
  'onboarding_completed',
  'branch_selected',
  'period_logged',
  'insight_viewed',
  'insight_dismissed',
  'sia_started',
  'partner_connected',
  'permission_changed',
  'support_request_sent',
  'support_request_completed',
  'article_completed',
  'screening_completed',
  'safety_escalation',
  'life_stage_transitioned',
  'care_action_completed',
  'reflection_completed',
]);

/**
 * Property keys allowed on an analytics event. Free-form properties are
 * dropped so raw journal text or Sia conversations can never be sent
 * (spec §26).
 */
const ALLOWED_PROPERTY_KEYS = new Set([
  'lifeStage', 'branch', 'insightType', 'category', 'contentId', 'instrumentId',
  'permissionKey', 'enabled', 'requestType', 'surface', 'source', 'level',
  'durationMs', 'platform', 'appVersion', 'fromStage', 'toStage', 'actionId',
]);

export function sanitizeAnalyticsProperties(properties) {
  const clean = {};
  if (!properties || typeof properties !== 'object') return clean;
  for (const [key, value] of Object.entries(properties)) {
    if (!ALLOWED_PROPERTY_KEYS.has(key)) continue;
    if (value === null || value === undefined) continue;
    if (typeof value === 'string') clean[key] = value.slice(0, 120);
    else if (typeof value === 'number' || typeof value === 'boolean') clean[key] = value;
  }
  return clean;
}

/**
 * `pseudonymousId` is what analytics is keyed on; the real user id is stored
 * separately only so a deletion request can find and remove the rows.
 */
export async function recordAnalyticsEvent({ userId, pseudonymousId, eventName, properties = {} }) {
  if (!ANALYTICS_EVENTS.includes(eventName)) {
    return { ok: false, error: `Unknown analytics event: ${eventName}.` };
  }

  const doc = {
    analytics_id: randomUUID(),
    pseudonymous_id: pseudonymousId,
    user_id: userId ? cleanUserId(userId) : null,
    event_name: eventName,
    properties: sanitizeAnalyticsProperties(properties),
    created_at: new Date(),
  };

  await db.collection(ANALYTICS).insertOne(doc);
  return { ok: true, analyticsId: doc.analytics_id };
}

export async function getFunnelCounts({ from = null, to = null } = {}) {
  const match = {};
  if (from || to) {
    match.created_at = {};
    if (from) match.created_at.$gte = new Date(from);
    if (to) match.created_at.$lte = new Date(to);
  }

  const rows = await db.collection(ANALYTICS).aggregate([
    ...(Object.keys(match).length > 0 ? [{ $match: match }] : []),
    { $group: { _id: '$event_name', count: { $sum: 1 } } },
    { $sort: { count: -1 } },
  ]).toArray();

  const counts = {};
  for (const row of rows) counts[row._id] = row.count;
  return counts;
}

export async function purgeUserAudit(userId) {
  const uid = cleanUserId(userId);
  const a = await db.collection(ANALYTICS).deleteMany({ user_id: uid });
  const b = await db.collection(SAFETY_AUDIT).deleteMany({ user_id: uid });
  return (a.deletedCount ?? 0) + (b.deletedCount ?? 0);
}
