import test from 'node:test';
import assert from 'node:assert/strict';

import {
  CONSENT_DOCUMENTS,
  CONSENT_DOCUMENT_KEYS,
  CONSENT_REASONS,
  currentDocumentVersions,
  evaluateConsent,
  validateAcceptedDocuments,
} from '../src/domain/consent.js';

/** A body accepting every document at the version currently in force. */
function acceptAll() {
  return { ...CONSENT_DOCUMENTS };
}

/** A stored row for a user who accepted everything and has not withdrawn. */
function goodRecord() {
  return { documents: { ...CONSENT_DOCUMENTS }, granted_at: new Date(), withdrawn_at: null };
}

test('every document in force has a version', () => {
  assert.ok(CONSENT_DOCUMENT_KEYS.length > 0);
  for (const key of CONSENT_DOCUMENT_KEYS) {
    assert.equal(typeof CONSENT_DOCUMENTS[key], 'string');
    assert.notEqual(CONSENT_DOCUMENTS[key].trim(), '');
  }
});

test('currentDocumentVersions hands out a copy, not the original', () => {
  const versions = currentDocumentVersions();
  versions.privacy_policy = 'tampered';
  assert.notEqual(CONSENT_DOCUMENTS.privacy_policy, 'tampered');
});

test('a full, current acceptance is valid', () => {
  const result = validateAcceptedDocuments(acceptAll());
  assert.deepEqual(result.missing, []);
  assert.deepEqual(result.mismatched, []);
  assert.deepEqual(Object.keys(result.accepted).sort(), [...CONSENT_DOCUMENT_KEYS].sort());
});

test('a missing document is reported, not silently accepted', () => {
  const partial = acceptAll();
  delete partial.medical_disclaimer;

  const result = validateAcceptedDocuments(partial);
  assert.deepEqual(result.missing, ['medical_disclaimer']);
  assert.equal(result.accepted.medical_disclaimer, undefined);
});

test('an empty or non-string version counts as missing', () => {
  for (const bad of ['', '   ', null, 42, {}]) {
    const body = { ...acceptAll(), terms: bad };
    const result = validateAcceptedDocuments(body);
    assert.deepEqual(result.missing, ['terms'], `expected ${JSON.stringify(bad)} to be missing`);
  }
});

test('accepting a version that is not the one in force is a mismatch', () => {
  // The case that matters: an older build shows last month's policy and posts
  // the version it showed. Recording that against the current text would be
  // evidence of something that did not happen.
  const stale = { ...acceptAll(), privacy_policy: '0.9' };

  const result = validateAcceptedDocuments(stale);
  assert.deepEqual(result.mismatched, ['privacy_policy']);
  assert.equal(result.accepted.privacy_policy, undefined);
});

test('unrecognised documents are reported but do not invalidate the rest', () => {
  const result = validateAcceptedDocuments({ ...acceptAll(), cookie_policy: '1.0' });
  assert.deepEqual(result.unknown, ['cookie_policy']);
  assert.deepEqual(result.missing, []);
  assert.deepEqual(result.mismatched, []);
});

test('a rubbish body is missing everything rather than throwing', () => {
  for (const bad of [null, undefined, 'yes', 7, []]) {
    const result = validateAcceptedDocuments(bad);
    assert.deepEqual(result.missing.sort(), [...CONSENT_DOCUMENT_KEYS].sort());
  }
});

test('no record at all means consent is needed', () => {
  const status = evaluateConsent(null);
  assert.equal(status.hasConsent, false);
  assert.equal(status.needsConsent, true);
  assert.equal(status.reason, CONSENT_REASONS.neverGiven);
});

test('a complete current record means consent stands', () => {
  const status = evaluateConsent(goodRecord());
  assert.equal(status.hasConsent, true);
  assert.equal(status.needsConsent, false);
  assert.equal(status.reason, null);
  assert.deepEqual(status.outdatedDocuments, []);
});

test('a withdrawn record does not count, however complete', () => {
  const status = evaluateConsent({ ...goodRecord(), withdrawn_at: new Date() });
  assert.equal(status.hasConsent, false);
  assert.equal(status.reason, CONSENT_REASONS.withdrawn);
});

test('bumping a document version asks that user again', () => {
  const record = goodRecord();
  record.documents.privacy_policy = '0.9';

  const status = evaluateConsent(record);
  assert.equal(status.hasConsent, false);
  assert.equal(status.reason, CONSENT_REASONS.documentsUpdated);
  assert.deepEqual(status.outdatedDocuments, ['privacy_policy']);
});

test('a record predating a document asks for that document', () => {
  // Accounts that consented before the medical disclaimer existed have a row
  // that never mentioned it. They are not "consented" to it by omission.
  const record = goodRecord();
  delete record.documents.medical_disclaimer;

  const status = evaluateConsent(record);
  assert.equal(status.needsConsent, true);
  assert.deepEqual(status.outdatedDocuments, ['medical_disclaimer']);
});

test('a record with no documents field is treated as no consent', () => {
  const status = evaluateConsent({ granted_at: new Date(), withdrawn_at: null });
  assert.equal(status.hasConsent, false);
  assert.equal(status.outdatedDocuments.length, CONSENT_DOCUMENT_KEYS.length);
});

/* ------------------------------------------------------------------ *
 * Permission vocabulary bridge
 *
 * Two vocabularies are live at once and a v1 write used to replace the
 * stored object wholesale, deleting the legacy flags the older read paths
 * still depend on -- which is what switched the partner decoder off.
 * ------------------------------------------------------------------ */

