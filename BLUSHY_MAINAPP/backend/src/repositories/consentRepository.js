import { randomUUID } from 'node:crypto';

import { db } from '../utils/db.js';

/**
 * The consent ledger.
 *
 * Append-only. Each acceptance and each withdrawal is a new row, and rows are
 * never edited except to stamp `withdrawn_at` on the row being withdrawn. The
 * point of the record is to be able to say what a user agreed to on a given
 * day; a table that is updated in place cannot answer that, because the answer
 * has already been overwritten by the next answer.
 *
 * Current consent is therefore "the most recent row that has not been
 * withdrawn", not "the row".
 */

const COLLECTION = 'user_consents';

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

/** The row that represents this user's consent right now, or null. */
export async function getLatestConsent(userId) {
  const cleanId = cleanUserId(userId);
  if (!cleanId) return null;

  const rows = await db.collection(COLLECTION)
    .find({ user_id: cleanId })
    .sort({ granted_at: -1 })
    .limit(1)
    .toArray();

  return rows[0] ?? null;
}

/**
 * Records an acceptance.
 *
 * `context` carries the circumstances that make the record evidence rather
 * than an assertion: where the request came from and what was running. None of
 * it is health data.
 */
export async function recordConsent({ userId, documents, method, context = {} }) {
  const cleanId = cleanUserId(userId);
  if (!cleanId) {
    throw new Error('A user id is required to record consent.');
  }

  const doc = {
    consent_id: randomUUID(),
    user_id: cleanId,
    documents,
    method,
    ip: context.ip ?? null,
    user_agent: context.userAgent ?? null,
    app_version: context.appVersion ?? null,
    platform: context.platform ?? null,
    granted_at: new Date(),
    withdrawn_at: null,
    withdrawal_reason: null,
  };

  await db.collection(COLLECTION).insertOne(doc);
  return doc;
}

/**
 * Marks the user's current consent withdrawn.
 *
 * Stamps the row that was in force rather than inserting a separate withdrawal
 * row, so that "the latest row" remains a complete answer on its own -- a
 * reader does not have to join two rows to discover that consent no longer
 * stands.
 *
 * @returns the withdrawn row, or null if there was nothing in force.
 */
export async function withdrawConsent(userId, reason = null) {
  const cleanId = cleanUserId(userId);
  if (!cleanId) return null;

  const current = await getLatestConsent(cleanId);
  if (!current || current.withdrawn_at) {
    return null;
  }

  const withdrawnAt = new Date();
  await db.collection(COLLECTION).updateOne(
    { consent_id: current.consent_id },
    { $set: { withdrawn_at: withdrawnAt, withdrawal_reason: reason } },
  );

  return { ...current, withdrawn_at: withdrawnAt, withdrawal_reason: reason };
}

/**
 * The user's full consent history, newest first.
 *
 * Exists so that a user exercising their right of access can be shown what
 * they agreed to and when, rather than being told only the current state.
 */
export async function listConsentHistory(userId, { limit = 50 } = {}) {
  const cleanId = cleanUserId(userId);
  if (!cleanId) return [];

  return db.collection(COLLECTION)
    .find({ user_id: cleanId })
    .sort({ granted_at: -1 })
    .limit(Math.min(limit, 200))
    .toArray();
}
