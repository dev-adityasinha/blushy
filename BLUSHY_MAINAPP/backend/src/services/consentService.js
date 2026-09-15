import {
  currentDocumentVersions,
  evaluateConsent,
  validateAcceptedDocuments,
} from '../domain/consent.js';
import {
  getLatestConsent,
  listConsentHistory,
  recordConsent,
  withdrawConsent,
} from '../repositories/consentRepository.js';
import { createHttpError } from '../utils/httpError.js';
import { logger } from '../utils/logger.js';

/**
 * Consent capture, re-consent, and withdrawal.
 *
 * The service deliberately reports the *current document versions* on every
 * response, including the failure ones. A client that is one release behind
 * needs to know which text it should be showing, and telling it only "your
 * consent is out of date" leaves it no way to fix that.
 */

function toIso(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function shapeStatus(record) {
  const evaluation = evaluateConsent(record);

  return {
    hasConsent: evaluation.hasConsent,
    needsConsent: evaluation.needsConsent,
    reason: evaluation.reason,
    outdatedDocuments: evaluation.outdatedDocuments,
    currentVersions: currentDocumentVersions(),
    acceptedVersions: record?.documents ?? null,
    grantedAt: toIso(record?.granted_at),
    withdrawnAt: toIso(record?.withdrawn_at),
  };
}

/** What the app needs to decide whether to show the consent screen. */
export async function getConsentStatus(userId) {
  const record = await getLatestConsent(userId);
  return shapeStatus(record);
}

/**
 * Records an acceptance of the documents currently in force.
 *
 * Rejects a partial or stale acceptance rather than storing it. A record
 * saying the user accepted version 1.0 when they were shown 0.9 is worse than
 * no record: it is evidence of something that did not happen.
 */
export async function acceptConsent(userId, { documents, method = 'onboarding', context = {} } = {}) {
  const { accepted, missing, mismatched, unknown } = validateAcceptedDocuments(documents);

  if (missing.length > 0) {
    throw createHttpError(400, `Consent is missing for: ${missing.join(', ')}.`);
  }

  if (mismatched.length > 0) {
    throw createHttpError(
      409,
      `These documents have changed since the version you were shown: ${mismatched.join(', ')}. `
      + 'Please review the current version and accept again.',
    );
  }

  if (unknown.length > 0) {
    // Not fatal -- a newer client may know about a document this server does
    // not. Worth a line in the log, because the reverse (a client that has
    // silently stopped sending one) shows up as `missing` and is fatal.
    logger.warn(`Consent: ignoring unrecognised documents: ${unknown.join(', ')}`);
  }

  const allowedMethods = new Set(['onboarding', 're_consent', 'settings']);
  const safeMethod = allowedMethods.has(method) ? method : 'onboarding';

  const record = await recordConsent({
    userId,
    documents: accepted,
    method: safeMethod,
    context,
  });

  logger.info(`Consent recorded for ${record.user_id} (${safeMethod}).`);

  return shapeStatus(record);
}

/**
 * Withdraws consent.
 *
 * Withdrawal is not deletion, and this does not delete anything. What it does
 * is make `needsConsent` true again, so the app stops treating the user as
 * having agreed and asks before processing anything further. A user who wants
 * their data gone as well is directed to account deletion, which is a separate
 * and irreversible action they have to take deliberately.
 */
export async function withdrawUserConsent(userId, reason = null) {
  const withdrawn = await withdrawConsent(userId, reason);

  if (!withdrawn) {
    throw createHttpError(409, 'There is no active consent to withdraw.');
  }

  logger.info(`Consent withdrawn for ${withdrawn.user_id}.`);

  return shapeStatus(withdrawn);
}

/** The user's own consent history, for the right of access. */
export async function getConsentHistory(userId) {
  const rows = await listConsentHistory(userId);

  return rows.map((row) => ({
    consentId: row.consent_id,
    documents: row.documents ?? {},
    method: row.method ?? null,
    platform: row.platform ?? null,
    appVersion: row.app_version ?? null,
    grantedAt: toIso(row.granted_at),
    withdrawnAt: toIso(row.withdrawn_at),
  }));
}