test('a v1 patch carries its legacy equivalents', async () => {
  const { legacyFlagsForPatch } = await import('../src/domain/partnerPermissions.js');

  assert.deepEqual(legacyFlagsForPatch({ mood: true }), { shareMood: true });
  assert.deepEqual(legacyFlagsForPatch({ sleep: false }), { shareSleep: false });
  assert.deepEqual(
    legacyFlagsForPatch({ mood: true, sleep: true }),
    { shareMood: true, shareSleep: true },
  );
});

test('keys with no legacy equivalent contribute nothing', async () => {
  const { legacyFlagsForPatch } = await import('../src/domain/partnerPermissions.js');

  assert.deepEqual(legacyFlagsForPatch({ symptoms: true, energy: true }), {});
  assert.deepEqual(legacyFlagsForPatch({}), {});
  assert.deepEqual(legacyFlagsForPatch(), {});
});

test('non-boolean and unknown keys are ignored rather than mirrored', async () => {
  const { legacyFlagsForPatch } = await import('../src/domain/partnerPermissions.js');

  assert.deepEqual(legacyFlagsForPatch({ mood: 'yes' }), {});
  assert.deepEqual(legacyFlagsForPatch({ notAPermission: true }), {});
});

test('merging a v1 patch preserves flags the v1 vocabulary does not name', async () => {
  const { legacyFlagsForPatch, normalizePermissions } =
    await import('../src/domain/partnerPermissions.js');

  // What the connection actually holds, including the decoder switch.
  const stored = {
    shareMood: false,
    shareCycle: true,
    allowDecoderMan: true,
    allowAiSuggestionsMan: true,
  };

  const previous = normalizePermissions(stored);
  const clean = { mood: true };

  // The merge the service performs.
  const next = { ...stored, ...previous, ...clean, ...legacyFlagsForPatch(clean) };

  // The decoder survives a change to an unrelated permission. Before the fix
  // this key was gone, and the decoder endpoint refused every request.
  assert.equal(next.allowDecoderMan, true);
  assert.equal(next.allowAiSuggestionsMan, true);
  assert.equal(next.shareCycle, true);

  // And both vocabularies agree about the key that was actually changed.
  assert.equal(next.mood, true);
  assert.equal(next.shareMood, true);
});

/* ------------------------------------------------------------------ *
 * AI cost accounting
 *
 * Every chat-completions response carries a `usage` block that nothing read,
 * so spend could not be attributed to a user, a feature or an endpoint.
 * ------------------------------------------------------------------ */

test('a priced model costs input and output at its own rates', async () => {
  const { estimateCostUsd } = await import('../src/domain/aiPricing.js');

  // grok-4.3: $1.25 per million in, $2.50 per million out.
  const cost = estimateCostUsd({
    model: 'x-ai/grok-4.3',
    promptTokens: 1_000_000,
    completionTokens: 1_000_000,
  });
  assert.equal(cost, 3.75);

  assert.equal(
    estimateCostUsd({ model: 'x-ai/grok-4.3', promptTokens: 1000, completionTokens: 0 }),
    0.00125,
  );
});

test('an unpriced model is null, never zero', async () => {
  const { estimateCostUsd } = await import('../src/domain/aiPricing.js');

  // Zero would quietly understate the bill; null says "unknown" out loud.
  assert.equal(estimateCostUsd({ model: 'some/new-model', promptTokens: 5000 }), null);
  assert.equal(estimateCostUsd({ model: null, promptTokens: 5000 }), null);
});

test('missing token counts are treated as zero, not NaN', async () => {
  const { estimateCostUsd } = await import('../src/domain/aiPricing.js');

  assert.equal(estimateCostUsd({ model: 'x-ai/grok-4.3' }), 0);
  assert.equal(
    estimateCostUsd({ model: 'x-ai/grok-4.3', promptTokens: undefined, completionTokens: null }),
    0,
  );
});

test('a summary totals tokens and keeps unpriced calls visible', async () => {
  const { summariseUsage } = await import('../src/domain/aiPricing.js');

  const summary = summariseUsage([
    { model: 'x-ai/grok-4.3', prompt_tokens: 1000, completion_tokens: 500 },
    { model: 'x-ai/grok-4.3', prompt_tokens: 2000, completion_tokens: 1000 },
    { model: 'unknown/model', prompt_tokens: 9000, completion_tokens: 9000 },
  ]);

  assert.equal(summary.calls, 3);
  assert.equal(summary.promptTokens, 12000);
  assert.equal(summary.completionTokens, 10500);
  assert.equal(summary.totalTokens, 22500);

  // Only the two priced calls contribute money, and the third is reported
  // rather than silently folded in at zero.
  assert.equal(summary.unpricedCalls, 1);
  assert.ok(Math.abs(summary.costUsd - (0.00375 + 0.00375)) < 1e-9);
});

test('an empty summary is zero rather than NaN', async () => {
  const { summariseUsage } = await import('../src/domain/aiPricing.js');

  const summary = summariseUsage([]);
  assert.equal(summary.calls, 0);
  assert.equal(summary.totalTokens, 0);
  assert.equal(summary.costUsd, 0);
  assert.equal(summary.unpricedCalls, 0);
});

test('the prices carry the date they were verified', async () => {
  const { PRICES_VERIFIED_ON } = await import('../src/domain/aiPricing.js');

  // Providers reprice without notice; a rate with no date cannot be audited.
  assert.match(PRICES_VERIFIED_ON, /^\d{4}-\d{2}-\d{2}$/);
});
