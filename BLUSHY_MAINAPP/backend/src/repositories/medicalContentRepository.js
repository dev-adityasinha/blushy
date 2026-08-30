import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';

/**
 * Central MedicalReference / MedicalContent service (spec §17 "Medical Content
 * System", §27 "Admin / Clinical Operations").
 *
 * Fields: ID, title, body, source, reviewer, review date, version, region /
 * locale, life stage, topic, status.
 * States: draft -> clinical_review -> approved -> retired.
 *
 * AI retrieves approved content only. Community content is a different
 * collection entirely and never mixes with this one.
 */

const COLLECTION = 'medical_content';
const AUDIT_COLLECTION = 'medical_content_audit';

export const CONTENT_STATES = Object.freeze({
  DRAFT: 'draft',
  CLINICAL_REVIEW: 'clinical_review',
  APPROVED: 'approved',
  RETIRED: 'retired',
});

export const CONTENT_STATE_VALUES = Object.freeze(Object.values(CONTENT_STATES));

/**
 * Allowed state moves. `retired` is terminal for serving purposes but can be
 * reopened to draft for a rewrite.
 */
const STATE_TRANSITIONS = Object.freeze({
  [CONTENT_STATES.DRAFT]: [CONTENT_STATES.CLINICAL_REVIEW, CONTENT_STATES.RETIRED],
  [CONTENT_STATES.CLINICAL_REVIEW]: [CONTENT_STATES.APPROVED, CONTENT_STATES.DRAFT, CONTENT_STATES.RETIRED],
  [CONTENT_STATES.APPROVED]: [CONTENT_STATES.RETIRED, CONTENT_STATES.CLINICAL_REVIEW],
  [CONTENT_STATES.RETIRED]: [CONTENT_STATES.DRAFT],
});

export function canTransitionContentState(from, to) {
  return Boolean(STATE_TRANSITIONS[from]?.includes(to));
}

