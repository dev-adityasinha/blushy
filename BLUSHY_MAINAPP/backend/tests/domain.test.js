import test from 'node:test';
import assert from 'node:assert/strict';

import {
  LIFE_STAGES,
  normalizeLifeStage,
  evaluateTransition,
  getBranchCapabilities,
  getHomeModules,
  getBranchInitialContext,
} from '../src/domain/lifeStages.js';
import { calculatePregnancyState, getMilestones, trimesterForWeek, resolvePregnancyEnd } from '../src/domain/pregnancy.js';
import { calculatePostpartumState, getRecoveryMilestones, postpartumPhase } from '../src/domain/postpartum.js';
import { evaluateRedFlags, getEmergencyResources, resolveRegion, applySafetyGate, ESCALATION_LEVELS } from '../src/domain/safety.js';
import { scoreScreening, getDueCheckpoint, shouldTriggerMoodCheckIn, SCREENING_OUTCOMES } from '../src/domain/screening.js';
import {
  defaultPermissions,
  normalizePermissions,
  sanitizePermissionPatch,
  buildPartnerSafeContext,
  filterSharedInsights,
  hasGrant,
  CONNECTION_STATES,
  PERMISSION_KEYS,
} from '../src/domain/partnerPermissions.js';
import { computePatterns, correlation, findInsightsInvalidatedBy } from '../src/domain/patterns.js';
import { buildCarePlan, resolveAdaptiveMode, ADAPTIVE_MODES, COMPLETION_STATES } from '../src/domain/carePlan.js';
import { validateEvent, describeEvent, isUserConfirmedSource } from '../src/domain/healthEvents.js';
import { buildFertilityIndicators, detectBbtShift } from '../src/domain/fertility.js';
import {
  defaultNotificationPreferences,
  sanitizeNotificationPreferences,
  isWithinQuietHours,
  evaluateDelivery,
  canSendProactiveSia,
} from '../src/domain/notifications.js';
import { canTransition, validateSupportRequest, SUPPORT_REQUEST_STATES } from '../src/domain/supportRequests.js';
import { resolvePeriodDuration, observedPeriodDurations } from '../src/domain/periodDuration.js';
import {
  evaluatePost,
  canView,
  audienceForRole,
  defaultAnonymity,
  isVisibleState,
  isValidReportReason,
  isValidModeratorAction,
} from '../src/domain/communityModeration.js';

/**
 * Deterministic domain tests (spec §30 "Testing").
 *
 * These cover exactly the list the spec says must be unit tested: cycle and
 * pregnancy calculations, permissions and revocation, red flag escalation,
 * screening scoring, life stage transitions, and AI context filtering. No
 * database is involved, so they are fast and run anywhere.
 */

/* ================================================================== *
 * Life stage transitions (spec §23)
 * ================================================================== */

test('life stage: legacy Flutter stage keys normalize onto canonical branches', () => {
  assert.equal(normalizeLifeStage('firstPeriodNotStarted'), LIFE_STAGES.FIRST_PERIOD);
  assert.equal(normalizeLifeStage('Living with my cycle'), LIFE_STAGES.CYCLE_TRACKING);
  assert.equal(normalizeLifeStage('trying_to_conceive'), LIFE_STAGES.TTC);
  assert.equal(normalizeLifeStage('PREGNANCY'), LIFE_STAGES.PREGNANCY);
  assert.equal(normalizeLifeStage('nonsense-stage', null), null);
});

test('life stage: TTC to pregnancy requires explicit confirmation', () => {
  const unconfirmed = evaluateTransition(LIFE_STAGES.TTC, LIFE_STAGES.PREGNANCY, { confirmed: false });
  assert.equal(unconfirmed.allowed, false);
  assert.equal(unconfirmed.requiresConfirmation, true);
  assert.equal(unconfirmed.errorCode, 'CONFIRMATION_REQUIRED');

  const confirmed = evaluateTransition(LIFE_STAGES.TTC, LIFE_STAGES.PREGNANCY, { confirmed: true });
  assert.equal(confirmed.allowed, true);
  assert.equal(confirmed.reason, 'pregnancy_confirmed');
});

test('life stage: unsupported jumps are rejected', () => {
  const result = evaluateTransition(LIFE_STAGES.FIRST_PERIOD, LIFE_STAGES.MENOPAUSE, { confirmed: true });
  assert.equal(result.allowed, false);
  assert.equal(result.errorCode, 'TRANSITION_NOT_ALLOWED');
});

test('life stage: first selection during onboarding is always allowed', () => {
  const result = evaluateTransition(null, LIFE_STAGES.PREGNANCY, { confirmed: false });
  assert.equal(result.allowed, true);
  assert.equal(result.reason, 'initial_selection');
});

test('life stage: re-entering the same stage is a conflict, not a transition', () => {
  const result = evaluateTransition(LIFE_STAGES.CYCLE_TRACKING, LIFE_STAGES.CYCLE_TRACKING, { confirmed: true });
  assert.equal(result.allowed, false);
  assert.equal(result.errorCode, 'ALREADY_IN_STAGE');
});

test('life stage: menopause and pregnancy suppress cycle-centric language', () => {
  assert.equal(getBranchCapabilities(LIFE_STAGES.MENOPAUSE).cycleLanguage, false);
  assert.equal(getBranchCapabilities(LIFE_STAGES.PREGNANCY).cycleLanguage, false);
  assert.equal(getBranchCapabilities(LIFE_STAGES.CYCLE_TRACKING).cycleLanguage, true);
});

test('life stage: first period tracks periods but does not offer predictions', () => {
  const capabilities = getBranchCapabilities(LIFE_STAGES.FIRST_PERIOD);
  assert.equal(capabilities.cycleTracking, true);
  // Early post-menarche users must not receive false precision (spec §5).
  assert.equal(capabilities.cyclePredictions, false);
});

test('life stage: only the selected branch questions are returned', () => {
  const ttc = getBranchInitialContext(LIFE_STAGES.TTC).map((q) => q.key);
  assert.deepEqual(ttc, ['ttc_duration_months']);
  const pregnancy = getBranchInitialContext(LIFE_STAGES.PREGNANCY).map((q) => q.key);
  assert.ok(pregnancy.includes('due_date'));
  assert.ok(!pregnancy.includes('ttc_duration_months'));
});

test('life stage: home modules are ordered and branch specific', () => {
  const pregnancyModules = getHomeModules(LIFE_STAGES.PREGNANCY).map((m) => m.moduleId);
  assert.ok(pregnancyModules.includes('pregnancy_tracker'));
  assert.ok(!pregnancyModules.includes('hero_tracker'));

  const orders = getHomeModules(LIFE_STAGES.CYCLE_TRACKING).map((m) => m.order);
  assert.deepEqual(orders, [...orders].sort((a, b) => a - b));
});

