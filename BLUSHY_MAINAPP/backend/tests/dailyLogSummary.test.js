import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

import { buildDailyLogSummary, hasLoggedToday, parseSymptomConsent } from '../src/domain/dailyLogSummary.js';

/**
 * The daily check-in and symptoms reaching Docsy.
 *
 * Docsy's context carried onboarding answers, predictions, insights, captures,
 * reports and journals — and nothing about what she logs every day. The one
 * thing she does daily was the one thing it could not see.
 */

const DAY = 86400000;
const base = Date.UTC(2026, 8, 3, 12);
const at = (d) => new Date(base - d * DAY).toISOString();
const ref = new Date(base);

const ev = (dayAgo, eventType, payload, extra = {}) => ({
  eventId: `${eventType}-${dayAgo}`,
  eventType,
  timestamp: at(dayAgo),
  payload,
  ...extra,
});

test('today is named as today, older days by date', () => {
  const summary = buildDailyLogSummary([
    ev(0, 'symptom_logged', { symptom: 'cramps' }),
    ev(2, 'mood_logged', { mood: 'low' }),
  ], { referenceDate: ref });

  assert.match(summary, /Today: cramps/);
  assert.match(summary, /2026-09-01: mood low/);
});

test('a day with several entries reads as one line', () => {
  const summary = buildDailyLogSummary([
    ev(0, 'symptom_logged', { symptom: 'headache' }),
    ev(0, 'sleep_logged', { durationHours: 5 }),
    ev(0, 'energy_logged', { level: 2 }),
  ], { referenceDate: ref });

  assert.match(summary, /Today: headache, slept 5h, energy 2\/5/);
});

test('it restates rather than concludes', () => {
  // The pattern engine decides what goes with what, behind six paired
  // observations. A summary that drew the link here would let the model
  // announce a finding nothing computed.
  const summary = buildDailyLogSummary([
    ev(0, 'symptom_logged', { symptom: 'fatigue' }),
    ev(0, 'sleep_logged', { durationHours: 4 }),
  ], { referenceDate: ref });

  for (const word of ['because', 'caused', 'linked', 'due to', 'explains']) {
    assert.ok(!summary.toLowerCase().includes(word), `must not say "${word}"`);
  }
  assert.match(summary, /not conclusions/);
});

test('nothing logged produces nothing, rather than an empty-looking day', () => {
  assert.equal(buildDailyLogSummary([], { referenceDate: ref }), '');
  assert.equal(
    buildDailyLogSummary([ev(30, 'symptom_logged', { symptom: 'cramps' })], { referenceDate: ref }),
    '',
    'outside the window is outside the summary',
  );
});

test('the model never reads its own earlier guesses back as fact', () => {
  const summary = buildDailyLogSummary([
    ev(0, 'symptom_logged', { symptom: 'nausea' }, { source: 'ai_derived' }),
  ], { referenceDate: ref });
  assert.equal(summary, '');
});

test('a deleted entry is gone from the context too', () => {
  const summary = buildDailyLogSummary([
    ev(0, 'symptom_logged', { symptom: 'cramps' }, { deletedAt: at(0) }),
  ], { referenceDate: ref });
  assert.equal(summary, '');
});

test('every category on the symptoms sheet can be read back', () => {
  // A category the summary cannot phrase is one Docsy is blind to.
  const summary = buildDailyLogSummary([
    ev(0, 'flow_logged', { flow: 'heavy' }),
    ev(0, 'cervical_mucus_logged', { observation: 'egg_white' }),
    ev(0, 'lh_test_logged', { result: 'peak' }),
    ev(0, 'sexual_activity_logged', { activity: 'unprotected', drive: 'high' }),
    ev(0, 'pregnancy_test_logged', { result: 'faint_line' }),
    ev(0, 'activity_logged', { activity: 'yoga' }),
    ev(0, 'bbt_logged', { celsius: 36.6 }),
    ev(0, 'weight_logged', { kg: 61.4 }),
    ev(0, 'hot_flash_logged', { severity: 6, nightSweat: true }),
  ], { referenceDate: ref });

  for (const fragment of [
    'heavy flow', 'cervical mucus egg_white', 'LH test peak',
    'unprotected', 'high sex drive', 'pregnancy test faint line',
    'yoga', 'BBT 36.6C', 'weight 61.4kg', 'night sweat 6/10',
  ]) {
    assert.ok(summary.includes(fragment), `missing: ${fragment}`);
  }
});