function mapRow(row) {
  if (!row) return null;
  return {
    contentId: row.content_id,
    title: row.title,
    body: row.body,
    summary: row.summary ?? null,
    source: row.source ?? null,
    reviewer: row.reviewer ?? null,
    reviewDate: row.review_date ?? null,
    reviewDueDate: row.review_due_date ?? null,
    version: row.version ?? '1.0.0',
    locale: row.locale ?? 'en',
    region: row.region ?? null,
    lifeStages: row.life_stages ?? [],
    topics: row.topics ?? [],
    audience: row.audience ?? 'female_user',
    status: row.status,
    contentType: row.content_type ?? 'article',
    readingTimeMinutes: row.reading_time_minutes ?? null,
    mediaUrl: row.media_url ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

function normalizeArray(value) {
  if (!Array.isArray(value)) return [];
  return value.map((v) => String(v).trim().toLowerCase()).filter(Boolean);
}

export async function createContent(input, actorId) {
  const now = new Date();
  const doc = {
    content_id: input.contentId ?? `mc_${randomUUID().slice(0, 12)}`,
    title: String(input.title ?? '').slice(0, 300),
    body: String(input.body ?? '').slice(0, 100000),
    summary: input.summary ? String(input.summary).slice(0, 1000) : null,
    source: input.source ? String(input.source).slice(0, 500) : null,
    reviewer: input.reviewer ? String(input.reviewer).slice(0, 200) : null,
    review_date: input.reviewDate ?? null,
    review_due_date: input.reviewDueDate ?? null,
    version: input.version ?? '1.0.0',
    locale: input.locale ?? 'en',
    region: input.region ?? null,
    life_stages: normalizeArray(input.lifeStages),
    topics: normalizeArray(input.topics),
    audience: input.audience ?? 'female_user',
    status: CONTENT_STATES.DRAFT,
    content_type: input.contentType ?? 'article',
    reading_time_minutes: Number.isFinite(Number(input.readingTimeMinutes)) ? Number(input.readingTimeMinutes) : null,
    media_url: input.mediaUrl ?? null,
    created_at: now,
    updated_at: now,
  };

  await db.collection(COLLECTION).insertOne(doc);
  await recordAudit(doc.content_id, 'created', actorId, { status: CONTENT_STATES.DRAFT });
  return mapRow(doc);
}

export async function updateContent(contentId, patch, actorId) {
  const existing = await db.collection(COLLECTION).findOne({ content_id: contentId });
  if (!existing) return null;

  const set = { updated_at: new Date() };
  const fieldMap = {
    title: 'title',
    body: 'body',
    summary: 'summary',
    source: 'source',
    reviewer: 'reviewer',
    reviewDate: 'review_date',
    reviewDueDate: 'review_due_date',
    version: 'version',
    locale: 'locale',
    region: 'region',
    audience: 'audience',
    contentType: 'content_type',
    mediaUrl: 'media_url',
  };

  for (const [inputKey, column] of Object.entries(fieldMap)) {
    if (patch[inputKey] !== undefined) set[column] = patch[inputKey];
  }
  if (patch.lifeStages !== undefined) set.life_stages = normalizeArray(patch.lifeStages);
  if (patch.topics !== undefined) set.topics = normalizeArray(patch.topics);
  if (patch.readingTimeMinutes !== undefined) {
    set.reading_time_minutes = Number.isFinite(Number(patch.readingTimeMinutes)) ? Number(patch.readingTimeMinutes) : null;
  }

  // Editing approved content sends it back for review: approved words must
  // always match what a reviewer signed off.
  if (existing.status === CONTENT_STATES.APPROVED && (patch.body !== undefined || patch.title !== undefined)) {
    set.status = CONTENT_STATES.CLINICAL_REVIEW;
  }

  await db.collection(COLLECTION).updateOne({ content_id: contentId }, { $set: set });
  await recordAudit(contentId, 'updated', actorId, { fields: Object.keys(set) });

  const row = await db.collection(COLLECTION).findOne({ content_id: contentId });
  return mapRow(row);
}

export async function setContentStatus(contentId, status, actorId, { reviewer = null, reviewDate = null } = {}) {
  const existing = await db.collection(COLLECTION).findOne({ content_id: contentId });
  if (!existing) return { ok: false, notFound: true };

  if (!CONTENT_STATE_VALUES.includes(status)) {
    return { ok: false, error: `status must be one of: ${CONTENT_STATE_VALUES.join(', ')}.` };
  }
  if (!canTransitionContentState(existing.status, status)) {
    return { ok: false, error: `Cannot move content from ${existing.status} to ${status}.` };
  }
  if (status === CONTENT_STATES.APPROVED && !(reviewer ?? existing.reviewer)) {
    return { ok: false, error: 'Approval requires a reviewer.' };
  }

  const set = { status, updated_at: new Date() };
  if (status === CONTENT_STATES.APPROVED) {
    set.reviewer = reviewer ?? existing.reviewer;
    set.review_date = reviewDate ?? new Date().toISOString().slice(0, 10);
  }

  await db.collection(COLLECTION).updateOne({ content_id: contentId }, { $set: set });
  await recordAudit(contentId, `status_${status}`, actorId, { from: existing.status, to: status });

  const row = await db.collection(COLLECTION).findOne({ content_id: contentId });
  return { ok: true, content: mapRow(row) };
}

/**
 * Emergency retirement of unsafe content (spec §27). Skips the normal
 * transition rules by design and is always audited.
 */
export async function emergencyRetire(contentId, actorId, reason) {
  const existing = await db.collection(COLLECTION).findOne({ content_id: contentId });
  if (!existing) return { ok: false, notFound: true };

  await db.collection(COLLECTION).updateOne(
    { content_id: contentId },
    { $set: { status: CONTENT_STATES.RETIRED, updated_at: new Date() } },
  );
  await recordAudit(contentId, 'emergency_retired', actorId, { from: existing.status, reason: reason ?? null });

  const row = await db.collection(COLLECTION).findOne({ content_id: contentId });
  return { ok: true, content: mapRow(row) };
}

export async function getContent(contentId, { approvedOnly = true } = {}) {
  const query = { content_id: contentId };
  if (approvedOnly) query.status = CONTENT_STATES.APPROVED;
  const row = await db.collection(COLLECTION).findOne(query);
  return mapRow(row);
}

export async function getContentBatch(contentIds = [], { approvedOnly = true } = {}) {
  if (!Array.isArray(contentIds) || contentIds.length === 0) return [];
  const query = { content_id: { $in: contentIds } };
  if (approvedOnly) query.status = CONTENT_STATES.APPROVED;
  const rows = await db.collection(COLLECTION).find(query).toArray();
  return rows.map(mapRow);
}

/**
 * Retrieval for both the app and the AI gateway. `approvedOnly` defaults to
 * true so unreviewed drafts can never be served or reach a prompt.
 */
export async function listContent({
  lifeStage = null,
  topic = null,
  audience = null,
  locale = null,
  region = null,
  status = null,
  contentType = null,
  approvedOnly = true,
  search = null,
  limit = 30,
  skip = 0,
} = {}) {
  const query = {};
  if (approvedOnly) query.status = CONTENT_STATES.APPROVED;
  else if (status) query.status = status;

  if (lifeStage) query.life_stages = String(lifeStage).toLowerCase();
  if (topic) query.topics = String(topic).toLowerCase();
  if (audience) query.audience = audience;
  if (locale) query.locale = locale;
  if (contentType) query.content_type = contentType;
  if (region) query.$or = [{ region: null }, { region }];
  if (search) {
    const safe = String(search).replace(/[.*+?^${}()|[\]\\]/g, '\\$&').slice(0, 80);
    query.title = { $regex: safe, $options: 'i' };
  }

  const rows = await db.collection(COLLECTION)
    .find(query)
    .sort({ updated_at: -1 })
    .skip(Math.max(Number(skip) || 0, 0))
    .limit(Math.min(Math.max(Number(limit) || 30, 1), 100))
    .toArray();

  return rows.map(mapRow);
}

export async function countContent(filter = {}) {
  const query = {};
  if (filter.status) query.status = filter.status;
  if (filter.audience) query.audience = filter.audience;
  return db.collection(COLLECTION).countDocuments(query);
}

/**
 * Review queue: everything awaiting clinical review, plus approved items whose
 * review due date has passed (spec §17 "Review/expiration reminders").
 */
export async function getReviewQueue({ referenceDate = new Date() } = {}) {
  const today = referenceDate.toISOString().slice(0, 10);
  const awaiting = await db.collection(COLLECTION)
    .find({ status: CONTENT_STATES.CLINICAL_REVIEW })
    .sort({ updated_at: 1 })
    .toArray();

  const overdue = await db.collection(COLLECTION)
    .find({ status: CONTENT_STATES.APPROVED, review_due_date: { $ne: null, $lte: today } })
    .sort({ review_due_date: 1 })
    .toArray();

  return {
    awaitingReview: awaiting.map(mapRow),
    reviewOverdue: overdue.map(mapRow),
  };
}

async function recordAudit(contentId, action, actorId, details = null) {
  await db.collection(AUDIT_COLLECTION).insertOne({
    audit_id: randomUUID(),
    content_id: contentId,
    action,
    actor_id: actorId ?? 'system',
    details,
    created_at: new Date(),
  });
}

export async function getContentAudit(contentId, limit = 50) {
  const rows = await db.collection(AUDIT_COLLECTION)
    .find({ content_id: contentId })
    .sort({ created_at: -1 })
    .limit(Math.min(limit, 200))
    .toArray();

  return rows.map((row) => ({
    auditId: row.audit_id,
    contentId: row.content_id,
    action: row.action,
    actorId: row.actor_id,
    details: row.details ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  }));
}

/**
 * Idempotent seeding used by the content bootstrap so the app has real,
 * reviewed copy behind every contentId the domain layer references.
 */
export async function seedContentIfMissing(entries = [], actorId = 'system_seed') {
  let created = 0;
  for (const entry of entries) {
    const existing = await db.collection(COLLECTION).findOne({ content_id: entry.contentId });
    if (existing) continue;

    const now = new Date();
    await db.collection(COLLECTION).insertOne({
      content_id: entry.contentId,
      title: entry.title,
      body: entry.body,
      summary: entry.summary ?? null,
      source: entry.source ?? null,
      reviewer: entry.reviewer ?? null,
      review_date: entry.reviewDate ?? null,
      review_due_date: entry.reviewDueDate ?? null,
      version: entry.version ?? '1.0.0',
      locale: entry.locale ?? 'en',
      region: entry.region ?? null,
      life_stages: normalizeArray(entry.lifeStages),
      topics: normalizeArray(entry.topics),
      audience: entry.audience ?? 'female_user',
      status: entry.status ?? CONTENT_STATES.APPROVED,
      content_type: entry.contentType ?? 'article',
      reading_time_minutes: entry.readingTimeMinutes ?? null,
      media_url: entry.mediaUrl ?? null,
      created_at: now,
      updated_at: now,
    });
    await recordAudit(entry.contentId, 'seeded', actorId, null);
    created += 1;
  }
  return created;
}