/* ================================================================== *
 * Pregnancy arithmetic (spec §15, §26)
 * ================================================================== */

test('pregnancy: gestational week derives deterministically from the due date', () => {
  // 40 weeks from 2026-01-01 LMP is 2026-10-08.
  const state = calculatePregnancyState({ dueDate: '2026-10-08', referenceDate: '2026-05-21' });
  assert.equal(state.state, 'ready');
  assert.equal(state.gestationalWeek, 20);
  assert.equal(state.trimester, 2);
  assert.equal(state.dateSource, 'due_date');
});

test('pregnancy: LMP produces the same answer as the equivalent due date', () => {
  const fromLmp = calculatePregnancyState({ lmpDate: '2026-01-01', referenceDate: '2026-05-21' });
  const fromDue = calculatePregnancyState({ dueDate: '2026-10-08', referenceDate: '2026-05-21' });
  assert.equal(fromLmp.gestationalWeek, fromDue.gestationalWeek);
  assert.equal(fromLmp.dateSource, 'lmp');
});

test('pregnancy: a reported week keeps advancing from the date it was reported', () => {
  const state = calculatePregnancyState({
    week: 10,
    weekRecordedOn: '2026-05-01',
    referenceDate: '2026-05-15',
  });
  assert.equal(state.state, 'ready');
  assert.equal(state.gestationalWeek, 12);
  assert.equal(state.dateSource, 'reported_week');
});

test('pregnancy: no source date returns insufficient_data, never a guess', () => {
  const state = calculatePregnancyState({ referenceDate: '2026-05-21' });
  assert.equal(state.state, 'insufficient_data');
  assert.equal(state.gestationalWeek, null);
  assert.equal(state.trimester, null);
});

test('pregnancy: trimester boundaries', () => {
  assert.equal(trimesterForWeek(12), 1);
  assert.equal(trimesterForWeek(13), 2);
  assert.equal(trimesterForWeek(26), 2);
  assert.equal(trimesterForWeek(27), 3);
});

test('pregnancy: milestones split around the current week', () => {
  const milestones = getMilestones(20);
  assert.equal(milestones.current.week, 20);
  assert.ok(milestones.passed.every((m) => m.week < 20));
  assert.ok(milestones.upcoming.every((m) => m.week > 20));
});

test('pregnancy: every end outcome blocks further pregnancy content', () => {
  for (const outcome of ['birth', 'loss', 'termination', 'other', 'prefer_not_to_say']) {
    const resolution = resolvePregnancyEnd(outcome);
    assert.ok(resolution, `${outcome} should resolve`);
    assert.equal(resolution.blocksPregnancyContent, true);
    assert.equal(resolution.requiresConfirmation, true);
  }
  assert.equal(resolvePregnancyEnd('unknown_outcome'), null);
});

test('pregnancy: birth routes to postpartum, loss routes to a support flow', () => {
  assert.equal(resolvePregnancyEnd('birth').nextStage, LIFE_STAGES.POSTPARTUM);
  assert.equal(resolvePregnancyEnd('loss').nextStage, LIFE_STAGES.EVERYDAY_WELLNESS);
  assert.equal(resolvePregnancyEnd('loss').supportFlow, 'pregnancy_loss_support');
});

/* ================================================================== *
 * Postpartum (spec §16)
 * ================================================================== */

test('postpartum: days and phase derive from the birth date', () => {
  const state = calculatePostpartumState({ birthDate: '2026-05-01', referenceDate: '2026-06-12' });
  assert.equal(state.state, 'ready');
  assert.equal(state.daysSinceBirth, 42);
  assert.equal(state.weeksSinceBirth, 6);
  assert.equal(state.phase, 'early');
});

test('postpartum: a future birth date is rejected rather than rendered', () => {
  const state = calculatePostpartumState({ birthDate: '2027-01-01', referenceDate: '2026-06-12' });
  assert.equal(state.state, 'insufficient_data');
  assert.equal(state.reason, 'birth_date_in_future');
});

test('postpartum: phases are descriptive windows', () => {
  assert.equal(postpartumPhase(3), 'immediate');
  assert.equal(postpartumPhase(30), 'early');
  assert.equal(postpartumPhase(120), 'extended');
  assert.equal(postpartumPhase(300), 'late');
});

test('postpartum: recovery milestones align to the six week review', () => {
  const milestones = getRecoveryMilestones(42);
  assert.equal(milestones.current.day, 42);
  assert.equal(milestones.current.screening, 'EPDS');
});

/* ================================================================== *
 * Red flag escalation (spec §15, §26)
 * ================================================================== */

test('red flag: bleeding in pregnancy escalates to emergency and suppresses wellness', () => {
  const result = evaluateRedFlags({
    lifeStage: 'pregnancy',
    symptoms: [{ symptom: 'heavy bleeding', severity: 5 }],
  });
  assert.equal(result.triggered, true);
  assert.equal(result.level, ESCALATION_LEVELS.EMERGENCY);
  assert.equal(result.suppressWellnessContent, true);
  assert.ok(result.rules[0].instruction.length > 0);
  assert.ok(result.rules[0].source);
  assert.ok(result.rules[0].reviewer);
});

test('red flag: reduced movements only fire from 24 weeks', () => {
  const early = evaluateRedFlags({ lifeStage: 'pregnancy', freeText: 'baby not moving much', gestationalWeek: 18 });
  assert.ok(!early.rules.some((r) => r.ruleId === 'rf_pg_reduced_movements'));

  const late = evaluateRedFlags({ lifeStage: 'pregnancy', freeText: 'baby not moving much', gestationalWeek: 30 });
  assert.ok(late.rules.some((r) => r.ruleId === 'rf_pg_reduced_movements'));
});

test('red flag: severity-gated rules need a logged severity, not free text alone', () => {
  const textOnly = evaluateRedFlags({ lifeStage: 'cycle_tracking', freeText: 'unbearable pain today' });
  assert.ok(!textOnly.rules.some((r) => r.ruleId === 'rf_gyn_severe_pelvic_pain'));

  const logged = evaluateRedFlags({
    lifeStage: 'cycle_tracking',
    symptoms: [{ symptom: 'pelvic pain', severity: 9 }],
  });
  assert.ok(logged.rules.some((r) => r.ruleId === 'rf_gyn_severe_pelvic_pain'));
});

