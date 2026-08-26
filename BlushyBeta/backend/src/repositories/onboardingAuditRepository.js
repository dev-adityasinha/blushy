import { randomUUID } from 'node:crypto';

import { db } from '../utils/db.js';

async function getColl(userId, baseName) {
  const isMan = await db.collection('users_man').findOne({ user_id: userId });
  return isMan ? `${baseName}_man` : `${baseName}_woman`;
}

const ensureOnboardingAuditSchemaPromise = (async () => {
  try {
    await db.collection('ai_onboarding_update_audit_man').createIndex(
      { user_id: 1, created_at: -1 },
      { name: 'idx_ai_onboarding_audit_user_created' }
    );
    await db.collection('ai_onboarding_update_audit_woman').createIndex(
      { user_id: 1, created_at: -1 },
      { name: 'idx_ai_onboarding_audit_user_created' }
    );
  } catch (error) {
    console.error('Failed to create index for ai_onboarding_update_audit:', error);
  }
})();

await ensureOnboardingAuditSchemaPromise;

function mapRow(row) {
  if (!row) {
    return null;
  }

  return {
    auditId: row.audit_id,
    userId: row.user_id,
    source: row.source,
    changedKeys: Array.isArray(row.changed_keys) ? row.changed_keys : [],
    previousValues: row.previous_values ?? {},
    newValues: row.new_values ?? {},
    messageSnippet: row.message_snippet ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

async function appendAuditTrailEntry({
  userId,
  source = 'ai-chat',
  changedKeys = [],
  previousValues = {},
  newValues = {},
  messageSnippet = null,
}) {
  const doc = {
    audit_id: randomUUID(),
    user_id: userId,
    source,
    changed_keys: changedKeys,
    previous_values: previousValues,
    new_values: newValues,
    message_snippet: messageSnippet,
    created_at: new Date(),
  };

  await db.collection(await getColl(userId, 'ai_onboarding_update_audit')).insertOne(doc);

  return mapRow(doc);
}

async function listAuditTrailByUser({ userId, limit = 50 }) {
  const safeLimit = Number.isInteger(limit) && limit > 0 ? Math.min(limit, 200) : 50;

  const results = await db
    .collection(await getColl(userId, 'ai_onboarding_update_audit'))
    .find({ user_id: userId })
    .sort({ created_at: -1 })
    .limit(safeLimit)
    .toArray();

  return results.map(mapRow);
}

export const onboardingAuditRepository = {
  appendAuditTrailEntry,
  listAuditTrailByUser,
};