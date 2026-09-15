/**
 * Consent documents, their versions, and when consent must be asked for again.
 *
 * The onboarding wizard has always shown a "Trust & Privacy" step with tick
 * boxes for the privacy policy and the terms, and refused to continue until
 * both were ticked. Nothing was ever recorded. The tick lived in a `setState`
 * field and died with the widget, so the only evidence that any user had ever
 * consented was that they had got past the screen.
 *
 * Under the DPDP Act, 2023 a Data Fiduciary processing personal data on the
 * basis of consent must be able to *demonstrate* that valid consent was
 * obtained -- who consented, to what, and when. A screen that is shown but not
 * recorded cannot demonstrate anything. For health data, which is most of what
 * this app holds, that is the difference between a lawful basis and none.
 *
 * Dependency-free like the rest of `domain/`: the clock is passed in, so the
 * re-consent rules can be unit-tested without a database or a fixed date.
 */

/**
 * The version of each document currently in force.
 *
 * **Bump a version here whenever the corresponding document changes
 * materially.** Every user whose recorded consent names an older version is
 * then asked again, which is what §26 of the privacy policy promises ("material
 * changes ... we will seek renewed consent"). Nothing else needs to change.
 *
 * Versions are opaque strings compared for equality, not ordered. A version
 * that merely differs from the recorded one triggers re-consent, so correcting
 * a typo by bumping to '1.0.1' costs every user a prompt -- bump only for
 * changes a user would want to know about.
 */
export const CONSENT_DOCUMENTS = Object.freeze({
  privacy_policy: '1.0',
  terms: '1.0',
  medical_disclaimer: '1.0',
});

/** Every document a user must accept before health data may be processed. */
export const CONSENT_DOCUMENT_KEYS = Object.freeze(Object.keys(CONSENT_DOCUMENTS));

/**
 * Why the app should ask for consent, when it should.
 *
 * `null` means it should not ask.
 */
export const CONSENT_REASONS = Object.freeze({
  neverGiven: 'never_given',
  withdrawn: 'withdrawn',
  documentsUpdated: 'documents_updated',
});

/** A fresh copy of the current versions, safe for a caller to serialise. */
export function currentDocumentVersions() {
  return { ...CONSENT_DOCUMENTS };
}

/**
 * Checks what a client claims to have accepted against what is in force.
 *
 * Deliberately strict about versions. A client that accepts "the privacy
 * policy" without saying which one has not produced usable evidence, and a
 * client one release behind must not have its acceptance recorded against the
 * current text -- that would manufacture consent to a document the user never
 * saw.
 *
 * @param {unknown} input `{ privacy_policy: '1.0', ... }` from the request body.
 * @returns {{accepted: Record<string,string>, missing: string[], mismatched: string[], unknown: string[]}}
 */
export function validateAcceptedDocuments(input) {
  const provided = (input && typeof input === 'object' && !Array.isArray(input)) ? input : {};

  const accepted = {};
  const missing = [];
  const mismatched = [];

  for (const key of CONSENT_DOCUMENT_KEYS) {
    const raw = provided[key];
    const version = typeof raw === 'string' ? raw.trim() : '';

    if (!version) {
      missing.push(key);
      continue;
    }

    if (version !== CONSENT_DOCUMENTS[key]) {
      mismatched.push(key);
      continue;
    }

    accepted[key] = version;
  }

  const unknown = Object.keys(provided).filter((key) => !CONSENT_DOCUMENT_KEYS.includes(key));

  return { accepted, missing, mismatched, unknown };
}

/**
 * Whether the stored consent record still covers what the app is doing.
 *
 * A user with no record at all is not an error case: every account that
 * existed before consent was recorded is in exactly that position, and each of
 * them genuinely does need to be asked. The caller decides what to do about
 * it; this only reports the fact.
 *
 * @param {object|null} record The latest consent row, or null if there is none.
 * @returns {{hasConsent: boolean, needsConsent: boolean, reason: string|null, outdatedDocuments: string[]}}
 */
export function evaluateConsent(record) {
  if (!record) {
    return {
      hasConsent: false,
      needsConsent: true,
      reason: CONSENT_REASONS.neverGiven,
      outdatedDocuments: [...CONSENT_DOCUMENT_KEYS],
    };
  }

  if (record.withdrawn_at) {
    return {
      hasConsent: false,
      needsConsent: true,
      reason: CONSENT_REASONS.withdrawn,
      outdatedDocuments: [...CONSENT_DOCUMENT_KEYS],
    };
  }

  const documents = (record.documents && typeof record.documents === 'object') ? record.documents : {};
  const outdatedDocuments = CONSENT_DOCUMENT_KEYS
    .filter((key) => documents[key] !== CONSENT_DOCUMENTS[key]);

  if (outdatedDocuments.length > 0) {
    return {
      hasConsent: false,
      needsConsent: true,
      reason: CONSENT_REASONS.documentsUpdated,
      outdatedDocuments,
    };
  }

  return {
    hasConsent: true,
    needsConsent: false,
    reason: null,
    outdatedDocuments: [],
  };
}