test('red flag: self-harm language escalates in every life stage', () => {
  for (const stage of ['cycle_tracking', 'menopause', 'postpartum', 'everyday_wellness']) {
    const result = evaluateRedFlags({ lifeStage: stage, freeText: 'I have been thinking about self harm' });
    assert.equal(result.triggered, true, `stage ${stage}`);
    assert.equal(result.suppressWellnessContent, true, `stage ${stage}`);
  }
});

test('red flag: post-menopausal bleeding is flagged, and is not flagged for cycling users', () => {
  const menopause = evaluateRedFlags({ lifeStage: 'menopause', symptoms: [{ symptom: 'spotting' }] });
  assert.ok(menopause.rules.some((r) => r.ruleId === 'rf_gyn_postmenopausal_bleeding'));

  const cycling = evaluateRedFlags({ lifeStage: 'cycle_tracking', symptoms: [{ symptom: 'spotting' }] });
  assert.ok(!cycling.rules.some((r) => r.ruleId === 'rf_gyn_postmenopausal_bleeding'));
});

test('red flag: nothing fires on ordinary logs', () => {
  const result = evaluateRedFlags({
    lifeStage: 'cycle_tracking',
    symptoms: [{ symptom: 'bloating', severity: 3 }, { symptom: 'fatigue', severity: 4 }],
  });
  assert.equal(result.triggered, false);
  assert.equal(result.suppressWellnessContent, false);
});

test('safety gate: AI output is replaced during an emergency escalation', () => {
  const redFlagResult = evaluateRedFlags({ lifeStage: 'pregnancy', symptoms: [{ symptom: 'heavy bleeding' }] });
  const gated = applySafetyGate({
    aiOutput: { type: 'wellness_tip', body: 'Try a warm bath and some rest.' },
    redFlagResult,
    emergencyResources: getEmergencyResources('IN'),
  });

  assert.equal(gated.blocked, true);
  assert.equal(gated.output.type, 'safety_escalation');
  assert.equal(gated.output.source, 'medical_reference');
  assert.ok(!JSON.stringify(gated.output).includes('warm bath'));
});

test('emergency resources: region aware, and honest when the region is unknown', () => {
  assert.equal(getEmergencyResources('IN').emergencyNumber, '112');
  assert.equal(getEmergencyResources('US').emergencyNumber, '911');
  assert.equal(getEmergencyResources('GB').emergencyNumber, '999');
  assert.equal(getEmergencyResources('DE').region, 'EU');
  // No fabricated number for an unknown region.
  assert.equal(getEmergencyResources('ZZ').emergencyNumber, null);
  assert.equal(getEmergencyResources(null).region, 'default');
});

test('emergency resources: region resolves from locale and timezone', () => {
  assert.equal(resolveRegion({ locale: 'en-IN' }), 'IN');
  assert.equal(resolveRegion({ timezone: 'Europe/London' }), 'GB');
  assert.equal(resolveRegion({ region: 'us' }), 'US');
  assert.equal(resolveRegion({}), null);
});

/* ================================================================== *
 * Screening scoring (spec §16, §26)
 * ================================================================== */

test('screening: EPDS reverse scoring is applied to the correct items', () => {
  // All answers at option index 0.
  const allZero = scoreScreening('EPDS', Array(10).fill(0));
  assert.equal(allZero.ok, true);
  // Items 1, 2 and 4 score 0; the other seven reverse to 3.
  assert.equal(allZero.result.totalScore, 21);

  const allThree = scoreScreening('EPDS', Array(10).fill(3));
  assert.equal(allThree.result.totalScore, 9);
});

test('screening: EPDS outcome bands', () => {
  // Construct a deliberately low total: forward items 0, reverse items option 3.
  const responses = [0, 0, 3, 0, 3, 3, 3, 3, 3, 3];
  const result = scoreScreening('EPDS', responses);
  assert.equal(result.result.totalScore, 0);
  assert.equal(result.result.outcome, SCREENING_OUTCOMES.BELOW_THRESHOLD);
  assert.equal(result.result.requiresProfessionalSupport, false);
});

test('screening: a positive self-harm item escalates to crisis regardless of total', () => {
  // Low everywhere except the final (self-harm) item.
  const responses = [0, 0, 3, 0, 3, 3, 3, 3, 3, 2];
  const result = scoreScreening('EPDS', responses);
  assert.equal(result.result.crisisItemPositive, true);
  assert.equal(result.result.outcome, SCREENING_OUTCOMES.CRISIS);
  assert.equal(result.result.requiresProfessionalSupport, true);
  assert.equal(result.result.suppressesWellnessContent, true);
});

test('screening: a result is never a diagnosis and always carries instrument metadata', () => {
  const result = scoreScreening('EPDS', Array(10).fill(1));
  assert.equal(result.result.isDiagnosis, false);
  assert.equal(result.result.instrumentId, 'EPDS');
  assert.ok(result.result.instrumentVersion);
  assert.ok(result.result.engineVersion);
  assert.ok(result.result.source.includes('Cox'));
});

test('screening: malformed submissions are rejected', () => {
  assert.equal(scoreScreening('EPDS', Array(9).fill(0)).ok, false);
  assert.equal(scoreScreening('EPDS', Array(10).fill(7)).ok, false);
  assert.equal(scoreScreening('NOT_AN_INSTRUMENT', Array(10).fill(0)).ok, false);
});

test('screening: PHQ-9 has no reverse scoring', () => {
  const allZero = scoreScreening('PHQ9', Array(9).fill(0));
  assert.equal(allZero.result.totalScore, 0);

  const allMax = scoreScreening('PHQ9', Array(9).fill(3));
  assert.equal(allMax.result.totalScore, 27);
  // Item 9 is the self-harm item, so a positive answer there escalates past
  // "concerning" to crisis regardless of the band the total falls in.
  assert.equal(allMax.result.outcome, SCREENING_OUTCOMES.CRISIS);

  const concerningWithoutCrisisItem = scoreScreening('PHQ9', [3, 3, 3, 3, 0, 0, 0, 0, 0]);
  assert.equal(concerningWithoutCrisisItem.result.totalScore, 12);
  assert.equal(concerningWithoutCrisisItem.result.outcome, SCREENING_OUTCOMES.CONCERNING);
  assert.equal(concerningWithoutCrisisItem.result.crisisItemPositive, false);
});

test('screening: checkpoints only become due inside their window and once', () => {
  assert.equal(getDueCheckpoint('EPDS', 5, []), null);
  assert.equal(getDueCheckpoint('EPDS', 16, []).checkpointDay, 14);
  assert.equal(getDueCheckpoint('EPDS', 16, [14]), null);
});