test('"no sexual activity" is carried, not dropped as a blank', () => {
  // A blank day and a day she said nothing happened are different, and the
  // fertility engine reads that difference.
  const summary = buildDailyLogSummary([
    ev(0, 'sexual_activity_logged', { activity: 'none' }),
  ], { referenceDate: ref });
  assert.match(summary, /no sexual activity/);
});

test('hasLoggedToday separates a quiet day from an unlogged one', () => {
  assert.equal(hasLoggedToday([ev(0, 'mood_logged', { mood: 'okay' })], ref), true);
  assert.equal(hasLoggedToday([ev(1, 'mood_logged', { mood: 'okay' })], ref), false);
  assert.equal(hasLoggedToday([], ref), false);
});

test('the prompt forbids Docsy drawing its own correlations from it', () => {
  // The engine computes patterns; Docsy phrases them. Without this the model
  // would happily assert a link from two entries on one day.
  const prompt = fs.readFileSync('src/services/aiChatService.js', 'utf8');
  assert.match(prompt, /HER DAILY CHECK-IN AND SYMPTOM LOGS/);
  assert.match(prompt, /Do NOT draw your own correlations/);
  // And it must say what an empty week means rather than leaving it silent.
  assert.match(prompt, /Do not assume that means she felt fine/);
});

test('a switched-off group stops reaching Docsy, even for older rows', () => {
  // Switching a category off does not delete what is stored, and the sheet
  // says so. What it must do is stop those readings shaping what Docsy says.
  const events = [
    ev(0, 'symptom_logged', { symptom: 'bloating' }),
    ev(0, 'symptom_logged', { symptom: 'cramps' }),
    ev(0, 'sexual_activity_logged', { activity: 'unprotected' }),
  ];

  const summary = buildDailyLogSummary(events, {
    referenceDate: ref,
    excludedEventTypes: new Set(['sexual_activity_logged']),
    excludedSymptoms: new Set(['bloating']),
  });

  assert.ok(summary.includes('cramps'), 'what she still shares must stay');
  assert.ok(!summary.includes('bloating'), 'the switched-off group must go');
  assert.ok(!summary.includes('unprotected'), 'and so must the whole type');
});

test('excluding one symptom group does not take the others with it', () => {
  // Six groups record as `symptom_logged`. Filtering by type would drop every
  // symptom she has ever logged because she switched off Digestion.
  const events = [
    ev(0, 'symptom_logged', { symptom: 'nausea' }),
    ev(0, 'symptom_logged', { symptom: 'headache' }),
    ev(0, 'symptom_logged', { symptom: 'hair thinning' }),
  ];

  const summary = buildDailyLogSummary(events, {
    referenceDate: ref,
    excludedSymptoms: new Set(['nausea', 'bloating', 'constipation', 'diarrhea']),
  });

  assert.ok(!summary.includes('nausea'));
  assert.ok(summary.includes('headache'));
  assert.ok(summary.includes('hair thinning'));
});

test('a record with no consent field filters nothing', () => {
  // Every account predates this field. Failing closed would silently blank
  // the context for all of them.
  const consent = parseSymptomConsent({});
  assert.equal(consent.excludedEventTypes.size, 0);
  assert.equal(consent.excludedSymptoms.size, 0);
});

test('the lists survive the JSON-string form the client sends', () => {
  // saveOnboardingAnswers encodes every list as a JSON string.
  const consent = parseSymptomConsent({
    symptom_consent_excluded_event_types: '["sexual_activity_logged"]',
    symptom_consent_excluded_symptoms: '["Bloating","Nausea"]',
  });
  assert.ok(consent.excludedEventTypes.has('sexual_activity_logged'));
  // Lower-cased, because that is how the payload stores symptom names.
  assert.ok(consent.excludedSymptoms.has('bloating'));
  assert.ok(consent.excludedSymptoms.has('nausea'));
});

test('a malformed consent value filters nothing rather than everything', () => {
  const consent = parseSymptomConsent({
    symptom_consent_excluded_symptoms: 'not json at all',
  });
  assert.equal(consent.excludedSymptoms.size, 0);
});