test('screening: repeated concerning moods trigger a check-in, with a cooldown', () => {
  const events = Array.from({ length: 6 }, (_, i) => ({
    payload: { mood: 'low' },
    timestamp: new Date(Date.UTC(2026, 4, 10 + i)).toISOString(),
  }));
  const reference = new Date(Date.UTC(2026, 4, 18));

  const triggered = shouldTriggerMoodCheckIn(events, { referenceDate: reference });
  assert.equal(triggered.triggered, true);
  assert.equal(triggered.concerningDayCount, 6);

  const cooled = shouldTriggerMoodCheckIn(events, {
    referenceDate: reference,
    lastTriggeredAt: new Date(Date.UTC(2026, 4, 16)).toISOString(),
  });
  assert.equal(cooled.triggered, false);
  assert.equal(cooled.reason, 'cooldown');
});

/* ================================================================== *
 * Partner permissions and AI context filtering (spec §9, §10, §22, §25)
 * ================================================================== */

test('permissions: every shareable permission defaults to off', () => {
  const defaults = defaultPermissions();
  for (const key of PERMISSION_KEYS) {
    if (key === 'care_requests') continue; // always on: the request is addressed to the partner
    assert.equal(defaults[key], false, `${key} must default to off`);
  }
});

test('permissions: legacy flags migrate onto the canonical matrix', () => {
  const migrated = normalizePermissions({ shareMood: true, shareCycle: true, shareSleep: false });
  assert.equal(migrated.mood, true);
  assert.equal(migrated.cycle_insights, true);
  assert.equal(migrated.sleep, false);
  assert.equal(migrated.journal, false);
});

test('permissions: unknown and always-on keys are rejected from a patch', () => {
  const { clean, rejected } = sanitizePermissionPatch({ mood: true, care_requests: false, not_a_key: true });
  assert.deepEqual(clean, { mood: true });
  assert.ok(rejected.includes('care_requests'));
  assert.ok(rejected.includes('not_a_key'));
});

const FULL_CONTEXT = {
  preferredName: 'Ada',
  lifeStage: 'cycle_tracking',
  mood: { value: 'low' },
  energyLevel: { value: 2 },
  sleep: { durationHours: 5 },
  symptoms: [{ symptom: 'cramps' }],
  cyclePhase: { phase: 'Luteal Phase' },
  journalEntries: [{ text: 'private thoughts' }],
  siaConversations: [{ text: 'private conversation' }],
  generalInsights: [{ title: 'Sleep and mood' }],
};

test('AI context filter: nothing leaks with default permissions', () => {
  const filtered = buildPartnerSafeContext(FULL_CONTEXT, defaultPermissions());
  assert.equal(filtered.state, 'empty');
  assert.equal(filtered.context.mood, undefined);
  assert.equal(filtered.context.journalEntries, undefined);
  assert.equal(filtered.context.siaConversations, undefined);
  // Non-private context that keeps the partner app useful is still present.
  assert.equal(filtered.context.partnerPreferredName, 'Ada');
  assert.equal(filtered.context.relationshipActive, true);
});

test('AI context filter: enabling energy shares energy and nothing else', () => {
  const filtered = buildPartnerSafeContext(FULL_CONTEXT, { ...defaultPermissions(), energy: true });
  assert.deepEqual(filtered.context.energyLevel, { value: 2 });
  assert.equal(filtered.context.mood, undefined);
  assert.equal(filtered.context.symptoms, undefined);
  assert.equal(filtered.context.cyclePhase, undefined);
  assert.ok(filtered.allowedGrants.includes('log.energy'));
  assert.ok(filtered.restrictedGrants.includes('log.mood'));
});

test('AI context filter: journal and Sia conversations need their own explicit grants', () => {
  const withJournal = buildPartnerSafeContext(FULL_CONTEXT, { ...defaultPermissions(), journal: true });
  assert.ok(withJournal.context.journalEntries);
  assert.equal(withJournal.context.siaConversations, undefined);
});

test('AI context filter: an inactive relationship returns nothing at all', () => {
  const allOn = Object.fromEntries(PERMISSION_KEYS.map((key) => [key, true]));
  for (const state of [CONNECTION_STATES.REVOKED, CONNECTION_STATES.PENDING, CONNECTION_STATES.BLOCKED, CONNECTION_STATES.EXPIRED]) {
    const filtered = buildPartnerSafeContext(FULL_CONTEXT, allOn, { connectionState: state });
    assert.equal(filtered.state, 'restricted', `state ${state}`);
    assert.equal(filtered.context.relationshipActive, false, `state ${state}`);
    assert.equal(filtered.context.mood, undefined, `state ${state}`);
  }
});

test('shared insights: an insight generated before revocation stops being returned', () => {
  const insights = [{ id: 'i1', title: 'Energy', requiredGrants: ['log.energy'] }];

  const before = filterSharedInsights(insights, { ...defaultPermissions(), energy: true });
  assert.equal(before.length, 1);

  const after = filterSharedInsights(insights, { ...defaultPermissions(), energy: false });
  assert.equal(after.length, 0);
});

test('shared insights: an insight with no declared grants fails closed', () => {
  const allOn = Object.fromEntries(PERMISSION_KEYS.map((key) => [key, true]));
  assert.equal(filterSharedInsights([{ id: 'x' }], allOn).length, 0);
});

test('permissions: grant lookup maps to the right permission key', () => {
  const perms = { ...defaultPermissions(), cycle_insights: true };
  assert.equal(hasGrant(perms, 'cycle.phase'), true);
  assert.equal(hasGrant(perms, 'fertility.window'), false);
  assert.equal(hasGrant(perms, 'not.a.grant'), false);
});

/* ================================================================== *
 * Health events (spec §6, §21)
 * ================================================================== */

test('events: valid payloads produce a canonical stored shape', () => {
  const result = validateEvent({
    eventType: 'sleep_logged',
    payload: { durationHours: 7.5, quality: 'good' },
    source: 'manual',
  });
  assert.equal(result.ok, true);
  assert.equal(result.event.schemaVersion, 1);
  assert.equal(result.event.userConfirmed, true);
  // `reportedAs` is null for an exact entry; it only carries a value when the
  // UI offered a bucket rather than a precise number.
  assert.deepEqual(result.event.payload, { durationHours: 7.5, quality: 'good', reportedAs: null });
});

test('events: AI-derived events are never marked user confirmed', () => {
  const result = validateEvent({ eventType: 'mood_logged', payload: { mood: 'low' }, source: 'ai_derived' });
  assert.equal(result.event.userConfirmed, false);
  assert.equal(isUserConfirmedSource('ai_derived'), false);
  assert.equal(isUserConfirmedSource('manual'), true);
});

test('events: invalid payloads and unknown types are rejected', () => {
  assert.equal(validateEvent({ eventType: 'sleep_logged', payload: { durationHours: 30 } }).ok, false);
  assert.equal(validateEvent({ eventType: 'mood_logged', payload: { mood: 'ecstatic' } }).ok, false);
  assert.equal(validateEvent({ eventType: 'not_a_type', payload: {} }).ok, false);
  assert.equal(validateEvent({ eventType: 'mood_logged', payload: { mood: 'low' }, source: 'telepathy' }).ok, false);
});

test('events: far-future timestamps are rejected', () => {
  const future = new Date(Date.now() + 10 * 86400000).toISOString();
  const result = validateEvent({ eventType: 'mood_logged', payload: { mood: 'good' }, timestamp: future });
  assert.equal(result.ok, false);
  assert.equal(result.field, 'timestamp');
});

test('events: a period cannot end before it starts', () => {
  const result = validateEvent({
    eventType: 'period_logged',
    payload: { startDate: '2026-05-10', endDate: '2026-05-08' },
  });
  assert.equal(result.ok, false);
});

test('events: flow is its own event type, tracked independently of the period start', () => {
  // Spec §5 tracks symptoms, mood, energy, flow and pain independently.
  const result = validateEvent({ eventType: 'flow_logged', payload: { flow: 'Heavy' } });
  assert.equal(result.ok, true);
  assert.equal(result.event.payload.flow, 'heavy');

  assert.equal(validateEvent({ eventType: 'flow_logged', payload: { flow: 'torrential' } }).ok, false);
  assert.equal(validateEvent({ eventType: 'flow_logged', payload: {} }).ok, false);
});

test('events: a bucketed answer keeps the label the user actually chose', () => {
  // The dashboard offers ranges, so the derived number must never stand alone
  // and be read back as a precise measurement.
  const sleep = validateEvent({
    eventType: 'sleep_logged',
    payload: { durationHours: 7, reportedAs: '6-8h' },
  });
  assert.equal(sleep.ok, true);
  assert.equal(sleep.event.payload.durationHours, 7);
  assert.equal(sleep.event.payload.reportedAs, '6-8h');

  const water = validateEvent({
    eventType: 'hydration_logged',
    payload: { glasses: 8, reportedAs: '2L' },
  });
  assert.equal(water.event.payload.reportedAs, '2L');

  // An exact entry simply has no bucket label.
  const exact = validateEvent({ eventType: 'sleep_logged', payload: { durationHours: 7.5 } });
  assert.equal(exact.event.payload.reportedAs, null);
});

test('events: timeline text is descriptive, never interpretive', () => {
  const text = describeEvent({ eventType: 'sleep_logged', payload: { durationHours: 7, quality: 'good' } });
  assert.equal(text, 'Slept 7h (good)');
});

/* ================================================================== *
 * Patterns (spec §7, §8)
 * ================================================================== */

test('patterns: too few paired observations returns insufficient_data', () => {
  const events = [
    { eventId: 'e1', eventType: 'sleep_logged', timestamp: '2026-05-01T22:00:00Z', payload: { durationHours: 6 }, source: 'manual' },
    { eventId: 'e2', eventType: 'mood_logged', timestamp: '2026-05-02T09:00:00Z', payload: { mood: 'low' }, source: 'manual' },
  ];
  const result = computePatterns({ events, referenceDate: new Date('2026-05-10T00:00:00Z') });
  assert.equal(result.state, 'insufficient_data');
  assert.equal(result.insights.length, 0);
});

test('patterns: a real sleep-mood relationship is detected with evidence attached', () => {
  const events = [];
  const sleepByDay = [4, 4.5, 5, 7.5, 8, 8.5, 4, 8];
  const moodByDay = ['awful', 'low', 'low', 'good', 'great', 'great', 'awful', 'good'];

  for (let i = 0; i < sleepByDay.length; i += 1) {
    const day = String(i + 1).padStart(2, '0');
    events.push({
      eventId: `s${i}`, eventType: 'sleep_logged', source: 'manual',
      timestamp: `2026-05-${day}T22:00:00Z`, payload: { durationHours: sleepByDay[i] },
    });
    const nextDay = String(i + 2).padStart(2, '0');
    events.push({
      eventId: `m${i}`, eventType: 'mood_logged', source: 'manual',
      timestamp: `2026-05-${nextDay}T09:00:00Z`, payload: { mood: moodByDay[i] },
    });
  }

  const result = computePatterns({ events, referenceDate: new Date('2026-05-15T00:00:00Z') });
  assert.equal(result.state, 'ready');

  const sleepMood = result.insights.find((insight) => insight.type === 'sleep_mood');
  assert.ok(sleepMood, 'expected a sleep_mood insight');
  assert.ok(sleepMood.sourceEventIds.length > 0, 'insight must cite its evidence');
  assert.ok(sleepMood.confidence > 0 && sleepMood.confidence <= 1);
  assert.equal(sleepMood.causalClaim, false);
  assert.ok(sleepMood.description.startsWith('Based on your recent logs'));
  assert.ok(sleepMood.engineVersion);
});

test('patterns: AI-derived events are never used as evidence', () => {
  const events = Array.from({ length: 10 }, (_, i) => ({
    eventId: `a${i}`, eventType: 'mood_logged', source: 'ai_derived',
    timestamp: `2026-05-${String(i + 1).padStart(2, '0')}T09:00:00Z`, payload: { mood: 'low' },
  }));
  const result = computePatterns({ events, referenceDate: new Date('2026-05-15T00:00:00Z') });
  assert.equal(result.state, 'empty');
});

test('patterns: deleted events are excluded and invalidate dependent insights', () => {
  const insights = [
    { id: 'i1', sourceEventIds: ['e1', 'e2'] },
    { id: 'i2', sourceEventIds: ['e3'] },
  ];
  const invalidated = findInsightsInvalidatedBy(insights, ['e2']);
  assert.deepEqual(invalidated.map((i) => i.id), ['i1']);
});

test('patterns: correlation refuses flat and short series', () => {
  assert.equal(correlation([1, 2, 3], [1, 2, 3]), null); // too short
  assert.equal(correlation([5, 5, 5, 5, 5, 5], [1, 2, 3, 4, 5, 6]), null); // no variance
  assert.ok(Math.abs(correlation([1, 2, 3, 4, 5, 6], [2, 4, 6, 8, 10, 12]) - 1) < 1e-9);
});

/* ================================================================== *
 * Care plan (spec §10, §20)
 * ================================================================== */

test('care plan: a safety escalation suppresses ordinary wellness actions entirely', () => {
  const plan = buildCarePlan({
    context: { lifeStage: 'cycle_tracking', averageSleepHours: 4, latestEnergyLevel: 1 },
    suppressWellness: true,
  });
  assert.equal(plan.state, 'restricted');
  assert.equal(plan.actions.length, 0);
  assert.equal(plan.suppressionReason, 'safety_escalation_active');
});

test('care plan: actions carry every field the spec table requires', () => {
  const plan = buildCarePlan({ context: { lifeStage: 'cycle_tracking', averageSleepHours: 5 } });
  const action = plan.actions.find((a) => a.id === 'care_sleep_001');
  assert.ok(action);
  for (const field of ['id', 'title', 'description', 'reason', 'category', 'priority', 'source', 'cta', 'completionState', 'validUntil']) {
    assert.ok(action[field] !== undefined, `missing ${field}`);
  }
  assert.equal(action.completionState, COMPLETION_STATES.NOT_STARTED);
});

test('care plan: the same action is not resurfaced inside its cooldown', () => {
  const context = { lifeStage: 'cycle_tracking', averageSleepHours: 5 };
  const history = [{ actionId: 'care_sleep_001', surfacedAt: new Date().toISOString(), completionState: COMPLETION_STATES.NOT_STARTED }];
  const plan = buildCarePlan({ context, history });
  assert.ok(!plan.actions.some((a) => a.id === 'care_sleep_001'));
});

test('care plan: cycle actions never reach a branch without cycle language', () => {
  const plan = buildCarePlan({
    context: { lifeStage: 'menopause', cycleLanguageAllowed: false, daysUntilNextPeriod: 2 },
  });
  assert.ok(!plan.actions.some((a) => a.id === 'care_cycle_001'));
});

test('care plan: low cognitive load mode trims to one action', () => {
  const context = { lifeStage: 'cycle_tracking', averageSleepHours: 4, latestEnergyLevel: 1, averageHydrationGlasses: 1 };
  const full = buildCarePlan({ context });
  assert.ok(full.actions.length > 1);

  const trimmed = buildCarePlan({ context, adaptiveMode: ADAPTIVE_MODES.LOW_COGNITIVE_LOAD });
  assert.equal(trimmed.actions.length, 1);
});

test('care plan: adaptive mode comes from self-reported signals only', () => {
  assert.equal(resolveAdaptiveMode({ latestEnergyLevel: 1 }), ADAPTIVE_MODES.CARE_MODE);
  assert.equal(resolveAdaptiveMode({ latestMood: 'low' }), ADAPTIVE_MODES.COMFORT_MODE);
  assert.equal(resolveAdaptiveMode({ latestEnergyLevel: 4, latestMood: 'good' }), ADAPTIVE_MODES.STANDARD);
  assert.equal(resolveAdaptiveMode({ userSelectedMode: ADAPTIVE_MODES.COMFORT_MODE, latestEnergyLevel: 5 }), ADAPTIVE_MODES.COMFORT_MODE);
});

/* ================================================================== *
 * Fertility (spec §13)
 * ================================================================== */

test('fertility: nothing is produced until the user opts in', () => {
  const result = buildFertilityIndicators({ events: [], ttcOptedIn: false });
  assert.equal(result.state, 'restricted');
  assert.equal(result.reason, 'ttc_not_opted_in');
});

test('fertility: conception probability is never produced', () => {
  const events = [{ eventId: 'l1', eventType: 'lh_test_logged', timestamp: '2026-05-10T08:00:00Z', payload: { result: 'peak' } }];
  const result = buildFertilityIndicators({ events, ttcOptedIn: true, referenceDate: '2026-05-12' });
  assert.equal(result.state, 'ready');
  assert.equal(result.conceptionProbability, null);
  assert.ok(result.disclaimer.includes('does not estimate the chance of conception'));
});

test('fertility: BBT shift needs enough readings before it is claimed', () => {
  const few = Array.from({ length: 5 }, (_, i) => ({
    eventType: 'bbt_logged', timestamp: `2026-05-0${i + 1}T06:00:00Z`, payload: { celsius: 36.4 },
  }));
  assert.equal(detectBbtShift(few).detected, false);

  const temps = [36.3, 36.4, 36.3, 36.4, 36.3, 36.4, 36.8, 36.9, 36.85];
  const readings = temps.map((celsius, i) => ({
    eventId: `b${i}`, eventType: 'bbt_logged',
    timestamp: `2026-05-${String(i + 1).padStart(2, '0')}T06:00:00Z`, payload: { celsius },
  }));
  const shift = detectBbtShift(readings);
  assert.equal(shift.detected, true);
  assert.ok(shift.sourceEventIds.length > 0);
});

/* ================================================================== *
 * Notifications (spec §19, §24)
 * ================================================================== */

test('notifications: sensitive content is hidden from the lock screen by default', () => {
  const preferences = defaultNotificationPreferences();
  assert.equal(preferences.hideSensitiveOnLockScreen, true);

  const decision = evaluateDelivery({
    category: 'period_reminder',
    preferences,
    title: 'Your period may start tomorrow',
    body: 'Based on your logged cycles.',
  });
  assert.equal(decision.deliver, true);
  assert.equal(decision.lockScreenTitle, 'Blushy');
  assert.ok(!decision.lockScreenBody.includes('period'));
});

test('notifications: non-sensitive categories keep their text', () => {
  const decision = evaluateDelivery({
    category: 'community',
    preferences: defaultNotificationPreferences(),
    title: 'New reply',
    body: 'Someone replied to your post.',
  });
  assert.equal(decision.lockScreenTitle, 'New reply');
});

test('notifications: quiet hours span midnight and defer delivery', () => {
  const quietHours = { enabled: true, start: '22:00', end: '07:00' };
  assert.equal(isWithinQuietHours(new Date('2026-05-10T23:30:00Z'), quietHours, 'UTC'), true);
  assert.equal(isWithinQuietHours(new Date('2026-05-10T03:00:00Z'), quietHours, 'UTC'), true);
  assert.equal(isWithinQuietHours(new Date('2026-05-10T12:00:00Z'), quietHours, 'UTC'), false);

  const preferences = { ...defaultNotificationPreferences(), quietHours, timezone: 'UTC' };
  const decision = evaluateDelivery({
    category: 'checkin_reminder', preferences, now: new Date('2026-05-10T23:30:00Z'),
  });
  assert.equal(decision.deliver, false);
  assert.equal(decision.deferUntilQuietHoursEnd, true);
});

test('notifications: safety escalations bypass quiet hours and cannot be turned off', () => {
  const preferences = sanitizeNotificationPreferences(
    { categories: { safety_escalation: false }, quietHours: { enabled: true, start: '00:00', end: '23:59' } },
    defaultNotificationPreferences(),
  );
  assert.equal(preferences.categories.safety_escalation, true);

  const decision = evaluateDelivery({
    category: 'safety_escalation', preferences, now: new Date('2026-05-10T03:00:00Z'), title: 'Please seek care',
  });
  assert.equal(decision.deliver, true);
});

test('notifications: a disabled category is not delivered', () => {
  const preferences = sanitizeNotificationPreferences({ categories: { community: false } }, defaultNotificationPreferences());
  const decision = evaluateDelivery({ category: 'community', preferences });
  assert.equal(decision.deliver, false);
  assert.equal(decision.reason, 'category_disabled');
});

test('notifications: proactive Sia is rate limited', () => {
  const now = new Date('2026-05-10T12:00:00Z');
  assert.equal(canSendProactiveSia([], now).allowed, true);
  assert.equal(canSendProactiveSia(['2026-05-10T06:00:00Z'], now).allowed, false);
  assert.equal(canSendProactiveSia(['2026-05-09T06:00:00Z'], now).allowed, true);
  const threeThisWeek = ['2026-05-09T06:00:00Z', '2026-05-07T06:00:00Z', '2026-05-05T06:00:00Z'];
  assert.equal(canSendProactiveSia(threeThisWeek, now).allowed, false);
});

/* ================================================================== *
 * Support requests (spec §11)
 * ================================================================== */

test('support requests: only the partner may acknowledge, only the requester may revoke', () => {
  assert.equal(canTransition(SUPPORT_REQUEST_STATES.PENDING, SUPPORT_REQUEST_STATES.ACKNOWLEDGED, 'partner').allowed, true);
  assert.equal(canTransition(SUPPORT_REQUEST_STATES.PENDING, SUPPORT_REQUEST_STATES.ACKNOWLEDGED, 'requester').allowed, false);
  assert.equal(canTransition(SUPPORT_REQUEST_STATES.PENDING, SUPPORT_REQUEST_STATES.REVOKED, 'requester').allowed, true);
  assert.equal(canTransition(SUPPORT_REQUEST_STATES.PENDING, SUPPORT_REQUEST_STATES.REVOKED, 'partner').allowed, false);
});

test('support requests: completed and revoked are terminal', () => {
  assert.equal(canTransition(SUPPORT_REQUEST_STATES.COMPLETED, SUPPORT_REQUEST_STATES.PENDING, 'partner').allowed, false);
  assert.equal(canTransition(SUPPORT_REQUEST_STATES.REVOKED, SUPPORT_REQUEST_STATES.ACKNOWLEDGED, 'partner').allowed, false);
});

test('support requests: a custom request needs its own message, presets get a default', () => {
  assert.equal(validateSupportRequest({ type: 'custom', message: '' }).ok, false);
  const rest = validateSupportRequest({ type: 'rest' });
  assert.equal(rest.ok, true);
  assert.ok(rest.value.message.length > 0);
  assert.equal(validateSupportRequest({ type: 'not_a_type' }).ok, false);
});

test('support requests: expiry is clamped to one week', () => {
  const result = validateSupportRequest({ type: 'rest', expiresInHours: 10000 });
  assert.equal(result.value.expiresInHours, 168);
});

/* ================================================================== *
 * Community moderation (spec §12, §22)
 * ================================================================== */

test('moderation: female and partner communities are separate audiences', () => {
  assert.equal(audienceForRole('woman'), 'female_user');
  assert.equal(audienceForRole('man'), 'partner');
  assert.equal(audienceForRole('partner'), 'partner');

  const femalePost = { authorId: 'a', audience: 'female_user', moderationState: 'visible' };
  // A partner never sees the female community feed.
  assert.equal(canView({ post: femalePost, viewerUserId: 'p', viewerAudience: 'partner' }), false);
  assert.equal(canView({ post: femalePost, viewerUserId: 'w', viewerAudience: 'female_user' }), true);
});

test('moderation: the partner community is anonymous by default', () => {
  assert.equal(defaultAnonymity('partner'), true);
  assert.equal(defaultAnonymity('female_user'), false);
});

test('moderation: ordinary talk stays visible with no notice', () => {
  const result = evaluatePost({ title: 'Hello', text: 'Just saying hi to everyone here.' });
  assert.equal(result.state, 'visible');
  assert.equal(result.notice, null);
  assert.equal(result.requiresHumanReview, false);
});

test('moderation: personal experience on a sensitive topic is kept, with a notice', () => {
  const result = evaluatePost({
    title: 'My PCOS journey',
    text: 'I was diagnosed with PCOS last year and wanted to share how I have been getting on.',
  });
  // Kept visible - this is someone sharing experience, not misinformation.
  assert.equal(result.state, 'warned');
  assert.ok(result.sensitiveTopics.includes('pcos'));
  assert.ok(result.notice.includes('not medical advice'));
  assert.equal(result.requiresHumanReview, false);
});

test('moderation: a treatment claim on a sensitive topic goes to clinical review', () => {
  const result = evaluatePost({
    title: 'PCOS cure',
    text: 'You should stop taking metformin, inositol cures PCOS. Doctors are wrong about this.',
  });
  assert.equal(result.state, 'medical_review');
  assert.equal(result.requiresHumanReview, true);
  assert.ok(result.sensitiveTopics.includes('pcos'));
  assert.ok(result.claimSignals.length > 0);
});

test('moderation: a dosage on a sensitive topic is flagged for review', () => {
  const result = evaluatePost({
    title: 'HRT',
    text: 'I take 100mg of progesterone every night.',
  });
  assert.equal(result.state, 'medical_review');
  assert.ok(result.claimSignals.includes('dosage_mentioned'));
});

test('moderation: enough reports hold a post for review regardless of content', () => {
  const result = evaluatePost({
    title: 'Hello',
    text: 'Nothing clinical here.',
    reportCount: 3,
    reportReasons: ['spam', 'spam', 'harassment'],
  });
  assert.equal(result.state, 'pending_review');
  assert.equal(result.requiresHumanReview, true);
});

test('moderation: a reported misinformation claim on a sensitive topic escalates below the threshold', () => {
  const result = evaluatePost({
    title: 'Fertility',
    text: 'This is what happened during my IVF cycle.',
    reportCount: 1,
    reportReasons: ['misinformation'],
  });
  assert.equal(result.state, 'medical_review');
  assert.equal(result.requiresHumanReview, true);
});

test('moderation: hidden and removed posts leave the feed, warned ones do not', () => {
  assert.equal(isVisibleState('visible'), true);
  assert.equal(isVisibleState('warned'), true);
  assert.equal(isVisibleState('pending_review'), false);
  assert.equal(isVisibleState('medical_review'), false);
  assert.equal(isVisibleState('hidden'), false);
  assert.equal(isVisibleState('removed'), false);
});

test('moderation: an author still sees their own hidden post, but not a removed one', () => {
  const post = { authorId: 'me', audience: 'female_user', moderationState: 'hidden' };
  assert.equal(canView({ post, viewerUserId: 'me', viewerAudience: 'female_user' }), true);
  assert.equal(canView({ post, viewerUserId: 'someone', viewerAudience: 'female_user' }), false);

  const removed = { ...post, moderationState: 'removed' };
  assert.equal(canView({ post: removed, viewerUserId: 'me', viewerAudience: 'female_user' }), false);
});

test('moderation: a blocked author disappears from the feed', () => {
  const post = { authorId: 'blocked_person', audience: 'female_user', moderationState: 'visible' };
  assert.equal(
    canView({ post, viewerUserId: 'me', viewerAudience: 'female_user', blockedAuthorIds: ['blocked_person'] }),
    false,
  );
  assert.equal(canView({ post, viewerUserId: 'me', viewerAudience: 'female_user', blockedAuthorIds: [] }), true);
});

test('moderation: a moderator sees everything', () => {
  const post = { authorId: 'a', audience: 'partner', moderationState: 'removed' };
  assert.equal(canView({ post, viewerUserId: 'mod', viewerAudience: 'female_user', isModerator: true }), true);
});

test('moderation: report reasons and moderator actions are validated', () => {
  assert.equal(isValidReportReason('misinformation'), true);
  assert.equal(isValidReportReason('because_i_said_so'), false);
  assert.equal(isValidModeratorAction('remove'), true);
  assert.equal(isValidModeratorAction('delete_everything'), false);
});

test('life stage: every Flutter onboarding enum name maps to a branch', () => {
  // These are the exact values the wizard sends. A miss here means a user
  // completes onboarding and the engine silently never records their branch.
  const wizardEnum = {
    firstPeriodNotStarted: LIFE_STAGES.FIRST_PERIOD,
    firstPeriodStarted: LIFE_STAGES.FIRST_PERIOD,
    reproductiveYears: LIFE_STAGES.CYCLE_TRACKING,
    hormonalHealth: LIFE_STAGES.HORMONAL_HEALTH,
    tryingToConceive: LIFE_STAGES.TTC,
    pregnancy: LIFE_STAGES.PREGNANCY,
    postpartum: LIFE_STAGES.POSTPARTUM,
    perimenopause: LIFE_STAGES.PERIMENOPAUSE,
    menopause: LIFE_STAGES.MENOPAUSE,
  };

  for (const [given, expected] of Object.entries(wizardEnum)) {
    assert.equal(normalizeLifeStage(given, null), expected, `${given} did not map`);
  }
});


/* ================================================================== *
 * Period duration resolution (spec §22)
 * ================================================================== */

const DURATION_BOUNDS = { minDays: 2, maxDays: 10, defaultDays: 5, minObservations: 2 };

test('period duration: logged end dates outrank the stated onboarding answer', () => {
  const entries = [
    { periodStartDate: '2026-06-01', periodEndDate: '2026-06-07' },
    { periodStartDate: '2026-07-01', periodEndDate: '2026-07-07' },
  ];
  const result = resolvePeriodDuration(entries, { period_duration_days: 4 }, DURATION_BOUNDS);
  assert.equal(result.periodDurationDays, 7);
  assert.equal(result.periodDurationSource, 'logged');
  assert.equal(result.periodDurationObservations, 2);
});

test('period duration: the day count is inclusive of both ends', () => {
  const sameDay = observedPeriodDurations(
    [{ periodStartDate: '2026-06-01', periodEndDate: '2026-06-01' }],
    DURATION_BOUNDS,
  );
  assert.deepEqual(sameDay, [], 'one day is below the two-day minimum');
  const twoDays = observedPeriodDurations(
    [{ periodStartDate: '2026-06-01', periodEndDate: '2026-06-02' }],
    DURATION_BOUNDS,
  );
  assert.deepEqual(twoDays, [2]);
});

test('period duration: one observation is not enough to overrule the stated answer', () => {
  const entries = [
    { periodStartDate: '2026-06-01' },
    { periodStartDate: '2026-07-01', periodEndDate: '2026-07-07' },
  ];
  const result = resolvePeriodDuration(entries, { period_duration_days: 4 }, DURATION_BOUNDS);
  assert.equal(result.periodDurationDays, 4);
  assert.equal(result.periodDurationSource, 'stated');
});

test('period duration: an out-of-range span is discarded, never clamped', () => {
  const entries = [
    { periodStartDate: '2026-06-01', periodEndDate: '2026-06-21' },
    { periodStartDate: '2026-07-01', periodEndDate: '2026-07-25' },
  ];
  const result = resolvePeriodDuration(entries, {}, DURATION_BOUNDS);
  assert.equal(result.periodDurationObservations, 0, 'both spans exceed the maximum');
  assert.equal(result.periodDurationSource, 'default');
  assert.equal(result.periodDurationDays, 5);
  assert.notEqual(result.periodDurationDays, DURATION_BOUNDS.maxDays);
});

test('period duration: the median resists a single unusual period', () => {
  const entries = [
    { periodStartDate: '2026-04-01', periodEndDate: '2026-04-04' },
    { periodStartDate: '2026-05-01', periodEndDate: '2026-05-04' },
    { periodStartDate: '2026-06-01', periodEndDate: '2026-06-10' },
  ];
  const result = resolvePeriodDuration(entries, {}, DURATION_BOUNDS);
  assert.equal(result.periodDurationDays, 4, 'the 10-day outlier must not pull the estimate up');
  assert.equal(result.periodDurationObservations, 3);
});

test('period duration: with nothing logged and nothing stated, the default is labelled', () => {
  const result = resolvePeriodDuration([], {}, DURATION_BOUNDS);
  assert.equal(result.periodDurationDays, 5);
  assert.equal(result.periodDurationSource, 'default');
  assert.equal(result.periodDurationObservations, 0);
});
