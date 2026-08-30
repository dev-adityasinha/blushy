import test, { before, after } from 'node:test';
import { generateKeyPairSync } from 'node:crypto';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

import { startTestServer, stopTestServer, createTestUser, api, getDb } from './helpers/testServer.js';

/**
 * A calendar date `days` before today, on the same clock the services count
 * with. Building these from `toISOString()` uses UTC, which disagrees with the
 * local/user calendar for part of every day -- so day-count assertions failed
 * for the hours when the two dates differ.
 */
function daysAgoIso(days) {
  const now = new Date();
  const localMidnight = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
  return new Date(localMidnight - days * 86400000).toISOString().slice(0, 10);
}

/**
 * Same idea, but on the UTC calendar. `domain/postpartum.js` normalises "today"
 * with getUTC* accessors, so its day counts follow UTC rather than the local or
 * user calendar the other services use.
 */
function utcDaysAgoIso(days) {
  return new Date(Date.now() - days * 86400000).toISOString().slice(0, 10);
}


/**
 * Integration tests (spec §30 "Testing").
 *
 * These boot the real Express app against an in-memory MongoDB and exercise the
 * routes end to end, covering the integration cases the spec names:
 * onboarding -> Home, permission change -> partner Home, TTC -> Pregnancy,
 * pregnancy exit/loss, offline sync, timezone, export/deletion, and access
 * control / IDOR.
 */

before(async () => {
  await startTestServer();
});

after(async () => {
  await stopTestServer();
});

/**
 * Every spec-aligned response must carry the standard envelope (spec §27).
 */
function assertContract(body) {
  assert.ok(body, 'response body missing');
  for (const field of ['data', 'state', 'lastUpdated', 'source', 'version', 'permissions', 'errorCode']) {
    assert.ok(Object.prototype.hasOwnProperty.call(body, field), `contract field "${field}" missing`);
  }
  assert.ok(
    ['ready', 'empty', 'insufficient_data', 'restricted', 'error'].includes(body.state),
    `unexpected state "${body.state}"`,
  );
}

async function connectPartners(womanId, partnerId, permissions = {}) {
  const connectionId = randomUUID();
  await getDb().collection('partner_connections').insertOne({
    connection_id: connectionId,
    user_a_id: womanId,
    user_b_id: partnerId,
    permission_owner_user_id: womanId,
    permissions,
    status: 'active',
    created_at: new Date(),
    updated_at: new Date(),
  });
  return connectionId;
}

/* ================================================================== *
 * Response contract and authorization
 * ================================================================== */

test('every private endpoint requires authentication', async () => {
  const endpoints = [
    ['GET', '/api/v1/home'],
    ['GET', '/api/v1/cycle'],
    ['GET', '/api/v1/patterns'],
    ['GET', '/api/v1/care-plan'],
    ['GET', '/api/v1/events'],
    ['GET', '/api/v1/events/timeline'],
    ['GET', '/api/v1/life-stage'],
    ['GET', '/api/v1/safety/state'],
    ['GET', '/api/v1/notifications'],
    ['GET', '/api/v1/content/saved'],
  ];

  for (const [method, path] of endpoints) {
    const { status } = await api(method, path);
    assert.equal(status, 401, `${method} ${path} should require auth`);
  }
});

test('safety guidance resolves without a session', async () => {
  // Critical safety guidance cannot depend on an authenticated request
  // (spec §25).
  const { status, body } = await api('GET', '/api/v1/safety/emergency-resources?region=IN');
  assert.equal(status, 200);
  assertContract(body);
  assert.equal(body.data.emergencyNumber, '112');
});

test('an unknown region returns an honest empty number, not a guess', async () => {
  const { body } = await api('GET', '/api/v1/safety/emergency-resources?region=ZZ');
  assert.equal(body.data.emergencyNumber, null);
  assert.equal(body.errorCode, 'REGION_UNKNOWN');
});

/* ================================================================== *
 * Onboarding -> Home (spec §30)
 * ================================================================== */

test('onboarding to Home: an unonboarded user is told so rather than shown a fake branch', async () => {
  const user = await createTestUser();
  const { status, body } = await api('GET', '/api/v1/home', { token: user.token });

  assert.equal(status, 200);
  assertContract(body);
  assert.equal(body.state, 'empty');
  assert.equal(body.data.onboardingRequired, true);
  assert.equal(body.data.modules.length, 0);
});

test('onboarding to Home: selecting a journey composes the branch Home', async () => {
  const user = await createTestUser();

  const journeys = await api('GET', '/api/v1/life-stage/journeys');
  assert.equal(journeys.status, 200);
  assert.equal(journeys.body.data.length, 10);

  const transition = await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'cycle_tracking', context: { cycle_pattern: 'Regular' } },
  });
  assert.equal(transition.status, 200);
  assert.equal(transition.body.data.stage.lifeStage, 'cycle_tracking');

  const home = await api('GET', '/api/v1/home', { token: user.token });
  assert.equal(home.body.state, 'ready');
  assert.equal(home.body.data.onboardingRequired, false);

  const moduleIds = home.body.data.modules.map((m) => m.moduleId);
  assert.ok(moduleIds.includes('hero_tracker'));
  assert.ok(moduleIds.includes('patterns'));
  assert.ok(moduleIds.includes('care_plan'));

  // Every module carries its own contract state so one failure cannot break
  // the screen (spec §4).
  for (const module of home.body.data.modules) {
    assert.ok(module.state, `module ${module.moduleId} has no state`);
  }
});

test('Home: menopause gets no cycle hero and no cycle language', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'menopause', confirmed: true },
  });

  const home = await api('GET', '/api/v1/home', { token: user.token });
  const moduleIds = home.body.data.modules.map((m) => m.moduleId);
  assert.ok(!moduleIds.includes('hero_tracker'));
  assert.equal(home.body.data.capabilities.cycleLanguage, false);

  const cycle = await api('GET', '/api/v1/cycle', { token: user.token });
  assert.equal(cycle.body.state, 'restricted');
  assert.equal(cycle.body.data.cycleTrackingAvailable, false);
});

/* ================================================================== *
 * Cycle: log, recalculate, delete (spec §6, §28)
 * ================================================================== */

test('cycle: no period data returns empty, never a simulated cycle day', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  const cycle = await api('GET', '/api/v1/cycle', { token: user.token });
  assert.equal(cycle.body.state, 'empty');
  assert.equal(cycle.body.data.currentCycle.currentCycleDay, null);
  assert.equal(cycle.body.data.prediction.nextPeriodStartDate, null);
});

test('cycle: logging a period returns the recalculated canonical state', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  const today = new Date();
  const start = daysAgoIso(5);

  const logged = await api('POST', '/api/v1/cycle/periods', {
    token: user.token,
    body: { startDate: start, flow: 'medium' },
  });

  assert.equal(logged.status, 201);
  assertContract(logged.body);
  assert.equal(logged.body.data.event.eventType, 'period_logged');
  assert.equal(logged.body.data.cycle.currentCycle.currentCycleDay, 6);
  assert.ok(logged.body.data.cycle.calculationVersion);
});

test('cycle: a period logged with an end date keeps that end date', async () => {
  // Regression for the gap this closed: the only screen able to send an end
  // date was a bottom sheet that was never wired to a button, so no period
  // ever carried one and period duration always fell back to a default.
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  const start = daysAgoIso(8);
  const end = daysAgoIso(4);

  const logged = await api('POST', '/api/v1/cycle/periods', {
    token: user.token,
    body: { startDate: start, endDate: end },
  });
  assert.equal(logged.status, 201);
  assert.equal(logged.body.data.event.payload.endDate, end);

  const history = await api('GET', '/api/v1/cycle/periods', { token: user.token });
  const entry = history.body.data.find(
    (e) => (e.periodStartDate ?? e.startDate) === start,
  );
  assert.ok(entry, 'the logged period should appear in history');
  assert.equal(
    entry.periodEndDate ?? entry.endDate,
    end,
    'the end date must survive the round trip',
  );
});

/* ================================================================== *
 * Stated period duration (spec §22)
 * ================================================================== */

test('onboarding answers: a stated period duration is kept, in range', async () => {
  // Closes the last break in the chain: nothing used to write this key, so
  // every consumer fell through to a 5-day default for every user.
  const { userRepository } = await import('../src/repositories/userRepository.js');
  const user = await createTestUser();

  const saved = await userRepository.updateOnboardingAnswers(user.userId, {
    period_duration_days: 7,
  });
  assert.equal(saved.onboardingAnswers.period_duration_days, '7');
});

test('onboarding answers: an out-of-range period duration is dropped, not clamped', async () => {
  const { userRepository } = await import('../src/repositories/userRepository.js');
  const user = await createTestUser();

  await userRepository.updateOnboardingAnswers(user.userId, { period_duration_days: 7 });
  const saved = await userRepository.updateOnboardingAnswers(user.userId, {
    period_duration_days: 40,
  });
  // Clamping 40 to 10 would invent an answer the user never gave.
  assert.equal(saved.onboardingAnswers.period_duration_days, undefined);
});

test('onboarding answers: a stated duration reaches the prediction engine', async () => {
  const { userRepository } = await import('../src/repositories/userRepository.js');
  const { calculatePeriodPredictions } = await import('../src/services/periodPredictionService.js');
  const user = await createTestUser();

  await userRepository.updateOnboardingAnswers(user.userId, { period_duration_days: 7 });
  await api('POST', '/api/v1/cycle/periods', {
    token: user.token,
    body: { startDate: daysAgoIso(5) },
  });

  const result = await calculatePeriodPredictions(user.userId);
  assert.equal(result.currentCycle.periodDurationSource, 'stated');
  assert.equal(result.currentCycle.periodDurationDays, 7);
  // Day 6 of a stated 7-day period is still a period day.
  assert.equal(result.currentCycle.isCurrentPeriod, true);
});

/* ================================================================== *
 * Every duration consumer agrees (spec §22)
 * ================================================================== */

function twoLoggedSevenDayPeriods() {
  return [
    { periodStartDate: '2026-06-01', periodEndDate: '2026-06-07' },
    { periodStartDate: '2026-07-01', periodEndDate: '2026-07-07' },
  ];
}

test('partner cycle info: period length comes from logged end dates', async () => {
  const { buildCycleInfo } = await import('../src/services/partnerSuggestionService.js');

  const withLogs = buildCycleInfo('2026-07-01', {}, new Date('2026-07-06'), twoLoggedSevenDayPeriods());
  assert.equal(withLogs.periodLengthDays, 7);
  assert.equal(withLogs.periodLengthSource, 'logged');

  // Without them it still falls back, and says so rather than implying data.
  const withoutLogs = buildCycleInfo('2026-07-01', {}, new Date('2026-07-06'), []);
  assert.equal(withoutLogs.periodLengthDays, 5);
  assert.equal(withoutLogs.periodLengthSource, 'default');
});

test('health insights: a day-6 period is recognised once the real length is known', async () => {
  const { healthInsightsService } = await import('../src/services/healthInsightsService.js');

  // Day 6 of the cycle, relative to now, because this path uses the wall clock.
  const cycleStartDate = daysAgoIso(5);
  const args = { userId: 'u1', role: 'woman', onboardingAnswers: {}, cycleStartDate };

  const withLogs = healthInsightsService.analyzeUserHealth({
    ...args,
    periodEntries: twoLoggedSevenDayPeriods(),
  });
  const insight = withLogs.insights.find((i) => i.type === 'current_period');
  assert.ok(insight, 'day 6 of a 7-day period is still a period day');
  assert.match(insight.message, /day 6 of your period/);
  assert.match(insight.message, /expected duration: 7 days/);

  // The same day with no logged end dates falls back to five, so day 6 is not
  // reported as a period day. This is the disagreement the plumbing removed.
  const withoutLogs = healthInsightsService.analyzeUserHealth({ ...args, periodEntries: [] });
  assert.equal(
    withoutLogs.insights.find((i) => i.type === 'current_period'),
    undefined,
  );
});

test('cycle: a single logged period is insufficient_data, not false precision', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  const start = daysAgoIso(3);
  await api('POST', '/api/v1/cycle/periods', { token: user.token, body: { startDate: start } });

  const cycle = await api('GET', '/api/v1/cycle', { token: user.token });
  assert.equal(cycle.body.state, 'insufficient_data');
  assert.equal(cycle.body.data.dataSufficiency.confidenceLevel, 'low');
});

test('cycle: a future period date is rejected', async () => {
  const user = await createTestUser();
  const future = daysAgoIso(-10);

  const result = await api('POST', '/api/v1/cycle/periods', { token: user.token, body: { startDate: future } });
  assert.equal(result.status, 400);
  assert.equal(result.body.errorCode, 'VALIDATION_FAILED');
});

test('cycle: an overdue cycle reports the real day count, not a modulo of it', async () => {
  // Regression for the dashboard bug this replaced: the client computed
  // `daysSinceStart % cycleLength + 1`, so a period logged 61 days ago on a
  // 28-day cycle rendered as "Cycle Day 6" and the 33-day delay vanished.
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  // Three regular 28-day cycles establish the pattern, then a 61-day gap.
  for (const daysAgo of [145, 117, 89, 61]) {
    const date = daysAgoIso(daysAgo);
    await api('POST', '/api/v1/cycle/periods', { token: user.token, body: { startDate: date } });
  }

  const cycle = await api('GET', '/api/v1/cycle', { token: user.token });
  const current = cycle.body.data.currentCycle;

  // The real count, not 61 % 28 + 1 = 6.
  assert.equal(current.currentCycleDay, 62);
  assert.notEqual(current.currentCycleDay, 6);
  assert.equal(current.isOverdue, true);
  assert.equal(current.daysOverdue, 34);

  // An overdue cycle offers no forward prediction rather than a fabricated one.
  assert.equal(cycle.body.data.prediction.nextPeriodStartDate, null);
  assert.equal(cycle.body.data.prediction.estimatedOvulationDate, null);
  assert.equal(cycle.body.data.pregnancyInferred, false);
  assert.ok(cycle.body.data.lateNotice);
});

test('cycle: a late period never implies pregnancy', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  // Three cycles, then a long gap so the current cycle reads as overdue.
  for (const daysAgo of [130, 102, 74]) {
    const date = daysAgoIso(daysAgo);
    await api('POST', '/api/v1/cycle/periods', { token: user.token, body: { startDate: date } });
  }

  const cycle = await api('GET', '/api/v1/cycle', { token: user.token });
  assert.equal(cycle.body.data.currentCycle.isOverdue, true);
  assert.equal(cycle.body.data.pregnancyInferred, false);
  assert.ok(cycle.body.data.lateNotice);
});

/* ================================================================== *
 * Events, patterns and invalidation (spec §6, §7)
 * ================================================================== */

test('events: a check-in returns the canonical saved record', async () => {
  const user = await createTestUser();

  const result = await api('POST', '/api/v1/events', {
    token: user.token,
    body: { eventType: 'mood_logged', payload: { mood: 'low', intensity: 4 } },
  });

  assert.equal(result.status, 201);
  assertContract(result.body);
  assert.equal(result.body.data.event.eventType, 'mood_logged');
  assert.equal(result.body.data.event.schemaVersion, 1);
  assert.equal(result.body.data.event.userConfirmed, true);
  assert.ok(result.body.data.event.eventId);
  assert.ok(result.body.data.invalidates.includes('patterns'));
});

test('events: invalid payloads are rejected with a machine-readable code', async () => {
  const user = await createTestUser();
  const result = await api('POST', '/api/v1/events', {
    token: user.token,
    body: { eventType: 'sleep_logged', payload: { durationHours: 99 } },
  });

  assert.equal(result.status, 400);
  assert.equal(result.body.errorCode, 'VALIDATION_FAILED');
  assert.equal(result.body.state, 'error');
});

test('offline sync: repeating the same clientEventId does not duplicate', async () => {
  const user = await createTestUser();
  const clientEventId = `offline-${randomUUID()}`;
  const body = { eventType: 'energy_logged', payload: { level: 3 }, clientEventId };

  const first = await api('POST', '/api/v1/events', { token: user.token, body });
  const second = await api('POST', '/api/v1/events', { token: user.token, body });

  assert.equal(first.status, 201);
  assert.equal(second.status, 200);
  assert.equal(second.body.data.deduplicated, true);
  assert.equal(first.body.data.event.eventId, second.body.data.event.eventId);

  const list = await api('GET', '/api/v1/events?eventTypes=energy_logged', { token: user.token });
  assert.equal(list.body.data.length, 1);
});

test('offline sync: a batch reports accepted and rejected items separately', async () => {
  const user = await createTestUser();
  const result = await api('POST', '/api/v1/events/sync', {
    token: user.token,
    body: {
      events: [
        { eventType: 'mood_logged', payload: { mood: 'good' }, clientEventId: `b1-${randomUUID()}` },
        { eventType: 'sleep_logged', payload: { durationHours: 8 }, clientEventId: `b2-${randomUUID()}` },
        { eventType: 'sleep_logged', payload: { durationHours: -4 }, clientEventId: `b3-${randomUUID()}` },
      ],
    },
  });

  assert.equal(result.status, 200);
  assert.equal(result.body.data.acceptedCount, 2);
  assert.equal(result.body.data.rejectedCount, 1);
});

test('check-ins: a day of selector taps becomes events the pattern engine can read', async () => {
  // The dashboard check-in cards previously wrote only to local storage, so
  // nothing downstream could see them. Each tap now posts a validated event.
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  const taps = [
    { eventType: 'mood_logged', payload: { mood: 'good' } },
    { eventType: 'energy_logged', payload: { level: 3, reportedAs: 'Medium' } },
    { eventType: 'sleep_logged', payload: { durationHours: 7, reportedAs: '6-8h' } },
    { eventType: 'stress_logged', payload: { level: 1, reportedAs: 'Low' } },
    { eventType: 'hydration_logged', payload: { glasses: 8, reportedAs: '2L' } },
    { eventType: 'pain_logged', payload: { severity: 3, reportedAs: 'Mild' } },
    { eventType: 'flow_logged', payload: { flow: 'medium', reportedAs: 'Medium' } },
    { eventType: 'activity_logged', payload: { activity: 'exercise', durationMinutes: 20, reportedAs: 'Light' } },
  ];

  for (const tap of taps) {
    const result = await api('POST', '/api/v1/events', { token: user.token, body: tap });
    assert.equal(result.status, 201, `${tap.eventType} should persist`);
  }

  const stored = await api('GET', '/api/v1/events', { token: user.token });
  assert.equal(stored.body.data.length, taps.length);

  // The bucket label survives alongside the derived number.
  const sleep = stored.body.data.find((e) => e.eventType === 'sleep_logged');
  assert.equal(sleep.payload.durationHours, 7);
  assert.equal(sleep.payload.reportedAs, '6-8h');

  // And the entries show up on the timeline as plain history.
  const timeline = await api('GET', '/api/v1/events/timeline', { token: user.token });
  assert.equal(timeline.body.state, 'ready');
  assert.ok(timeline.body.data.entries.some((e) => e.eventType === 'flow_logged'));
});

test('check-ins: re-tapping the same metric on the same day updates rather than duplicates', async () => {
  const user = await createTestUser();
  const key = `checkin:${user.userId}:energy:2026-08-29`;

  const first = await api('POST', '/api/v1/events', {
    token: user.token,
    body: { eventType: 'energy_logged', payload: { level: 1, reportedAs: 'Low' }, clientEventId: key },
  });
  const second = await api('POST', '/api/v1/events', {
    token: user.token,
    body: { eventType: 'energy_logged', payload: { level: 5, reportedAs: 'High' }, clientEventId: key },
  });

  assert.equal(first.status, 201);
  assert.equal(second.status, 200);
  assert.equal(second.body.data.deduplicated, true);

  const stored = await api('GET', '/api/v1/events?eventTypes=energy_logged', { token: user.token });
  assert.equal(stored.body.data.length, 1, 'one energy entry per day');
});

test('check-ins: logging a red flag symptom returns the safety flow with the event', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'menopause', confirmed: true } });

  // Bleeding after menopause is a reviewed red flag.
  const logged = await api('POST', '/api/v1/events', {
    token: user.token,
    body: { eventType: 'symptom_logged', payload: { symptom: 'spotting' } },
  });

  assert.equal(logged.status, 201);
  assert.ok(logged.body.data.safety, 'the check-in response should carry the safety flow');
  assert.ok(logged.body.data.safety.steps[0].instruction);
  assert.ok(logged.body.data.safety.steps[0].source, 'guidance must cite a source');
});

test('patterns: insufficient data is an explicit state, not an empty card', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  await api('POST', '/api/v1/events', { token: user.token, body: { eventType: 'mood_logged', payload: { mood: 'good' } } });

  const patterns = await api('GET', '/api/v1/patterns', { token: user.token });
  assert.ok(['insufficient_data', 'empty'].includes(patterns.body.state));
  assert.deepEqual(patterns.body.data, []);
});

test('patterns: deleting a source event invalidates the insight built from it', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  // Enough paired sleep/mood days for the engine to find a relationship.
  const sleepHours = [4, 4.5, 5, 7.5, 8, 8.5, 4, 8, 4.5, 8.5];
  const moods = ['awful', 'low', 'low', 'good', 'great', 'great', 'awful', 'good', 'low', 'great'];

  for (let i = 0; i < sleepHours.length; i += 1) {
    const sleepDay = new Date(Date.now() - (sleepHours.length - i + 1) * 86400000);
    const moodDay = new Date(sleepDay.getTime() + 86400000);
    await api('POST', '/api/v1/events', {
      token: user.token,
      body: { eventType: 'sleep_logged', payload: { durationHours: sleepHours[i] }, timestamp: sleepDay.toISOString() },
    });
    await api('POST', '/api/v1/events', {
      token: user.token,
      body: { eventType: 'mood_logged', payload: { mood: moods[i] }, timestamp: moodDay.toISOString() },
    });
  }

  const patterns = await api('GET', '/api/v1/patterns?refresh=true', { token: user.token });
  assert.equal(patterns.body.state, 'ready');

  const insight = patterns.body.data.find((i) => i.type === 'sleep_mood');
  assert.ok(insight, 'expected a sleep_mood insight');
  assert.ok(insight.sourceEventIds.length > 0);
  assert.ok(insight.confidence > 0);
  assert.ok(insight.engineVersion);

  const evidenceId = insight.sourceEventIds[0];
  const deletion = await api('DELETE', `/api/v1/events/${evidenceId}`, { token: user.token });
  assert.equal(deletion.status, 200);
  assert.ok(deletion.body.data.recalculation.invalidated >= 1);

  const stored = await getDb().collection('user_insights').findOne({ insight_id: insight.id });
  assert.ok(['invalidated', 'active'].includes(stored.status));
  if (stored.status === 'invalidated') {
    assert.equal(stored.invalidated_reason, 'source_event_deleted');
  }
});

test('patterns: an insight only appears once it is earned, and carries its evidence', async () => {
  // The Patterns and Sia Note cards previously rendered hardcoded sentences
  // chosen by chat keyword, with a fixed "Medium" confidence. Nothing is shown
  // now until the user's own logs support it.
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  const early = await api('GET', '/api/v1/patterns?refresh=true', { token: user.token });
  assert.ok(['empty', 'insufficient_data'].includes(early.body.state));
  assert.deepEqual(early.body.data, []);

  // Enough paired sleep/mood days for a relationship to actually exist.
  const sleepHours = [4, 4.5, 5, 7.5, 8, 8.5, 4, 8, 4.5, 8.5];
  const moods = ['awful', 'low', 'low', 'good', 'great', 'great', 'awful', 'good', 'low', 'great'];
  for (let i = 0; i < sleepHours.length; i += 1) {
    const sleepDay = new Date(Date.now() - (sleepHours.length - i + 1) * 86400000);
    const moodDay = new Date(sleepDay.getTime() + 86400000);
    await api('POST', '/api/v1/events', {
      token: user.token,
      body: { eventType: 'sleep_logged', payload: { durationHours: sleepHours[i], reportedAs: '6-8h' }, timestamp: sleepDay.toISOString() },
    });
    await api('POST', '/api/v1/events', {
      token: user.token,
      body: { eventType: 'mood_logged', payload: { mood: moods[i] }, timestamp: moodDay.toISOString() },
    });
  }

  const earned = await api('GET', '/api/v1/patterns?refresh=true', { token: user.token });
  assert.equal(earned.body.state, 'ready');

  const insight = earned.body.data[0];
  // Everything the card renders is present and traceable.
  assert.ok(insight.description.startsWith('Based on your recent logs'));
  assert.ok(insight.sourceEventIds.length > 0, 'the evidence line needs source events');
  assert.ok(insight.observationCount > 0, 'the evidence line needs an observation count');
  assert.ok(insight.periodStart && insight.periodEnd, 'the evidence line needs a time window');
  assert.ok(insight.strength, 'the strength badge needs a value');
  assert.ok(insight.generatedAt, 'the timestamp needs a value');
  assert.ok(insight.engineVersion, 'the insight must be traceable to an engine version');
  assert.equal(insight.source, 'rule');
  assert.equal(insight.causalClaim, false);
});

test('patterns: marking an insight helpful keeps it, not-useful removes it', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  for (let i = 0; i < 6; i += 1) {
    await api('POST', '/api/v1/events', {
      token: user.token,
      body: {
        eventType: 'symptom_logged',
        payload: { symptom: 'headache', severity: 6 },
        timestamp: new Date(Date.now() - (10 - i) * 86400000).toISOString(),
      },
    });
  }

  const patterns = await api('GET', '/api/v1/patterns?refresh=true', { token: user.token });
  const insight = patterns.body.data[0];
  assert.ok(insight);

  const helpful = await api('POST', `/api/v1/patterns/${insight.id}/feedback`, {
    token: user.token,
    body: { helpful: true },
  });
  assert.equal(helpful.status, 200);

  const stillThere = await api('GET', '/api/v1/patterns', { token: user.token });
  assert.ok(stillThere.body.data.some((i) => i.id === insight.id), 'helpful should not remove it');

  await api('POST', `/api/v1/patterns/${insight.id}/feedback`, { token: user.token, body: { helpful: false } });
  const gone = await api('GET', '/api/v1/patterns', { token: user.token });
  assert.ok(!gone.body.data.some((i) => i.id === insight.id), 'not useful should remove it');
});

test('patterns: dismiss and feedback are recorded', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  for (let i = 0; i < 6; i += 1) {
    const day = new Date(Date.now() - (10 - i) * 86400000);
    await api('POST', '/api/v1/events', {
      token: user.token,
      body: { eventType: 'symptom_logged', payload: { symptom: 'headache', severity: 6 }, timestamp: day.toISOString() },
    });
  }

  const patterns = await api('GET', '/api/v1/patterns?refresh=true', { token: user.token });
  const insight = patterns.body.data[0];
  assert.ok(insight);

  const feedback = await api('POST', `/api/v1/patterns/${insight.id}/feedback`, {
    token: user.token,
    body: { helpful: false },
  });
  assert.equal(feedback.status, 200);

  const after = await api('GET', '/api/v1/patterns', { token: user.token });
  assert.ok(!after.body.data.some((i) => i.id === insight.id), 'a not-useful insight should stop being served');
});

/* ================================================================== *
 * Timezone (spec §24, §30)
 * ================================================================== */

test('timezone: the cycle read model honours the supplied timezone', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  const kolkata = await api('GET', '/api/v1/cycle?timezone=Asia/Kolkata', { token: user.token });
  assert.equal(kolkata.body.data.userTimezone, 'Asia/Kolkata');

  const auckland = await api('GET', '/api/v1/cycle?timezone=Pacific/Auckland', { token: user.token });
  assert.equal(auckland.body.data.userTimezone, 'Pacific/Auckland');

  // An invalid timezone falls back rather than throwing.
  const bad = await api('GET', '/api/v1/cycle?timezone=Not/AZone', { token: user.token });
  assert.equal(bad.status, 200);
  assert.equal(bad.body.data.timezoneSource ?? 'emergency_fallback', 'emergency_fallback');
});

/* ================================================================== *
 * TTC -> Pregnancy -> exit (spec §30)
 * ================================================================== */

test('TTC to pregnancy: requires confirmation, then carries context forward', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'ttc' } });

  const stage = await api('GET', '/api/v1/life-stage', { token: user.token });
  assert.equal(stage.body.data.lifeStage, 'ttc');
  assert.equal(stage.body.data.ttcOptedIn, true);

  const unconfirmed = await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', context: { due_date: '2027-01-01' } },
  });
  assert.equal(unconfirmed.status, 409);
  assert.equal(unconfirmed.body.errorCode, 'CONFIRMATION_REQUIRED');

  const missingContext = await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true },
  });
  assert.equal(missingContext.status, 422);
  assert.equal(missingContext.body.errorCode, 'MISSING_BRANCH_CONTEXT');
  assert.ok(missingContext.body.data.missingContext.includes('due_date'));

  const confirmed = await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-01-01' } },
  });
  assert.equal(confirmed.status, 200);
  assert.equal(confirmed.body.data.stage.lifeStage, 'pregnancy');

  const pregnancy = await api('GET', '/api/v1/pregnancy', { token: user.token });
  assert.equal(pregnancy.body.state, 'ready');
  assert.ok(Number.isInteger(pregnancy.body.data.gestationalWeek));
  assert.ok(pregnancy.body.data.calculationVersion);

  // History is preserved across the transition (spec §23).
  const history = await api('GET', '/api/v1/life-stage/history', { token: user.token });
  const stages = history.body.data.map((h) => h.toStage);
  assert.ok(stages.includes('ttc'));
  assert.ok(stages.includes('pregnancy'));
});

test('pregnancy exit: requires confirmation and permanently stops pregnancy content', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-01-01' } },
  });

  const unconfirmed = await api('POST', '/api/v1/life-stage/pregnancy/end', {
    token: user.token,
    body: { outcome: 'loss' },
  });
  assert.equal(unconfirmed.status, 409);
  assert.equal(unconfirmed.body.errorCode, 'CONFIRMATION_REQUIRED');

  const ended = await api('POST', '/api/v1/life-stage/pregnancy/end', {
    token: user.token,
    body: { outcome: 'loss', confirmed: true, endDate: new Date().toISOString().slice(0, 10) },
  });
  assert.equal(ended.status, 200);
  assert.equal(ended.body.data.nextStage, 'everyday_wellness');
  assert.equal(ended.body.data.supportFlow, 'pregnancy_loss_support');
  assert.equal(ended.body.data.partnerPregnancySharingMustStop, true);

  // Pregnancy week content must not continue afterwards (spec §15).
  const pregnancy = await api('GET', '/api/v1/pregnancy', { token: user.token });
  assert.equal(pregnancy.body.state, 'restricted');
  assert.equal(pregnancy.body.data.reason, 'pregnancy_ended');

  const home = await api('GET', '/api/v1/home', { token: user.token });
  const moduleIds = home.body.data.modules.map((m) => m.moduleId);
  assert.ok(!moduleIds.includes('pregnancy_tracker'));

  // The event survives so history is preserved.
  const events = await api('GET', '/api/v1/events?eventTypes=pregnancy_ended', { token: user.token });
  assert.equal(events.body.data.length, 1);
});

test('pregnancy birth transition moves to postpartum with the birth date carried over', async () => {
  const user = await createTestUser();
  const birthDate = utcDaysAgoIso(42);

  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: birthDate } },
  });
  const ended = await api('POST', '/api/v1/life-stage/pregnancy/end', {
    token: user.token,
    body: { outcome: 'birth', confirmed: true, endDate: birthDate },
  });

  assert.equal(ended.body.data.nextStage, 'postpartum');

  const postpartum = await api('GET', '/api/v1/postpartum', { token: user.token });
  assert.equal(postpartum.body.state, 'ready');
  assert.equal(postpartum.body.data.daysSinceBirth, 42);
  assert.equal(postpartum.body.data.screening.instrumentId, 'EPDS');
  assert.ok(postpartum.body.data.screening.checkpointDue, 'the six week checkpoint should be due');
});

/* ================================================================== *
 * Screening (spec §16)
 * ================================================================== */

test('care plan: actions are objects with a stated reason, not paragraphs', async () => {
  // The dashboard previously rendered a hardcoded list per life stage,
  // including a fabricated appointment. Actions are now derived from the
  // user's own logs and carry every field the card renders.
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  const empty = await api('GET', '/api/v1/care-plan', { token: user.token });
  assert.equal(empty.body.state, 'empty');
  assert.deepEqual(empty.body.data.actions, []);

  // Short sleep is what triggers the sleep action.
  for (let i = 0; i < 4; i += 1) {
    await api('POST', '/api/v1/events', {
      token: user.token,
      body: {
        eventType: 'sleep_logged',
        payload: { durationHours: 5, reportedAs: '<6h' },
        timestamp: new Date(Date.now() - (i + 1) * 86400000).toISOString(),
      },
    });
  }

  const plan = await api('GET', '/api/v1/care-plan', { token: user.token });
  assert.equal(plan.body.state, 'ready');

  const action = plan.body.data.actions.find((a) => a.category === 'sleep');
  assert.ok(action, 'expected a sleep action');
  for (const field of ['id', 'title', 'description', 'reason', 'category', 'priority', 'source', 'cta', 'completionState', 'validUntil']) {
    assert.ok(action[field] !== undefined && action[field] !== null, `action.${field} is missing`);
  }
  assert.equal(action.completionState, 'not_started');
  // The reason cites the user's own logged data.
  assert.match(action.reason, /sleep has averaged/i);
  assert.ok(plan.body.version, 'the ruleset version must be reported');
});

test('care plan: a completed action is not resurfaced during its cooldown', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  for (let i = 0; i < 4; i += 1) {
    await api('POST', '/api/v1/events', {
      token: user.token,
      body: {
        eventType: 'sleep_logged',
        payload: { durationHours: 5 },
        timestamp: new Date(Date.now() - (i + 1) * 86400000).toISOString(),
      },
    });
  }

  const before = await api('GET', '/api/v1/care-plan', { token: user.token });
  const action = before.body.data.actions.find((a) => a.category === 'sleep');
  assert.ok(action);

  const completed = await api('POST', `/api/v1/care-plan/${action.id}/complete`, { token: user.token });
  assert.equal(completed.status, 200);
  assert.equal(completed.body.data.completionState, 'completed');

  const after = await api('GET', '/api/v1/care-plan', { token: user.token });
  assert.ok(
    !after.body.data.actions.some((a) => a.id === action.id),
    'a completed action should not reappear immediately',
  );
});

test('screening: a concerning result routes to professional support, not wellness tips', async () => {
  const user = await createTestUser();

  const result = await api('POST', '/api/v1/safety/screening/submit', {
    token: user.token,
    body: { instrumentId: 'EPDS', responses: [3, 3, 0, 3, 0, 0, 0, 0, 0, 1], checkpointDay: 42 },
  });

  assert.equal(result.status, 201);
  assert.equal(result.body.data.result.crisisItemPositive, true);
  assert.equal(result.body.data.result.isDiagnosis, false);
  assert.ok(result.body.data.supportFlow);
  assert.equal(result.body.data.supportFlow.required, true);
  assert.ok(result.body.data.supportFlow.emergencyResources);
  assert.ok(result.body.data.result.instrumentVersion);
});

test('screening: validated item wording is never approximated', async () => {
  const user = await createTestUser();
  const result = await api('GET', '/api/v1/safety/screening/instruments/EPDS/items', { token: user.token });

  assert.equal(result.status, 200);
  // The seed deliberately omits licensed instrument wording, so the honest
  // answer is that it is not available rather than a paraphrase.
  assert.equal(result.body.data.itemsAvailable, false);
  assert.equal(result.body.errorCode, 'CONTENT_UNAVAILABLE');
});

test('screening: a concerning result suppresses the care plan', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });
  await api('POST', '/api/v1/events', { token: user.token, body: { eventType: 'sleep_logged', payload: { durationHours: 4 } } });

  const before = await api('GET', '/api/v1/care-plan', { token: user.token });
  assert.equal(before.body.state, 'ready');

  await api('POST', '/api/v1/safety/screening/submit', {
    token: user.token,
    body: { instrumentId: 'EPDS', responses: [3, 3, 0, 3, 0, 0, 0, 0, 0, 3] },
  });

  const after = await api('GET', '/api/v1/care-plan', { token: user.token });
  assert.equal(after.body.state, 'restricted');
  assert.equal(after.body.data.suppressed, true);
  assert.equal(after.body.data.actions.length, 0);
});



test('captcha: enabling it without an integration refuses rather than waves requests through', async () => {
  // The placeholder returned true for any token whenever CAPTCHA_ENABLED was
  // set, so turning the flag on looked like bot protection while verifying
  // nothing. A control that silently passes is worse than an absent one.
  const { verifyCaptchaToken, isCaptchaImplemented } = await import('../src/services/captchaService.js');
  const { env } = await import('../src/utils/env.js');

  const previous = env.captchaEnabled;
  env.captchaEnabled = true;
  try {
    assert.equal(isCaptchaImplemented(), false, 'no provider is integrated yet');
    assert.throws(
      () => verifyCaptchaToken('any-token-at-all'),
      (error) => error.statusCode === 503,
      'an unverified token must not be accepted',
    );
  } finally {
    env.captchaEnabled = previous;
  }
});

test('captcha: with the flag off nothing is required', async () => {
  const { verifyCaptchaToken } = await import('../src/services/captchaService.js');
  const { env } = await import('../src/utils/env.js');

  const previous = env.captchaEnabled;
  env.captchaEnabled = false;
  try {
    assert.equal(verifyCaptchaToken(null), true);
  } finally {
    env.captchaEnabled = previous;
  }
});

/* ------------------------------------------------------------------ *
 * Password reset (spec §2)
 *
 * The reset used to be proven by email + phone number alone, and the phone
 * comparison was skipped when the account had no number on record -- which
 * made knowing the email address sufficient to take the account over. It now
 * requires a code sent to the mailbox.
 * ------------------------------------------------------------------ */

async function createResettableUser(db, { email, phone = null, password = 'the-real-password' }) {
  const bcrypt = (await import('bcryptjs')).default;
  const userId = `reset_${randomUUID().replace(/-/g, '').slice(0, 12)}`;
  await db.collection('users_woman').insertOne({
    user_id: userId,
    email,
    display_name: 'Reset Test',
    password_hash: await bcrypt.hash(password, 10),
    phone_number: phone,
    email_verified_at: new Date(),
    role: 'woman',
    token_version: 1,
    created_at: new Date(),
    updated_at: new Date(),
  });
  return userId;
}

/**
 * Captures the code the service mails out, standing in for reading the inbox.
 * Brute forcing the stored bcrypt hash would mean up to a million compares.
 */
const sentResetCodes = new Map();
{
  const { emailService } = await import('../src/services/emailService.js');
  const realSend = emailService.sendVerificationLink;
  emailService.sendVerificationLink = async (email, link, code) => {
    if (code) sentResetCodes.set(email, code);
    if (link) return realSend(email, link, code);
    return { success: true, mode: 'captured-by-test' };
  };
}

async function readResetCode(_db, email) {
  return sentResetCodes.get(email) ?? null;
}

test('reset: knowing only the email address is not enough to take an account over', async () => {
  const db = getDb();
  const email = `victim-${randomUUID().slice(0, 8)}@example.test`;
  await createResettableUser(db, { email, phone: null });

  const attacker = await api('POST', '/api/auth/reset-password', {
    body: {
      email,
      phoneNumber: '+919999999999',
      newPassword: 'attacker-chosen-pw-1',
      confirmPassword: 'attacker-chosen-pw-1',
    },
  });
  assert.equal(attacker.status, 400, 'a reset with no emailed code must be refused');

  const login = await api('POST', '/api/auth/login-email', {
    body: { email, password: 'attacker-chosen-pw-1' },
  });
  assert.notEqual(login.status, 200, 'the attacker password must not work');
});

test('reset: a guessed code does not work either', async () => {
  const db = getDb();
  const email = `guess-${randomUUID().slice(0, 8)}@example.test`;
  await createResettableUser(db, { email });

  await api('POST', '/api/auth/send-password-reset-code', { body: { email } });
  const real = await readResetCode(db, email);
  const wrong = real === '000000' ? '111111' : '000000';

  const attempt = await api('POST', '/api/auth/reset-password', {
    body: { email, code: wrong, newPassword: 'another-password-1', confirmPassword: 'another-password-1' },
  });
  assert.equal(attempt.status, 401);
});

test('reset: the real code completes the reset and the new password works', async () => {
  const db = getDb();
  const email = `owner-${randomUUID().slice(0, 8)}@example.test`;
  await createResettableUser(db, { email });

  const requested = await api('POST', '/api/auth/send-password-reset-code', { body: { email } });
  assert.equal(requested.status, 200);

  const code = await readResetCode(db, email);
  assert.ok(code, 'requesting a reset must store a code');

  const reset = await api('POST', '/api/auth/reset-password', {
    body: { email, code, newPassword: 'my-new-password-1', confirmPassword: 'my-new-password-1' },
  });
  assert.equal(reset.status, 200);

  const login = await api('POST', '/api/auth/login-email', {
    body: { email, password: 'my-new-password-1' },
  });
  assert.equal(login.status, 200, 'the owner must be able to sign in afterwards');
});

test('reset: a used code cannot be replayed', async () => {
  const db = getDb();
  const email = `replay-${randomUUID().slice(0, 8)}@example.test`;
  await createResettableUser(db, { email });

  await api('POST', '/api/auth/send-password-reset-code', { body: { email } });
  const code = await readResetCode(db, email);

  await api('POST', '/api/auth/reset-password', {
    body: { email, code, newPassword: 'first-new-password-1', confirmPassword: 'first-new-password-1' },
  });

  const replay = await api('POST', '/api/auth/reset-password', {
    body: { email, code, newPassword: 'second-new-password-1', confirmPassword: 'second-new-password-1' },
  });
  assert.equal(replay.status, 400, 'a reset code is single use');
});

test('reset: requesting a code does not reveal whether the account exists', async () => {
  const db = getDb();
  const email = `known-${randomUUID().slice(0, 8)}@example.test`;
  await createResettableUser(db, { email });

  const known = await api('POST', '/api/auth/send-password-reset-code', { body: { email } });
  const unknown = await api('POST', '/api/auth/send-password-reset-code', {
    body: { email: `nobody-${randomUUID().slice(0, 8)}@example.test` },
  });

  assert.equal(known.status, unknown.status);
  assert.deepEqual(known.body, unknown.body);
});

test('reset: a stored phone number still has to match', async () => {
  const db = getDb();
  const email = `phone-${randomUUID().slice(0, 8)}@example.test`;
  await createResettableUser(db, { email, phone: '+919812345678' });

  await api('POST', '/api/auth/send-password-reset-code', { body: { email } });
  const code = await readResetCode(db, email);

  const wrongPhone = await api('POST', '/api/auth/reset-password', {
    body: {
      email,
      code,
      phoneNumber: '+919999999999',
      newPassword: 'yet-another-password-1',
      confirmPassword: 'yet-another-password-1',
    },
  });
  assert.equal(wrongPhone.status, 401);
});

test('reset: a Google-only account is not given a reset code', async () => {
  const db = getDb();
  const email = `google-${randomUUID().slice(0, 8)}@example.test`;
  await db.collection('users_woman').insertOne({
    user_id: `google_${randomUUID().replace(/-/g, '').slice(0, 12)}`,
    email,
    display_name: 'Google User',
    password_hash: null,
    google_id: 'google-subject-123',
    email_verified_at: new Date(),
    role: 'woman',
    token_version: 1,
    created_at: new Date(),
    updated_at: new Date(),
  });

  const requested = await api('POST', '/api/auth/send-password-reset-code', { body: { email } });
  assert.equal(requested.status, 200, 'still generic, so it reveals nothing');

  const crypto = await import('node:crypto');
  const emailHash = crypto.createHash('sha256').update(email).digest('hex');
  const stored = await db.collection('auth_password_resets').findOne({ email_hash: emailHash });
  assert.equal(stored, null, 'no code should have been issued');
});

/* ------------------------------------------------------------------ *
 * Screening history, handoff and the mood check-in (spec §16)
 *
 * Scoring itself is covered by domain tests; these cover the HTTP routes
 * around it, which had no coverage at all.
 * ------------------------------------------------------------------ */

test('screening: an all-clear result routes nowhere', async () => {
  const user = await createTestUser();

  const result = await api('POST', '/api/v1/safety/screening/submit', {
    token: user.token,
    body: { instrumentId: 'EPDS', responses: [0, 0, 3, 0, 3, 3, 3, 3, 3, 3] },
  });

  assert.equal(result.status, 201);
  assert.equal(result.body.data.result.crisisItemPositive, false);
  assert.equal(result.body.data.supportFlow, null, 'nothing to route anywhere');
});

test('screening: a submitted screening appears in the history', async () => {
  const user = await createTestUser();

  await api('POST', '/api/v1/safety/screening/submit', {
    token: user.token,
    body: { instrumentId: 'PHQ9', responses: [1, 1, 1, 1, 1, 1, 1, 1, 0] },
  });

  const history = await api('GET', '/api/v1/safety/screening/history', { token: user.token });
  assert.equal(history.status, 200);
  assert.ok(history.body.data.some((s) => s.instrumentId === 'PHQ9'));
});

test('screening: one account never sees another account screening history', async () => {
  const mine = await createTestUser();
  const theirs = await createTestUser();

  await api('POST', '/api/v1/safety/screening/submit', {
    token: theirs.token,
    body: { instrumentId: 'PHQ9', responses: [2, 2, 2, 2, 2, 2, 2, 2, 0] },
  });

  const history = await api('GET', '/api/v1/safety/screening/history', { token: mine.token });
  assert.deepEqual(history.body.data, [], 'a screening score is as private as it gets');
});

test('screening: a handoff records who the result was shared with', async () => {
  const user = await createTestUser();

  const submitted = await api('POST', '/api/v1/safety/screening/submit', {
    token: user.token,
    body: { instrumentId: 'PHQ9', responses: [2, 2, 2, 2, 2, 2, 2, 2, 0] },
  });
  const screeningId = submitted.body.data.result.screeningId;
  assert.ok(screeningId, 'a saved screening needs an id to hand off');

  const shared = await api('POST', `/api/v1/safety/screening/${screeningId}/handoff`, {
    token: user.token,
    body: { sharedWith: 'Dr Rao, city clinic' },
  });
  assert.equal(shared.status, 200);
  assert.equal(shared.body.data.handoffSharedWith, 'Dr Rao, city clinic');
});

test('screening: a handoff needs a recipient', async () => {
  const user = await createTestUser();
  const submitted = await api('POST', '/api/v1/safety/screening/submit', {
    token: user.token,
    body: { instrumentId: 'PHQ9', responses: [0, 0, 0, 0, 0, 0, 0, 0, 0] },
  });

  const shared = await api('POST', `/api/v1/safety/screening/${submitted.body.data.result.screeningId}/handoff`, {
    token: user.token,
    body: {},
  });
  assert.equal(shared.status, 400);
});

test('screening: nobody can hand off someone else screening result', async () => {
  const owner = await createTestUser();
  const outsider = await createTestUser();

  const submitted = await api('POST', '/api/v1/safety/screening/submit', {
    token: owner.token,
    body: { instrumentId: 'PHQ9', responses: [2, 2, 2, 2, 2, 2, 2, 2, 0] },
  });
  const screeningId = submitted.body.data.result.screeningId;

  const stolen = await api('POST', `/api/v1/safety/screening/${screeningId}/handoff`, {
    token: outsider.token,
    body: { sharedWith: 'somewhere else entirely' },
  });
  assert.equal(stolen.status, 404, 'this would send a stranger mental health score to a third party');
});

test('mood check-in: a quiet account is not prompted', async () => {
  // The prompt has to come from repeated concerning logs, not from opening the
  // app, or it becomes noise people dismiss without reading.
  const user = await createTestUser();

  const status = await api('GET', '/api/v1/safety/screening/mood-check-in', { token: user.token });
  assert.equal(status.status, 200);
  assert.equal(status.body.data.triggered, false);
  assert.equal(status.body.state, 'empty');
});

/* ================================================================== *
 * Red flag escalation through the API (spec §15)
 * ================================================================== */

test('Sia chat: a self-harm disclosure is answered by the ruleset, not the model', async () => {
  // Spec §22: AI cannot override deterministic safety rules. The model is not
  // called at all here, so there is no generation that could soften or delay
  // the reviewed instruction.
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  const result = await api('POST', '/ai/chat', {
    token: user.token,
    body: { message: 'I have been thinking about self harm lately' },
  });

  assert.equal(result.status, 200);
  assert.equal(result.body.aiGenerated, false, 'the model must not answer this');
  assert.ok(result.body.model.startsWith('safety-ruleset'));

  assert.equal(result.body.safety.triggered, true);
  assert.equal(result.body.safety.level, 'emergency');
  assert.equal(result.body.safety.suppressWellnessContent, true);
  assert.ok(result.body.safety.steps.length > 0);
  assert.ok(result.body.safety.emergencyResources);

  // The reply is the reviewed instruction from the rule.
  assert.equal(result.body.message, result.body.safety.steps[0].instruction);
  assert.ok(result.body.safety.steps[0].source, 'guidance must cite a source');

  // And it is auditable without storing what the user wrote.
  const incident = await getDb().collection('safety_incident_audit').findOne({
    user_id: user.userId,
    surface: 'sia_chat',
  });
  assert.ok(incident);
  assert.ok(incident.rule_ids.includes('rf_mh_self_harm'));
  assert.equal(incident.free_text, undefined);
  assert.equal(incident.message, undefined);
});

test('Sia chat: a pregnancy red flag in a message escalates', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-01-01' } },
  });

  const result = await api('POST', '/ai/chat', {
    token: user.token,
    body: { message: 'I noticed some heavy bleeding this morning, is that normal?' },
  });

  assert.equal(result.status, 200);
  assert.equal(result.body.aiGenerated, false);
  assert.equal(result.body.safety.level, 'emergency');
  assert.ok(/maternity unit|emergency/i.test(result.body.message));
});

test('Sia chat: an ordinary message goes to the model and records no incident', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  const result = await api('POST', '/ai/chat', {
    token: user.token,
    body: { message: 'What should I eat for more energy this week?' },
  });

  // The harness clears every AI provider key, so reaching the model fails.
  // That failure is the point: it proves this message took the normal
  // generation path rather than the ruleset path, which the escalation tests
  // above complete successfully without any key.
  assert.notEqual(result.status, 200);

  // And nothing was logged as a safety incident.
  const incidents = await getDb().collection('safety_incident_audit').countDocuments({ user_id: user.userId });
  assert.equal(incidents, 0, 'an ordinary question must not record a safety incident');
});

test('Sia chat: safety escalation does not depend on the AI provider being reachable', async () => {
  // The escalation replies below are produced with no AI provider configured,
  // so critical guidance cannot be taken down by an upstream outage.
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  const escalated = await api('POST', '/ai/chat', {
    token: user.token,
    body: { message: 'I keep thinking about how to kill myself' },
  });
  assert.equal(escalated.status, 200);
  assert.equal(escalated.body.aiGenerated, false);
  assert.ok(escalated.body.message.length > 0);

  const ordinary = await api('POST', '/ai/chat', {
    token: user.token,
    body: { message: 'Tell me about follicular phase nutrition' },
  });
  // Same deployment, same missing key: the ordinary path cannot answer.
  assert.notEqual(ordinary.status, 200);
});

test('red flag: logging bleeding in pregnancy returns the safety flow with the event', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-01-01' } },
  });

  const logged = await api('POST', '/api/v1/events', {
    token: user.token,
    body: { eventType: 'symptom_logged', payload: { symptom: 'heavy bleeding', severity: 6 } },
  });

  assert.equal(logged.status, 201);
  assert.ok(logged.body.data.safety, 'expected a safety flow on the response');
  assert.equal(logged.body.data.safety.level, 'emergency');
  assert.ok(logged.body.data.safety.steps[0].instruction);
  assert.ok(logged.body.data.safety.emergencyResources);

  // The safety banner must appear on Home and Sia must be suppressed.
  const home = await api('GET', '/api/v1/home', { token: user.token });
  assert.equal(home.body.data.safetyActive, true);
  const siaNote = home.body.data.modules.find((m) => m.moduleId === 'sia_note');
  assert.equal(siaNote.state, 'restricted');
  assert.equal(siaNote.errorCode, 'SAFETY_SUPPRESSED');

  // The incident is auditable without storing the user's words.
  const incident = await getDb().collection('safety_incident_audit').findOne({ user_id: user.userId });
  assert.ok(incident);
  assert.ok(incident.rule_ids.length > 0);
  assert.equal(incident.free_text, undefined);
});

/* ================================================================== *
 * Partner permissions and partner Home (spec §30)
 * ================================================================== */

/* ------------------------------------------------------------------ *
 * Partner invitations, end to end (spec §10)
 * ------------------------------------------------------------------ */

/* Every other partner test inserts a connection straight into the database,
 * so the path a real pair of users actually takes -- invite, appear, accept,
 * connect -- had no coverage at all. */

test('invite: an invitation reaches the person it was sent to', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });

  const sent = await api('POST', '/partner/invite', {
    token: woman.token,
    body: { partnerEmail: `${man.userId}@example.test` },
  });
  assert.ok(sent.status === 200 || sent.status === 201, `invite failed: ${sent.status}`);

  const incoming = await api('GET', '/partner/requests/incoming', { token: man.token });
  assert.equal(incoming.status, 200);
  assert.ok(
    (incoming.body.invitations ?? incoming.body).length >= 1,
    'the invitation should be waiting for the recipient',
  );

  // And it shows on the sender's side as outstanding.
  const outgoing = await api('GET', '/partner/requests/outgoing', { token: woman.token });
  assert.ok((outgoing.body.invitations ?? outgoing.body).length >= 1);
});

test('invite: accepting it produces a connection both sides can see', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });

  await api('POST', '/partner/invite', {
    token: woman.token,
    body: { partnerEmail: `${man.userId}@example.test` },
  });

  const incoming = await api('GET', '/partner/requests/incoming', { token: man.token });
  const invitation = (incoming.body.invitations ?? incoming.body)[0];
  const invitationId = invitation.invitationId ?? invitation._id ?? invitation.id;

  const accepted = await api('POST', `/partner/requests/${invitationId}/respond`, {
    token: man.token,
    body: { action: 'accept' },
  });
  assert.equal(accepted.status, 200);

  for (const [who, user] of [['woman', woman], ['man', man]]) {
    const connections = await api('GET', '/partner/connections', { token: user.token });
    const list = connections.body.connections ?? connections.body;
    assert.ok(
      list.some((c) => c.status === 'active'),
      `${who} should see an active connection`,
    );
  }
});

test('invite: declining leaves both sides unconnected', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });

  await api('POST', '/partner/invite', {
    token: woman.token,
    body: { partnerEmail: `${man.userId}@example.test` },
  });
  const incoming = await api('GET', '/partner/requests/incoming', { token: man.token });
  const invitation = (incoming.body.invitations ?? incoming.body)[0];
  const invitationId = invitation.invitationId ?? invitation._id ?? invitation.id;

  await api('POST', `/partner/requests/${invitationId}/respond`, {
    token: man.token,
    body: { action: 'reject' },
  });

  const connections = await api('GET', '/partner/connections', { token: woman.token });
  const list = connections.body.connections ?? connections.body;
  assert.ok(
    !list.some((c) => c.status === 'active'),
    'a declined invitation must not connect anyone',
  );
});

test('invite: you cannot invite yourself', async () => {
  const woman = await createTestUser({ role: 'woman' });

  const result = await api('POST', '/partner/invite', {
    token: woman.token,
    body: { partnerEmail: `${woman.userId}@example.test` },
  });
  assert.equal(result.status, 400);
});

test('invite: an address with no account is refused, not silently dropped', async () => {
  const woman = await createTestUser({ role: 'woman' });

  const result = await api('POST', '/partner/invite', {
    token: woman.token,
    body: { partnerEmail: 'nobody-here@example.test' },
  });
  assert.equal(result.status, 404, 'the sender needs to know it did not go anywhere');
});

test('invite: a third party cannot answer an invitation addressed to someone else', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const stranger = await createTestUser({ role: 'man' });

  await api('POST', '/partner/invite', {
    token: woman.token,
    body: { partnerEmail: `${man.userId}@example.test` },
  });
  const incoming = await api('GET', '/partner/requests/incoming', { token: man.token });
  const invitation = (incoming.body.invitations ?? incoming.body)[0];
  const invitationId = invitation.invitationId ?? invitation._id ?? invitation.id;

  const hijack = await api('POST', `/partner/requests/${invitationId}/respond`, {
    token: stranger.token,
    body: { action: 'accept' },
  });
  assert.ok(hijack.status >= 400, 'only the recipient may accept');

  const strangerConnections = await api('GET', '/partner/connections', { token: stranger.token });
  const list = strangerConnections.body.connections ?? strangerConnections.body;
  assert.ok(!list.some((c) => c.status === 'active'));
});

test('invite: the recipient is actually emailed, not just given a database row', async () => {
  // The invitation was created and announced only over the realtime channel,
  // so unless the recipient already had the app open nothing ever reached them.
  const { emailService } = await import('../src/services/emailService.js');
  const realSend = emailService.sendPartnerInvite;
  const sent = [];
  emailService.sendPartnerInvite = async (args) => {
    sent.push(args);
    return { success: true, mode: 'captured-by-test' };
  };

  try {
    const woman = await createTestUser({ role: 'woman' });
    const man = await createTestUser({ role: 'man' });

    const result = await api('POST', '/partner/invite', {
      token: woman.token,
      body: { partnerEmail: `${man.userId}@example.test` },
    });

    assert.ok(result.status === 200 || result.status === 201);
    assert.equal(sent.length, 1, 'an invitation must actually be sent somewhere');
    assert.equal(sent[0].to, `${man.userId}@example.test`);
    assert.equal(result.body.emailed, true);
  } finally {
    emailService.sendPartnerInvite = realSend;
  }
});

test('invite: a failed email does not lose the invitation', async () => {
  // It is still visible in the recipient's app, so throwing away a created
  // invitation because the mail server was down would be the worse outcome.
  const { emailService } = await import('../src/services/emailService.js');
  const realSend = emailService.sendPartnerInvite;
  emailService.sendPartnerInvite = async () => {
    throw new Error('SMTP is down');
  };

  try {
    const woman = await createTestUser({ role: 'woman' });
    const man = await createTestUser({ role: 'man' });

    const result = await api('POST', '/partner/invite', {
      token: woman.token,
      body: { partnerEmail: `${man.userId}@example.test` },
    });

    assert.ok(result.status === 200 || result.status === 201, 'the invitation still stands');
    assert.equal(result.body.emailed, false, 'and the sender is told it was not emailed');

    const incoming = await api('GET', '/partner/requests/incoming', { token: man.token });
    assert.ok((incoming.body.invitations ?? incoming.body).length >= 1);
  } finally {
    emailService.sendPartnerInvite = realSend;
  }
});

test('invite: an invite link can be claimed and connects the pair', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });

  const link = await api('POST', '/partner/invite/link', { token: woman.token, body: {} });
  assert.ok(link.status === 200 || link.status === 201, `link creation failed: ${link.status}`);

  const code = link.body.code ?? link.body.inviteCode ?? link.body.invite?.code;
  assert.ok(code, 'a link invite needs a code to share');

  const claimed = await api('POST', '/partner/invite/claim', {
    token: man.token,
    body: { code },
  });
  assert.ok(claimed.status === 200 || claimed.status === 201, `claim failed: ${claimed.status}`);

  const connections = await api('GET', '/partner/connections', { token: man.token });
  const list = connections.body.connections ?? connections.body;
  assert.ok(list.length >= 1, 'claiming a link should create the connection');
});

/* ------------------------------------------------------------------ *
 * Relationship AI (spec sections 10, 22)
 *
 * The tab was a hardcoded sentence with no request behind it. These cover the
 * two things that must hold now that it makes a real call: the connection is
 * checked, and the deterministic safety ruleset is not reachable only through
 * the model.
 * ------------------------------------------------------------------ */

test('relationship AI: an outsider cannot ask about a connection they are not in', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const outsider = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId);

  const result = await api('POST', `/ai/relationship-advice/${connectionId}`, {
    token: outsider.token,
    body: { question: 'How are things going between them?' },
  });

  assert.equal(result.status, 404, 'and it must not confirm the connection exists');
});

test('relationship AI: a question is required', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId);

  const result = await api('POST', `/ai/relationship-advice/${connectionId}`, {
    token: woman.token,
    body: { question: '   ' },
  });

  assert.equal(result.status, 400);
});

test('relationship AI: a disclosure of harm is answered by the ruleset, not the model', async () => {
  // No AI provider is configured in tests, so a reply here can only have come
  // from the deterministic safety path. That is exactly the property worth
  // pinning: an upstream outage must not take crisis guidance down with it.
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId);
  await api('POST', '/api/v1/life-stage/transition', {
    token: woman.token,
    body: { toStage: 'cycle_tracking' },
  });

  const result = await api('POST', `/ai/relationship-advice/${connectionId}`, {
    token: woman.token,
    body: { question: 'I keep thinking about how to kill myself after we argue' },
  });

  assert.equal(result.status, 200);
  assert.equal(result.body.aiGenerated, false, 'crisis guidance must not be model generated');
  assert.ok(result.body.answer.length > 0);
  assert.equal(result.body.safety.triggered, true);
});

test('relationship AI: an ordinary question cannot be answered with no provider', async () => {
  // The counterpart to the test above: an ordinary question takes the
  // generation path, which fails cleanly rather than inventing an answer.
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId);

  const result = await api('POST', `/ai/relationship-advice/${connectionId}`, {
    token: woman.token,
    body: { question: 'How can I plan a nicer evening together this week?' },
  });

  assert.notEqual(result.status, 200);
  assert.notEqual(result.status, 500, 'a missing provider is not a server crash');
});

/* ------------------------------------------------------------------ *
 * Message decoder / suggested empathetic reply (spec sections 10, 26)
 *
 * The decoder reads the partner's mood, sleep and cycle to explain a message
 * and propose a reply. It used to read all three ungated, regardless of what
 * that partner had agreed to share, and printed them back to the other person
 * in `cycleMoodContext`. These pin the gate.
 * ------------------------------------------------------------------ */

/**
 * Seeded through the real repositories rather than raw inserts: the daily mood
 * collection is resolved per role and keys on a Date, so a hand-written
 * document silently fails to be found and the test passes for the wrong reason.
 */
async function seedPartnerSignals(_db, userId) {
  const { dailyMoodRepository } = await import('../src/repositories/dailyMoodRepository.js');
  await dailyMoodRepository.upsertDailyMood({
    userId,
    mood: 'anxious',
    energyLevel: 2,
  });
}

test('decoder: nothing about the partner leaks when nothing is shared', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const db = getDb();
  await seedPartnerSignals(db, woman.userId);
  await db.collection('users_woman').updateOne(
    { user_id: woman.userId },
    { $set: { cycle_start_date: '2026-08-20' } },
  );

  const result = await api('POST', `/partner/connections/${connectionId}/decode-message`, {
    token: man.token,
    body: { messageText: 'fine' },
  });

  assert.equal(result.status, 200);
  const context = String(result.body.cycleMoodContext ?? '');
  assert.equal(context, '', 'no permission means no context at all');
  assert.ok(!context.toLowerCase().includes('anxious'), 'mood must not leak');
  assert.ok(!/phase/i.test(context), 'cycle phase must not leak');
  assert.ok(!/hrs sleep/i.test(context), 'sleep must not leak');
});

test('decoder: a granted permission shows only that signal', async () => {
  // Permissions are per signal: sharing mood is not sharing a cycle.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, { shareMood: true });

  const db = getDb();
  await seedPartnerSignals(db, woman.userId);
  await db.collection('users_woman').updateOne(
    { user_id: woman.userId },
    { $set: { cycle_start_date: '2026-08-20' } },
  );

  const result = await api('POST', `/partner/connections/${connectionId}/decode-message`, {
    token: man.token,
    body: { messageText: 'fine' },
  });

  assert.equal(result.status, 200);
  const context = String(result.body.cycleMoodContext ?? '');
  assert.ok(context.toLowerCase().includes('anxious'), 'the shared mood should appear');
  assert.ok(!/phase/i.test(context), 'the cycle was not shared and must stay out');
  assert.ok(!/hrs sleep/i.test(context), 'sleep was not shared and must stay out');
});

test('decoder: an unshared cycle is absent rather than guessed', async () => {
  // It used to default to "Follicular phase" and state that to the partner as
  // fact, with no cycle data behind it at all.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, { shareMood: true });

  const result = await api('POST', `/partner/connections/${connectionId}/decode-message`, {
    token: man.token,
    body: { messageText: 'tired' },
  });

  assert.equal(result.status, 200);
  assert.ok(
    !/follicular|luteal|menstrual|ovulation/i.test(String(result.body.cycleMoodContext ?? '')),
    'no phase may be named when none is known',
  );
});

test('decoder: it still produces a usable reply with no provider configured', async () => {
  // The deterministic fallback is what makes this feature work during an
  // upstream outage; it must not depend on the model being reachable.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const result = await api('POST', `/partner/connections/${connectionId}/decode-message`, {
    token: man.token,
    body: { messageText: 'I am so exhausted today' },
  });

  assert.equal(result.status, 200);
  assert.ok(result.body.recommendedReply.length > 0, 'a reply must always be offered');
  assert.ok(result.body.decodedMeaning.length > 0);
  assert.ok(result.body.emotionalTone.length > 0);
});

test('decoder: an outsider cannot decode a message in a connection they are not in', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const outsider = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, { shareMood: true });

  const result = await api('POST', `/partner/connections/${connectionId}/decode-message`, {
    token: outsider.token,
    body: { messageText: 'fine' },
  });

  assert.equal(result.status, 404, 'and it must not confirm the connection exists');
});

/* ------------------------------------------------------------------ *
 * Sharing a journal day or a Sia conversation (spec sections 6, 21, 26)
 *
 * `journal.entry` and `sia.conversation` were in the permission matrix from the
 * start, but nothing ever served them: turning either category on delivered
 * nothing. They now work, and sharing is per item -- the category says a
 * partner may receive these at all, the item flag says which ones.
 * ------------------------------------------------------------------ */

async function writeJournalDay(user, entryDate, title) {
  return api('PUT', '/api/auth/me/journal', {
    token: user.token,
    body: {
      entryDate,
      summary: title,
      entries: [{ id: `e_${entryDate}`, date: entryDate, title, body: 'Body text.' }],
    },
  });
}

test('journal sharing: the permission alone releases nothing', async () => {
  // The category being on must not hand over every journal she has written.
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, { journal: true });

  await writeJournalDay(woman, '2026-08-20', 'A private day');

  const surface = await api('GET', `/api/v1/partner/connections/${connectionId}/us`, {
    token: partner.token,
  });
  assert.equal(surface.status, 200);

  const section = (surface.body.data?.sections ?? []).find((s) => s.key === 'shared_journal');
  assert.ok(section, 'the section should exist once the category is granted');
  assert.deepEqual(section.items, [], 'nothing is released until a day is marked shared');
});

test('journal sharing: a day marked shared reaches the partner', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, { journal: true });

  await writeJournalDay(woman, '2026-08-21', 'A day I chose to share');

  const shared = await api('PUT', '/api/auth/me/journal/2026-08-21/share', {
    token: woman.token,
    body: { shared: true },
  });
  assert.equal(shared.status, 200);

  const surface = await api('GET', `/api/v1/partner/connections/${connectionId}/us`, {
    token: partner.token,
  });
  const section = (surface.body.data?.sections ?? []).find((s) => s.key === 'shared_journal');
  assert.equal(section.items.length, 1);
  assert.ok(section.items[0].titles.includes('A day I chose to share'));
});

test('journal sharing: a shared day is withheld again when the category is revoked', async () => {
  // Revoking the category has to override the per item flag, not sit beside it.
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, { journal: true });

  await writeJournalDay(woman, '2026-08-22', 'Shared then withdrawn');
  await api('PUT', '/api/auth/me/journal/2026-08-22/share', {
    token: woman.token,
    body: { shared: true },
  });

  await api('PATCH', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
    body: { permissions: { journal: false } },
  });

  const surface = await api('GET', `/api/v1/partner/connections/${connectionId}/us`, {
    token: partner.token,
  });
  const section = (surface.body.data?.sections ?? []).find((s) => s.key === 'shared_journal');
  assert.equal(section.enabled, false);
  assert.deepEqual(section.items, []);
});

test('journal sharing: unsharing a day takes it back', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, { journal: true });

  await writeJournalDay(woman, '2026-08-23', 'Second thoughts');
  await api('PUT', '/api/auth/me/journal/2026-08-23/share', {
    token: woman.token,
    body: { shared: true },
  });
  await api('PUT', '/api/auth/me/journal/2026-08-23/share', {
    token: woman.token,
    body: { shared: false },
  });

  const surface = await api('GET', `/api/v1/partner/connections/${connectionId}/us`, {
    token: partner.token,
  });
  const section = (surface.body.data?.sections ?? []).find((s) => s.key === 'shared_journal');
  assert.deepEqual(section.items, [], 'taking a day back must remove it immediately');
});

test('journal sharing: only the author can share their own journal', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const outsider = await createTestUser({ role: 'woman' });

  await writeJournalDay(woman, '2026-08-24', 'Not yours to share');

  const result = await api('PUT', '/api/auth/me/journal/2026-08-24/share', {
    token: outsider.token,
    body: { shared: true },
  });
  // The route is scoped to the caller's own journal, so an outsider simply has
  // no entry for that date rather than reaching hers.
  assert.equal(result.status, 404);
});

test('journal sharing: the shared flag comes back on read', async () => {
  // The app hydrates its per day control from this. Without the flag on read,
  // every day would show as unshared again after a restart.
  const user = await createTestUser({ role: 'woman' });
  await writeJournalDay(user, '2026-08-25', 'Marked shared');
  await api('PUT', '/api/auth/me/journal/2026-08-25/share', {
    token: user.token,
    body: { shared: true },
  });

  const fetched = await api('GET', '/api/auth/me/journal', { token: user.token });
  const day = fetched.body.journals.find((j) => j.entryDate === '2026-08-25');
  assert.equal(day.sharedWithPartner, true);

  const other = await writeJournalDay(user, '2026-08-26', 'Never shared');
  assert.equal(other.status, 200);
  const fetchedAgain = await api('GET', '/api/auth/me/journal', { token: user.token });
  const unshared = fetchedAgain.body.journals.find((j) => j.entryDate === '2026-08-26');
  assert.equal(unshared.sharedWithPartner, false, 'unshared days must read as false, not undefined');
});

test('sia sharing: the history carries the id and shared flag the app needs', async () => {
  // The app could not offer sharing at all before this: its history client
  // flattened each record to sender and text, dropping the id, so there was
  // nothing to identify an exchange by.
  const user = await createTestUser({ role: 'woman' });
  const { aiHistoryRepository } = await import('../src/repositories/aiHistoryRepository.js');
  await aiHistoryRepository.appendConversation({
    userKey: `user:${user.userId}`,
    role: 'woman',
    userMessage: 'Can we talk about the appointment?',
    assistantMessage: 'Of course.',
    model: 'test',
  });

  let history = await api('GET', '/ai/history', { token: user.token });
  const record = history.body.history[0];
  assert.ok(record.id, 'an exchange needs an id to be shareable');
  assert.equal(record.sharedWithPartner, false, 'unshared must read false, not undefined');

  await api('PUT', `/api/auth/me/sia-conversations/${record.id}/share`, {
    token: user.token,
    body: { shared: true },
  });

  history = await api('GET', '/ai/history', { token: user.token });
  assert.equal(history.body.history[0].sharedWithPartner, true,
    'the flag has to survive a read or the control resets on every launch');
});

test('sia sharing: one account cannot share another account conversation', async () => {
  const owner = await createTestUser({ role: 'woman' });
  const outsider = await createTestUser({ role: 'woman' });

  const { aiHistoryRepository } = await import('../src/repositories/aiHistoryRepository.js');
  await aiHistoryRepository.appendConversation({
    userKey: `user:${owner.userId}`,
    role: 'woman',
    userMessage: 'Something private.',
    assistantMessage: 'I hear you.',
    model: 'test',
  });

  const history = await api('GET', '/ai/history', { token: owner.token });
  const conversationId = history.body.history[0].id;

  const stolen = await api('PUT', `/api/auth/me/sia-conversations/${conversationId}/share`, {
    token: outsider.token,
    body: { shared: true },
  });
  assert.equal(stolen.status, 404, 'sharing is scoped to the caller own conversations');
});

test('sia sharing: a conversation reaches the partner only when both are on', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, { sia_conversations: true });

  const { aiHistoryRepository } = await import('../src/repositories/aiHistoryRepository.js');
  await aiHistoryRepository.appendConversation({
    userKey: `user:${woman.userId}`,
    role: 'woman',
    userMessage: 'I have been feeling anxious about the scan.',
    assistantMessage: 'That sounds really unsettling.',
    model: 'test',
  });

  // Granted category, nothing marked shared.
  let surface = await api('GET', `/api/v1/partner/connections/${connectionId}/us`, {
    token: partner.token,
  });
  let section = (surface.body.data?.sections ?? []).find((s) => s.key === 'shared_sia_conversations');
  assert.deepEqual(section.items, [], 'Sia is where people say what they tell nobody else');

  const history = await api('GET', '/ai/history', { token: woman.token });
  const conversationId = (history.body.history ?? history.body.data ?? history.body)[0]?.id;
  assert.ok(conversationId, 'the conversation needs an id to be shared');

  const shared = await api('PUT', `/api/auth/me/sia-conversations/${conversationId}/share`, {
    token: woman.token,
    body: { shared: true },
  });
  assert.equal(shared.status, 200);

  surface = await api('GET', `/api/v1/partner/connections/${connectionId}/us`, {
    token: partner.token,
  });
  section = (surface.body.data?.sections ?? []).find((s) => s.key === 'shared_sia_conversations');
  assert.equal(section.items.length, 1);
  assert.ok(section.items[0].userMessage.includes('anxious'));
});

test('sia sharing: without the category a shared conversation still does not go', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, {});

  const { aiHistoryRepository } = await import('../src/repositories/aiHistoryRepository.js');
  await aiHistoryRepository.appendConversation({
    userKey: `user:${woman.userId}`,
    role: 'woman',
    userMessage: 'Something I would only tell Sia.',
    assistantMessage: 'Thank you for telling me.',
    model: 'test',
  });

  const history = await api('GET', '/ai/history', { token: woman.token });
  const conversationId = (history.body.history ?? history.body.data ?? history.body)[0]?.id;
  await api('PUT', `/api/auth/me/sia-conversations/${conversationId}/share`, {
    token: woman.token,
    body: { shared: true },
  });

  const surface = await api('GET', `/api/v1/partner/connections/${connectionId}/us`, {
    token: partner.token,
  });
  const section = (surface.body.data?.sections ?? []).find((s) => s.key === 'shared_sia_conversations');
  assert.equal(section.enabled, false, 'both gates must be open, not either');
  assert.deepEqual(section.items, []);
});

/* ------------------------------------------------------------------ *
 * AI reflections from Sia conversations (spec section 12)
 *
 * A reflection could only ever be produced by the nightly job, so a
 * conversation held today appeared nowhere in the AI Reflections tab -- while
 * the tab said letters arrive once you have talked with Sia.
 * ------------------------------------------------------------------ */

async function haveConversation(user, userMessage) {
  const { aiHistoryRepository } = await import('../src/repositories/aiHistoryRepository.js');
  await aiHistoryRepository.appendConversation({
    userKey: `user:${user.userId}`,
    role: 'woman',
    userMessage,
    assistantMessage: 'That makes sense.',
    model: 'test',
  });
}

test('reflections: a conversation today can be reflected on today', async () => {
  const user = await createTestUser({ role: 'woman' });

  const before = await api('GET', '/ai/daily-summaries', { token: user.token });
  assert.equal(before.status, 200);
  assert.deepEqual(before.body.summaries, [], 'nothing before anything was said');

  await haveConversation(user, 'My sleep has been broken all week.');

  const generated = await api('POST', '/ai/daily-summaries/generate', { token: user.token });
  assert.equal(generated.status, 200);
  assert.equal(generated.body.generated, true);

  const after = await api('GET', '/ai/daily-summaries', { token: user.token });
  assert.equal(after.body.summaries.length, 1);
  assert.ok(after.body.summaries[0].summaryText.length > 0);
  assert.equal(after.body.summaries[0].messageCount, 1);
});

test('reflections: writing one does not delete the conversation', async () => {
  // The nightly job clears history after summarising, because it rolls the day
  // over. Doing that here would delete the conversation the user is still
  // having.
  const user = await createTestUser({ role: 'woman' });
  await haveConversation(user, 'I wanted to talk about the appointment.');

  await api('POST', '/ai/daily-summaries/generate', { token: user.token });

  const history = await api('GET', '/ai/history', { token: user.token });
  assert.equal(history.body.history.length, 1, 'the conversation must survive');
  assert.ok(history.body.history[0].userMessage.includes('appointment'));
});

test('reflections: asking twice in a day updates rather than duplicates', async () => {
  const user = await createTestUser({ role: 'woman' });
  await haveConversation(user, 'First thing on my mind.');
  await api('POST', '/ai/daily-summaries/generate', { token: user.token });

  await haveConversation(user, 'And something else about my cycle.');
  await api('POST', '/ai/daily-summaries/generate', { token: user.token });

  const after = await api('GET', '/ai/daily-summaries', { token: user.token });
  assert.equal(after.body.summaries.length, 1, 'one reflection per day, not one per request');
  assert.equal(after.body.summaries[0].messageCount, 2, 'and it covers the whole day so far');
});

test('reflections: nothing to reflect on is reported, not invented', async () => {
  // The tab used to fill this gap with a letter quoting a conversation that
  // never happened.
  const user = await createTestUser({ role: 'woman' });

  const generated = await api('POST', '/ai/daily-summaries/generate', { token: user.token });
  assert.equal(generated.status, 200);
  assert.equal(generated.body.generated, false);
  assert.equal(generated.body.summary, null);

  const after = await api('GET', '/ai/daily-summaries', { token: user.token });
  assert.deepEqual(after.body.summaries, []);
});

test('reflections: one account never sees another account reflections', async () => {
  const mine = await createTestUser({ role: 'woman' });
  const theirs = await createTestUser({ role: 'woman' });

  await haveConversation(theirs, 'Something I only told Sia.');
  await api('POST', '/ai/daily-summaries/generate', { token: theirs.token });

  const after = await api('GET', '/ai/daily-summaries', { token: mine.token });
  assert.deepEqual(after.body.summaries, [], 'a reflection is as private as the chat behind it');
});

test('reflections: generating works with no AI provider configured', async () => {
  // The summary is keyword based on purpose, so reflections do not disappear
  // during an upstream outage.
  const user = await createTestUser({ role: 'woman' });
  await haveConversation(user, 'I have been stressed about sleep and my cycle.');

  const generated = await api('POST', '/ai/daily-summaries/generate', { token: user.token });
  assert.equal(generated.status, 200);
  assert.equal(generated.body.generated, true);
  assert.ok(generated.body.summary.summaryText.length > 0);
});

/* ------------------------------------------------------------------ *
 * Journal reflections (spec sections 6, 14)
 *
 * This endpoint was a fixed lookup table keyed only on life stage. It read no
 * journal at all, yet the app showed it as "AI Reflection" -- and it asserted
 * hormone levels, which spec 14 forbids without validated lab or device data.
 * ------------------------------------------------------------------ */

async function writeJournal(user, entryDate, title, body) {
  return api('PUT', '/api/auth/me/journal', {
    token: user.token,
    body: {
      entryDate,
      summary: title,
      entries: [{ id: `j_${entryDate}`, date: entryDate, title, body }],
    },
  });
}

test('journal reflection: nothing written means no reflection, not a composed one', async () => {
  const user = await createTestUser({ role: 'woman' });

  const result = await api('GET', '/ai/memory-summary', { token: user.token });

  assert.equal(result.status, 200);
  assert.equal(result.body.hasJournal, false);
  assert.equal(result.body.reflection, null, 'an empty journal has nothing to reflect on');
});

test('journal reflection: it is drawn from what was actually written', async () => {
  const user = await createTestUser({ role: 'woman' });
  await writeJournal(
    user,
    '2026-08-27',
    'A long walk',
    'I walked after dinner and slept much better than the night before.',
  );

  const result = await api('GET', '/ai/memory-summary', { token: user.token });

  assert.equal(result.body.hasJournal, true);
  assert.ok(result.body.reflection.length > 0);
  assert.equal(result.body.entryCount, 1);
  assert.ok(result.body.wordCount > 0);
  // Themes come from the user's own words.
  assert.ok(result.body.themes.includes('sleep'));
  assert.ok(result.body.themes.includes('movement'));
});

test('journal reflection: it never asserts a hormonal or physiological state', async () => {
  // The old default told everyone "Estrogen is naturally rising. Your focus and
  // mental clarity are at peak rhythm today.", and the menopause branch claimed
  // "Your reflection logs indicate balanced energy" while reading no logs.
  const user = await createTestUser({ role: 'woman' });
  await writeJournal(user, '2026-08-28', 'Quiet day', 'Not much happened. I read a book.');

  const result = await api('GET', '/ai/memory-summary', { token: user.token });
  const text = String(result.body.reflection ?? '').toLowerCase();

  for (const forbidden of [
    'estrogen',
    'progesterone',
    'testosterone',
    'hormone',
    'vasomotor',
    'autonomic',
    'peak rhythm',
  ]) {
    assert.ok(!text.includes(forbidden), `a reflection must not claim "${forbidden}"`);
  }
});

test('journal reflection: it does not depend on life stage', async () => {
  // The whole previous implementation branched on life stage and nothing else,
  // so two people who had written the same thing got different "reflections".
  const cycling = await createTestUser({ role: 'woman' });
  const pregnant = await createTestUser({ role: 'woman' });

  await api('POST', '/api/v1/life-stage/transition', {
    token: pregnant.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-03-01' } },
  });

  const text = 'I went for a walk and cooked dinner.';
  await writeJournal(cycling, '2026-08-29', 'Same day', text);
  await writeJournal(pregnant, '2026-08-29', 'Same day', text);

  const a = await api('GET', '/ai/memory-summary', { token: cycling.token });
  const b = await api('GET', '/ai/memory-summary', { token: pregnant.token });

  assert.equal(a.body.reflection, b.body.reflection,
    'the same writing should read back the same way');
});

test('journal reflection: it counts every day that was written on', async () => {
  const user = await createTestUser({ role: 'woman' });
  await writeJournal(user, '2026-08-25', 'Monday', 'Work was busy and I felt stressed.');
  await writeJournal(user, '2026-08-26', 'Tuesday', 'Dinner with family, much calmer.');

  const result = await api('GET', '/ai/memory-summary', { token: user.token });

  assert.equal(result.body.dayCount, 2);
  assert.equal(result.body.entryCount, 2);
  assert.ok(result.body.themes.includes('stress'));
  assert.ok(result.body.themes.includes('family'));
});

test('journal reflection: one account never reflects another account journal', async () => {
  const mine = await createTestUser({ role: 'woman' });
  const theirs = await createTestUser({ role: 'woman' });

  await writeJournal(theirs, '2026-08-24', 'Theirs', 'Something private I wrote.');

  const result = await api('GET', '/ai/memory-summary', { token: mine.token });
  assert.equal(result.body.hasJournal, false);
});

test('journal reflection: it works with no AI provider configured', async () => {
  // Deterministic on purpose: a reflection on someone's own writing should not
  // vanish because a model was unreachable.
  const user = await createTestUser({ role: 'woman' });
  await writeJournal(user, '2026-08-23', 'Steady', 'A slow morning and a long walk.');

  const result = await api('GET', '/ai/memory-summary', { token: user.token });
  assert.equal(result.status, 200);
  assert.equal(result.body.hasJournal, true);
  assert.ok(result.body.reflection.length > 0);
});

/* ------------------------------------------------------------------ *
 * Permission keys: v2 names, not the legacy flags
 *
 * The matrix is v2 (`mood`, `sleep`, `cycle_insights`). Several handlers read
 * the older `shareMood` / `shareCycle` / `allowAiSuggestions*` flags directly,
 * so on a connection saved with v2 keys every read was undefined and the
 * feature behaved as if nothing had been shared. The existing tests all used
 * legacy keys, so none of them caught it.
 * ------------------------------------------------------------------ */

test('permissions: the decoder reads context from v2 permission keys', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  // v2 key, which is what the sharing panel writes today.
  const connectionId = await connectPartners(woman.userId, man.userId, { mood: true });

  const { dailyMoodRepository } = await import('../src/repositories/dailyMoodRepository.js');
  await dailyMoodRepository.upsertDailyMood({
    userId: woman.userId,
    mood: 'anxious',
    energyLevel: 2,
  });

  const result = await api('POST', `/partner/connections/${connectionId}/decode-message`, {
    token: man.token,
    body: { messageText: 'fine' },
  });

  assert.equal(result.status, 200);
  assert.ok(
    String(result.body.cycleMoodContext ?? '').toLowerCase().includes('anxious'),
    'a v2 mood permission must actually deliver the mood',
  );
});

test('permissions: the decoder still honours the legacy flags', async () => {
  // Existing connections were saved with the old names and must keep working.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, { shareMood: true });

  const { dailyMoodRepository } = await import('../src/repositories/dailyMoodRepository.js');
  await dailyMoodRepository.upsertDailyMood({
    userId: woman.userId,
    mood: 'tired',
    energyLevel: 2,
  });

  const result = await api('POST', `/partner/connections/${connectionId}/decode-message`, {
    token: man.token,
    body: { messageText: 'fine' },
  });

  assert.ok(String(result.body.cycleMoodContext ?? '').toLowerCase().includes('tired'));
});

test('permissions: a v2 key still withholds what it does not cover', async () => {
  // Normalising must not become a blanket unlock: mood is not cycle.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, { mood: true });

  const db = getDb();
  await db.collection('users_woman').updateOne(
    { user_id: woman.userId },
    { $set: { cycle_start_date: '2026-08-20' } },
  );

  const result = await api('POST', `/partner/connections/${connectionId}/decode-message`, {
    token: man.token,
    body: { messageText: 'fine' },
  });

  assert.ok(
    !/phase/i.test(String(result.body.cycleMoodContext ?? '')),
    'a cycle that was not shared must stay out',
  );
});

test('permissions: relationship advice reports using partner data on a v2 connection', async () => {
  // The screen said "Your partner has not shared data Sia could use here" even
  // when they had, because aiAllowed was read from a legacy flag.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {
    general_ai_insights: true,
    mood: true,
  });

  const { dailyMoodRepository } = await import('../src/repositories/dailyMoodRepository.js');
  await dailyMoodRepository.upsertDailyMood({
    userId: woman.userId,
    mood: 'low',
    energyLevel: 2,
  });

  const result = await api('POST', `/ai/relationship-advice/${connectionId}`, {
    token: woman.token,
    body: { question: 'How can I plan a nicer evening together?' },
  });

  // No AI provider in tests, so generation fails -- but the permission read
  // happens before that, and it is the part under test here.
  assert.notEqual(result.status, 500, 'a missing provider is not a crash');

  const { normalizePermissions, hasGrant } = await import('../src/domain/partnerPermissions.js');
  const { partnerRepository } = await import('../src/repositories/partnerRepository.js');
  const connection = await partnerRepository.getConnectionForUser(connectionId, woman.userId);
  const permissions = normalizePermissions(connection.permissions);

  assert.equal(hasGrant(permissions, 'insight.general'), true, 'AI use must read as allowed');
  assert.equal(hasGrant(permissions, 'log.mood'), true, 'the mood must read as shared');
  assert.equal(hasGrant(permissions, 'cycle.phase'), false, 'and the cycle must not');
});

/* ------------------------------------------------------------------ *
 * Who owns the permissions on a connection (spec section 10)
 *
 * Invitations store only two user ids, no roles. Every call site passed
 * `invitation.senderRole`, which was always undefined, so resolvePermissionOwner
 * fell through to "the sender". When a man invited a woman he became the owner
 * of her sharing panel: she got 403 reading or changing it, could never share
 * anything, and every partner feature correctly reported that nothing had been
 * shared. It looked like the features were broken; the permissions were.
 * ------------------------------------------------------------------ */

test('permission owner: a man inviting a woman leaves her owning the permissions', async () => {
  const man = await createTestUser({ role: 'man' });
  const woman = await createTestUser({ role: 'woman' });

  await api('POST', '/partner/invite', {
    token: man.token,
    body: { partnerEmail: `${woman.userId}@example.test` },
  });

  const incoming = await api('GET', '/partner/requests/incoming', { token: woman.token });
  const invitation = (incoming.body.invitations ?? incoming.body)[0];
  const invitationId = invitation.invitationId ?? invitation._id ?? invitation.id;

  await api('POST', `/partner/requests/${invitationId}/respond`, {
    token: woman.token,
    body: { action: 'accept' },
  });

  const connections = await api('GET', '/partner/connections', { token: woman.token });
  const connection = (connections.body.connections ?? connections.body)
    .find((c) => c.status === 'active');
  assert.ok(connection, 'the pair should be connected');

  const connectionId = connection.connectionId;

  // The decisive check: she can read and change her own sharing panel.
  const panel = await api('GET', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
  });
  assert.equal(panel.status, 200, 'the person sharing must be able to see what she shares');

  const patched = await api('PATCH', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
    body: { permissions: { mood: true } },
  });
  assert.equal(patched.status, 200, 'and be able to change it');
  assert.equal(patched.body.data.permissions.mood, true);
});

test('permission owner: the partner cannot change what she shares about herself', async () => {
  const man = await createTestUser({ role: 'man' });
  const woman = await createTestUser({ role: 'woman' });

  await api('POST', '/partner/invite', {
    token: man.token,
    body: { partnerEmail: `${woman.userId}@example.test` },
  });
  const incoming = await api('GET', '/partner/requests/incoming', { token: woman.token });
  const invitation = (incoming.body.invitations ?? incoming.body)[0];
  await api('POST', `/partner/requests/${invitation.invitationId ?? invitation.id}/respond`, {
    token: woman.token,
    body: { action: 'accept' },
  });

  const connections = await api('GET', '/partner/connections', { token: woman.token });
  const connectionId = (connections.body.connections ?? connections.body)
    .find((c) => c.status === 'active').connectionId;

  const hijack = await api('PATCH', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: man.token,
    body: { permissions: { mood: true } },
  });
  assert.equal(hijack.status, 403, 'ownership must not simply have moved to the other person');
});

test('permission owner: a woman inviting a man still owns the permissions', async () => {
  // The other direction worked before and must keep working.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });

  await api('POST', '/partner/invite', {
    token: woman.token,
    body: { partnerEmail: `${man.userId}@example.test` },
  });
  const incoming = await api('GET', '/partner/requests/incoming', { token: man.token });
  const invitation = (incoming.body.invitations ?? incoming.body)[0];
  await api('POST', `/partner/requests/${invitation.invitationId ?? invitation.id}/respond`, {
    token: man.token,
    body: { action: 'accept' },
  });

  const connections = await api('GET', '/partner/connections', { token: woman.token });
  const connectionId = (connections.body.connections ?? connections.body)
    .find((c) => c.status === 'active').connectionId;

  const panel = await api('GET', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
  });
  assert.equal(panel.status, 200);
});

test('permission owner: the connection says which side may manage permissions', async () => {
  // The app routes on this flag: the owner gets the sharing panel, the other
  // side gets the read-only view of what they receive. Without it the partner
  // would be sent to a control panel that can only reject them with a 403.
  const man = await createTestUser({ role: 'man' });
  const woman = await createTestUser({ role: 'woman' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const hers = await api('GET', '/partner/connections', { token: woman.token });
  const his = await api('GET', '/partner/connections', { token: man.token });

  const herRow = (hers.body.connections ?? hers.body).find((c) => c.connectionId === connectionId);
  const hisRow = (his.body.connections ?? his.body).find((c) => c.connectionId === connectionId);

  assert.equal(herRow.canManagePermissions, true, 'the person sharing manages it');
  assert.equal(hisRow.canManagePermissions, false, 'the partner does not');
});

/* ------------------------------------------------------------------ *
 * Asking to be shown something (spec section 10)
 *
 * A partner can ask for a permission that is off, and the owner is notified in
 * app. The rule the whole feature rests on: asking changes nothing.
 * ------------------------------------------------------------------ */

const REQ = (connectionId) => `/api/v1/partner/connections/${connectionId}/sharing/requests`;

test('permission request: asking does not share anything by itself', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const asked = await api('POST', REQ(connectionId), {
    token: man.token,
    body: { permissionKey: 'mood' },
  });
  assert.equal(asked.status, 201);

  // The decisive check: the permission is still off.
  const panel = await api('GET', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
  });
  const mood = panel.body.data.permissions.find((p) => p.key === 'mood');
  assert.equal(mood.enabled, false, 'a request must never grant itself');
});

test('permission request: the owner is notified in app', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  await api('POST', REQ(connectionId), {
    token: man.token,
    body: { permissionKey: 'cycle_insights' },
  });

  const notifications = await api('GET', '/api/v1/notifications', { token: woman.token });
  const notice = (notifications.body.data ?? []).find(
    (n) => n.category === 'partner_permission_request',
  );
  assert.ok(notice, 'the person being asked has to actually hear about it');
  assert.ok(notice.body.includes('Cycle insights'), 'and be told what was asked for');
});

test('permission request: approving is what shares it', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const asked = await api('POST', REQ(connectionId), {
    token: man.token,
    body: { permissionKey: 'mood' },
  });
  const requestId = asked.body.data.request.requestId;

  const answered = await api('POST', `/api/v1/partner/sharing/requests/${requestId}/respond`, {
    token: woman.token,
    body: { approve: true },
  });
  assert.equal(answered.status, 200);
  assert.equal(answered.body.data.status, 'approved');

  const panel = await api('GET', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
  });
  const mood = panel.body.data.permissions.find((p) => p.key === 'mood');
  assert.equal(mood.enabled, true, 'approval is the only thing that turns it on');
});

test('permission request: declining leaves it off and closes the request', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const asked = await api('POST', REQ(connectionId), {
    token: man.token,
    body: { permissionKey: 'sleep' },
  });
  const requestId = asked.body.data.request.requestId;

  const answered = await api('POST', `/api/v1/partner/sharing/requests/${requestId}/respond`, {
    token: woman.token,
    body: { approve: false },
  });
  assert.equal(answered.body.data.status, 'declined');

  const panel = await api('GET', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
  });
  assert.equal(panel.body.data.permissions.find((p) => p.key === 'sleep').enabled, false);
});

test('permission request: the partner cannot answer their own request', async () => {
  // Otherwise the whole feature is just a way to grant yourself access.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const asked = await api('POST', REQ(connectionId), {
    token: man.token,
    body: { permissionKey: 'mood' },
  });
  const requestId = asked.body.data.request.requestId;

  const selfApprove = await api('POST', `/api/v1/partner/sharing/requests/${requestId}/respond`, {
    token: man.token,
    body: { approve: true },
  });
  assert.equal(selfApprove.status, 403);

  const panel = await api('GET', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
  });
  assert.equal(panel.body.data.permissions.find((p) => p.key === 'mood').enabled, false);
});

test('permission request: asking twice does not stack up notices', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  await api('POST', REQ(connectionId), { token: man.token, body: { permissionKey: 'mood' } });
  const again = await api('POST', REQ(connectionId), {
    token: man.token,
    body: { permissionKey: 'mood' },
  });

  assert.equal(again.status, 200);
  assert.equal(again.body.data.alreadyPending, true, 'the caller should know nothing new was sent');

  const listed = await api('GET', REQ(connectionId), { token: woman.token });
  const pending = listed.body.data.filter((r) => r.status === 'pending' && r.permissionKey === 'mood');
  assert.equal(pending.length, 1, 'one live request per permission');
});

test('permission request: you cannot ask for something already shared', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, { mood: true });

  const asked = await api('POST', REQ(connectionId), {
    token: man.token,
    body: { permissionKey: 'mood' },
  });
  assert.equal(asked.status, 400);
});

test('permission request: the owner cannot request from themselves', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const asked = await api('POST', REQ(connectionId), {
    token: woman.token,
    body: { permissionKey: 'mood' },
  });
  assert.equal(asked.status, 403, 'she changes her own settings directly');
});

test('permission request: an outsider cannot ask on someone else connection', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const outsider = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const asked = await api('POST', REQ(connectionId), {
    token: outsider.token,
    body: { permissionKey: 'mood' },
  });
  assert.ok(asked.status === 404 || asked.status === 403);
});

test('permission request: an unknown or always-on permission is refused', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const unknown = await api('POST', REQ(connectionId), {
    token: man.token,
    body: { permissionKey: 'not_a_permission' },
  });
  assert.equal(unknown.status, 400);

  const alwaysOn = await api('POST', REQ(connectionId), {
    token: man.token,
    body: { permissionKey: 'care_requests' },
  });
  assert.equal(alwaysOn.status, 400, 'asking for something already always on is meaningless');
});

test('permission request: the partner can withdraw what they asked for', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const asked = await api('POST', REQ(connectionId), {
    token: man.token,
    body: { permissionKey: 'mood' },
  });
  const requestId = asked.body.data.request.requestId;

  const withdrawn = await api('POST', `/api/v1/partner/sharing/requests/${requestId}/withdraw`, {
    token: man.token,
  });
  assert.equal(withdrawn.body.data.status, 'withdrawn');

  // And the owner can no longer answer a request that was taken back.
  const answered = await api('POST', `/api/v1/partner/sharing/requests/${requestId}/respond`, {
    token: woman.token,
    body: { approve: true },
  });
  assert.equal(answered.status, 400);
});

test('permission request: a request cannot be answered twice', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const asked = await api('POST', REQ(connectionId), {
    token: man.token,
    body: { permissionKey: 'mood' },
  });
  const requestId = asked.body.data.request.requestId;

  await api('POST', `/api/v1/partner/sharing/requests/${requestId}/respond`, {
    token: woman.token,
    body: { approve: false },
  });
  const second = await api('POST', `/api/v1/partner/sharing/requests/${requestId}/respond`, {
    token: woman.token,
    body: { approve: true },
  });

  assert.equal(second.status, 400, 'a declined request must not be flipped by a second tap');
  const panel = await api('GET', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
  });
  assert.equal(panel.body.data.permissions.find((p) => p.key === 'mood').enabled, false);
});

/* ------------------------------------------------------------------ *
 * Time capsules (spec section 12)
 *
 * These lived in device storage only: "Deliver in 6 Months" delivered nothing,
 * a reinstall lost every capsule, and the list seeded two invented ones when
 * empty. Sealing is the whole feature, so it is enforced on the server.
 * ------------------------------------------------------------------ */

function inDays(days) {
  return new Date(Date.now() + days * 86400000).toISOString();
}

test('capsules: a sealed body never leaves the server', async () => {
  // Withholding it client-side would make the seal a matter of trusting the
  // app rather than a property of the data.
  const user = await createTestUser();

  const created = await api('POST', '/api/v1/capsules', {
    token: user.token,
    body: { title: 'Letter to future me', body: 'The secret text.', deliverAt: inDays(30) },
  });
  assert.equal(created.status, 201);
  assert.equal(created.body.data.sealed, true);
  assert.equal(created.body.data.body, null);

  const listed = await api('GET', '/api/v1/capsules', { token: user.token });
  const capsule = listed.body.data[0];
  assert.equal(capsule.sealed, true);
  assert.equal(capsule.body, null, 'the text must not be sent down and merely hidden');
  assert.ok(!JSON.stringify(listed.body).includes('The secret text.'));
});

test('capsules: one cannot be opened before its date', async () => {
  const user = await createTestUser();
  const created = await api('POST', '/api/v1/capsules', {
    token: user.token,
    body: { title: 'Not yet', body: 'Later.', deliverAt: inDays(30) },
  });

  const opened = await api('POST', `/api/v1/capsules/${created.body.data.capsuleId}/open`, {
    token: user.token,
  });
  assert.equal(opened.status, 403, 'a seal that can be picked is not a seal');
});

test('capsules: a due capsule opens and reads back', async () => {
  const user = await createTestUser();
  const created = await api('POST', '/api/v1/capsules', {
    token: user.token,
    body: { title: 'Ready now', body: 'You made it.', deliverAt: inDays(-1) },
  });

  assert.equal(created.body.data.sealed, false);

  const opened = await api('POST', `/api/v1/capsules/${created.body.data.capsuleId}/open`, {
    token: user.token,
  });
  assert.equal(opened.status, 200);
  assert.equal(opened.body.data.body, 'You made it.');
  assert.ok(opened.body.data.openedAt, 'opening is recorded');
});

test('capsules: a capsule with no date is open immediately', async () => {
  const user = await createTestUser();
  const created = await api('POST', '/api/v1/capsules', {
    token: user.token,
    body: { title: 'Just a note', body: 'No seal on this one.' },
  });

  assert.equal(created.body.data.sealed, false);
  const listed = await api('GET', '/api/v1/capsules', { token: user.token });
  assert.equal(listed.body.data[0].body, 'No seal on this one.');
});

test('capsules: one account never sees another account capsules', async () => {
  const mine = await createTestUser();
  const theirs = await createTestUser();

  const created = await api('POST', '/api/v1/capsules', {
    token: theirs.token,
    body: { title: 'Private', body: 'Not yours.' },
  });

  const listed = await api('GET', '/api/v1/capsules', { token: mine.token });
  assert.deepEqual(listed.body.data, []);

  const stolen = await api('GET', `/api/v1/capsules/${created.body.data.capsuleId}`, {
    token: mine.token,
  });
  assert.equal(stolen.status, 404);
});

test('capsules: an empty list is empty, not seeded with invented capsules', async () => {
  // The old list filled itself with "Letter to Future Me" and "Birthday note
  // to Daughter" -- the second inventing a child.
  const user = await createTestUser();

  const listed = await api('GET', '/api/v1/capsules', { token: user.token });
  assert.equal(listed.status, 200);
  assert.deepEqual(listed.body.data, []);
  assert.equal(listed.body.state, 'empty');
});

test('capsules: a due capsule is announced exactly once', async () => {
  const { runCapsuleDeliveryOnce } = await import('../src/services/timeCapsuleService.js');
  const user = await createTestUser();

  await api('POST', '/api/v1/capsules', {
    token: user.token,
    body: { title: 'Open me', body: 'Hello from before.', deliverAt: inDays(-1) },
  });

  const first = await runCapsuleDeliveryOnce();
  assert.ok(first.delivered >= 1, 'a due capsule has to actually be announced');

  const notifications = await api('GET', '/api/v1/notifications', { token: user.token });
  const notice = (notifications.body.data ?? []).find((n) => n.entityType === 'time_capsule');
  assert.ok(notice, 'the person who sealed it must hear that it opened');
  assert.ok(notice.body.includes('Open me'));

  // Running again must not announce it a second time.
  const second = await runCapsuleDeliveryOnce();
  const listedAgain = await api('GET', '/api/v1/notifications', { token: user.token });
  const notices = (listedAgain.body.data ?? []).filter((n) => n.entityType === 'time_capsule');
  assert.equal(notices.length, 1, 'a capsule is announced once, not on every tick');
  assert.equal(second.delivered, 0);
});

test('capsules: a capsule with no date is never announced', async () => {
  // Nothing came due; announcing it would be an alert about nothing.
  const { runCapsuleDeliveryOnce } = await import('../src/services/timeCapsuleService.js');
  const user = await createTestUser();

  await api('POST', '/api/v1/capsules', {
    token: user.token,
    body: { title: 'Undated', body: 'No delivery expected.' },
  });

  await runCapsuleDeliveryOnce();
  const notifications = await api('GET', '/api/v1/notifications', { token: user.token });
  const notices = (notifications.body.data ?? []).filter((n) => n.entityType === 'time_capsule');
  assert.equal(notices.length, 0);
});

test('capsules: a title and something to seal are both required', async () => {
  const user = await createTestUser();

  const noTitle = await api('POST', '/api/v1/capsules', {
    token: user.token,
    body: { title: '  ', body: 'text' },
  });
  assert.equal(noTitle.status, 400);

  const noBody = await api('POST', '/api/v1/capsules', {
    token: user.token,
    body: { title: 'Title', body: '   ' },
  });
  assert.equal(noBody.status, 400);

  const badDate = await api('POST', '/api/v1/capsules', {
    token: user.token,
    body: { title: 'Title', body: 'text', deliverAt: 'not-a-date' },
  });
  assert.equal(badDate.status, 400);
});

test('capsules: deleting one removes it', async () => {
  const user = await createTestUser();
  const created = await api('POST', '/api/v1/capsules', {
    token: user.token,
    body: { title: 'Temporary', body: 'Gone soon.' },
  });

  const deleted = await api('DELETE', `/api/v1/capsules/${created.body.data.capsuleId}`, {
    token: user.token,
  });
  assert.equal(deleted.status, 200);

  const listed = await api('GET', '/api/v1/capsules', { token: user.token });
  assert.deepEqual(listed.body.data, []);
});

/* ------------------------------------------------------------------ *
 * The shared garden (spec section 21)
 *
 * It was stored in one phone's local storage under the name
 * `shared_garden_state`, so the partner never saw it and a reinstall reset it.
 * It also started at 3 flowers and 1 tree -- a garden nobody had grown.
 * ------------------------------------------------------------------ */

test('garden: a new couple starts with nothing grown', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const garden = await api('GET', `/api/v1/partner/connections/${connectionId}/garden`, {
    token: woman.token,
  });

  assert.equal(garden.status, 200);
  assert.equal(garden.body.data.flowers, 0, 'a garden you did not grow is not yours');
  assert.equal(garden.body.data.trees, 0);
  assert.equal(garden.body.state, 'empty');
});

test('garden: what one partner grows, the other sees', async () => {
  // The whole point of the feature, and exactly what local storage could not do.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const grown = await api('POST', `/api/v1/partner/connections/${connectionId}/garden/grow`, {
    token: woman.token,
    body: { flowers: 2 },
  });
  assert.equal(grown.status, 200);
  assert.equal(grown.body.data.flowers, 2);

  const hisView = await api('GET', `/api/v1/partner/connections/${connectionId}/garden`, {
    token: man.token,
  });
  assert.equal(hisView.body.data.flowers, 2, 'both are tending the same garden');
});

test('garden: growth from both sides accumulates', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  await api('POST', `/api/v1/partner/connections/${connectionId}/garden/grow`, {
    token: woman.token,
    body: { flowers: 2, trees: 1 },
  });
  await api('POST', `/api/v1/partner/connections/${connectionId}/garden/grow`, {
    token: man.token,
    body: { flowers: 3, addPond: true },
  });

  const garden = await api('GET', `/api/v1/partner/connections/${connectionId}/garden`, {
    token: woman.token,
  });
  assert.equal(garden.body.data.flowers, 5, 'neither person overwrites the other');
  assert.equal(garden.body.data.trees, 1);
  assert.equal(garden.body.data.hasPond, true);
});

test('garden: it only grows', async () => {
  // Otherwise either person could quietly tear down a shared keepsake.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  await api('POST', `/api/v1/partner/connections/${connectionId}/garden/grow`, {
    token: woman.token,
    body: { flowers: 3 },
  });

  const shrink = await api('POST', `/api/v1/partner/connections/${connectionId}/garden/grow`, {
    token: man.token,
    body: { flowers: -3 },
  });
  assert.equal(shrink.status, 400);

  const garden = await api('GET', `/api/v1/partner/connections/${connectionId}/garden`, {
    token: woman.token,
  });
  assert.equal(garden.body.data.flowers, 3);
});

test('garden: an outsider can neither see nor tend it', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const outsider = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const seen = await api('GET', `/api/v1/partner/connections/${connectionId}/garden`, {
    token: outsider.token,
  });
  assert.equal(seen.status, 404);

  const tended = await api('POST', `/api/v1/partner/connections/${connectionId}/garden/grow`, {
    token: outsider.token,
    body: { flowers: 1 },
  });
  assert.equal(tended.status, 404);
});

test('garden: a no-op or absurd request is refused', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const nothing = await api('POST', `/api/v1/partner/connections/${connectionId}/garden/grow`, {
    token: woman.token,
    body: {},
  });
  assert.equal(nothing.status, 400);

  const absurd = await api('POST', `/api/v1/partner/connections/${connectionId}/garden/grow`, {
    token: woman.token,
    body: { flowers: 9999 },
  });
  assert.equal(absurd.status, 400);
});

/* ------------------------------------------------------------------ *
 * Digital bouquets (spec section 21)
 *
 * These lived in SharedPreferences on one device: a reinstall lost every
 * bouquet, and "Send Digital Flowers" sent nothing -- the button only opened
 * the builder.
 * ------------------------------------------------------------------ */

const DESIGN = {
  creator: 'Aditi',
  flowers: ['rose', 'rose', 'peony'],
  greeneryIndex: 1,
  seed: 42,
  mode: 'color',
  message: 'Thinking of you.',
  wrappingPaper: 'wrap-classic',
  ribbonColorIndex: 2,
};

test('bouquets: one saved on the account comes back on another device', async () => {
  const user = await createTestUser();

  const created = await api('POST', '/api/v1/bouquets', { token: user.token, body: DESIGN });
  assert.equal(created.status, 201);
  assert.equal(created.body.data.flowers.length, 3);

  const listed = await api('GET', '/api/v1/bouquets', { token: user.token });
  assert.equal(listed.body.data.length, 1);
  assert.equal(listed.body.data[0].message, 'Thinking of you.');
  assert.equal(listed.body.data[0].ribbonColorIndex, 2);
});

test('bouquets: a bouquet with no flowers is refused', async () => {
  const user = await createTestUser();
  const created = await api('POST', '/api/v1/bouquets', {
    token: user.token,
    body: { ...DESIGN, flowers: [] },
  });
  assert.equal(created.status, 400);
});

test('bouquets: sending one actually delivers it to the partner', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const created = await api('POST', '/api/v1/bouquets', { token: woman.token, body: DESIGN });
  const bouquetId = created.body.data.bouquetId;

  const sent = await api('POST', `/api/v1/bouquets/${bouquetId}/send`, {
    token: woman.token,
    body: { connectionId },
  });
  assert.equal(sent.status, 201);

  const received = await api('GET', '/api/v1/bouquets?received=true', { token: man.token });
  assert.equal(received.body.data.length, 1, 'flowers that are sent have to arrive somewhere');
  assert.equal(received.body.data[0].message, 'Thinking of you.');
  assert.equal(received.body.data[0].fromUserId, woman.userId);
});

test('bouquets: the recipient is told', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const created = await api('POST', '/api/v1/bouquets', { token: woman.token, body: DESIGN });
  await api('POST', `/api/v1/bouquets/${created.body.data.bouquetId}/send`, {
    token: woman.token,
    body: { connectionId },
  });

  const notifications = await api('GET', '/api/v1/notifications', { token: man.token });
  const notice = (notifications.body.data ?? []).find((n) => n.entityType === 'bouquet');
  assert.ok(notice, 'a gift nobody hears about is not a gift');
});

test('bouquets: a sent bouquet is a copy, not a pointer', async () => {
  // The sender may later delete theirs. What someone was given should not
  // vanish underneath them.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const created = await api('POST', '/api/v1/bouquets', { token: woman.token, body: DESIGN });
  const bouquetId = created.body.data.bouquetId;
  await api('POST', `/api/v1/bouquets/${bouquetId}/send`, {
    token: woman.token,
    body: { connectionId },
  });

  await api('DELETE', `/api/v1/bouquets/${bouquetId}`, { token: woman.token });

  const received = await api('GET', '/api/v1/bouquets?received=true', { token: man.token });
  assert.equal(received.body.data.length, 1, 'the gift survives the giver deleting theirs');
});

test('bouquets: a received one does not appear in your own garden', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const created = await api('POST', '/api/v1/bouquets', { token: woman.token, body: DESIGN });
  await api('POST', `/api/v1/bouquets/${created.body.data.bouquetId}/send`, {
    token: woman.token,
    body: { connectionId },
  });

  const hisOwn = await api('GET', '/api/v1/bouquets', { token: man.token });
  assert.deepEqual(hisOwn.body.data, [], 'given is not the same as made');
});

test('bouquets: one cannot be pushed at an account you are not connected to', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const outsider = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const created = await api('POST', '/api/v1/bouquets', { token: outsider.token, body: DESIGN });

  // The outsider is not in that connection.
  const sent = await api('POST', `/api/v1/bouquets/${created.body.data.bouquetId}/send`, {
    token: outsider.token,
    body: { connectionId },
  });
  assert.equal(sent.status, 404);

  const received = await api('GET', '/api/v1/bouquets?received=true', { token: man.token });
  assert.deepEqual(received.body.data, []);
});

test('bouquets: you cannot send a bouquet you did not make', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const hers = await api('POST', '/api/v1/bouquets', { token: woman.token, body: DESIGN });

  const stolen = await api('POST', `/api/v1/bouquets/${hers.body.data.bouquetId}/send`, {
    token: man.token,
    body: { connectionId },
  });
  assert.equal(stolen.status, 404);
});

test('bouquets: opening one is recorded, and is idempotent', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const created = await api('POST', '/api/v1/bouquets', { token: woman.token, body: DESIGN });
  await api('POST', `/api/v1/bouquets/${created.body.data.bouquetId}/send`, {
    token: woman.token,
    body: { connectionId },
  });

  const received = await api('GET', '/api/v1/bouquets?received=true', { token: man.token });
  const id = received.body.data[0].bouquetId;
  assert.equal(received.body.data[0].openedAt, null);

  const opened = await api('POST', `/api/v1/bouquets/${id}/open`, { token: man.token });
  assert.ok(opened.body.data.openedAt);

  const again = await api('POST', `/api/v1/bouquets/${id}/open`, { token: man.token });
  assert.equal(again.status, 200, 'opening twice is not an error');
  assert.equal(again.body.data.openedAt, opened.body.data.openedAt, 'the first time stands');
});

test('bouquets: one account never sees another account garden', async () => {
  const mine = await createTestUser();
  const theirs = await createTestUser();

  await api('POST', '/api/v1/bouquets', { token: theirs.token, body: DESIGN });

  const listed = await api('GET', '/api/v1/bouquets', { token: mine.token });
  assert.deepEqual(listed.body.data, []);
});

test('bouquets: an oversized arrangement is trimmed rather than stored whole', async () => {
  const user = await createTestUser();
  const created = await api('POST', '/api/v1/bouquets', {
    token: user.token,
    body: { ...DESIGN, flowers: Array(500).fill('rose'), message: 'x'.repeat(2000) },
  });

  assert.equal(created.status, 201);
  assert.ok(created.body.data.flowers.length <= 60, 'one arrangement is not an unbounded payload');
  assert.ok(created.body.data.message.length <= 500);
});

/* ------------------------------------------------------------------ *
 * Guided recovery sessions (spec sections 12, 27)
 *
 * The Recovery tab advertised named sessions with durations -- "Period Pain
 * Relief Meditation • 12 min" -- and both cards were `onTap: () {}`. There was
 * no player and no content behind either of them.
 * ------------------------------------------------------------------ */

test('recovery: sessions are served with the steps that make them playable', async () => {
  const user = await createTestUser();

  const listed = await api('GET', '/api/v1/recovery/sessions', { token: user.token });
  assert.equal(listed.status, 200);
  assert.ok(listed.body.data.length > 0, 'the seeded sessions should be available in tests');

  const session = listed.body.data[0];
  assert.ok(session.steps.length > 0, 'a session with no steps is an empty shell');
  assert.ok(session.totalSeconds > 0);
  assert.equal(typeof session.steps[0].instruction, 'string');
  assert.ok(session.steps[0].seconds > 0);
});

test('recovery: no session claims a therapeutic effect', async () => {
  // The old cards asserted that a meditation relieves period pain and that a
  // breathing exercise treats luteal phase anxiety. Those are clinical claims,
  // and a seed file is not where they get made.
  const user = await createTestUser();
  const listed = await api('GET', '/api/v1/recovery/sessions', { token: user.token });

  const text = JSON.stringify(listed.body.data).toLowerCase();
  for (const claim of ['pain relief', 'relieves', 'treats', 'cures', 'therapy', 'anxiety breathing']) {
    assert.ok(!text.includes(claim), `a seeded session must not claim "${claim}"`);
  }
});

test('recovery: an unapproved session is not served', async () => {
  // The whole point of routing these through the reviewed content pipeline.
  const { seedContentIfMissing, CONTENT_STATES } = await import(
    '../src/repositories/medicalContentRepository.js'
  );
  const user = await createTestUser();

  await seedContentIfMissing([{
    contentId: 'rs_unreviewed_test',
    title: 'Unreviewed session',
    body: JSON.stringify({ steps: [{ instruction: 'Breathe.', seconds: 10 }] }),
    contentType: 'recovery_session',
    audience: 'female_user',
    status: CONTENT_STATES.CLINICAL_REVIEW,
  }], 'test');

  const listed = await api('GET', '/api/v1/recovery/sessions', { token: user.token });
  const ids = listed.body.data.map((s) => s.sessionId);
  assert.ok(!ids.includes('rs_unreviewed_test'), 'content awaiting review must not reach anyone');

  const direct = await api('GET', '/api/v1/recovery/sessions/rs_unreviewed_test', {
    token: user.token,
  });
  assert.equal(direct.status, 404, 'and it must not be reachable by id either');
});

test('recovery: completing one is recorded on the account', async () => {
  const user = await createTestUser();
  const listed = await api('GET', '/api/v1/recovery/sessions', { token: user.token });
  const sessionId = listed.body.data[0].sessionId;

  const done = await api('POST', `/api/v1/recovery/sessions/${sessionId}/complete`, {
    token: user.token,
    body: { secondsListened: 120 },
  });
  assert.equal(done.status, 201);

  const again = await api('GET', '/api/v1/recovery/sessions', { token: user.token });
  const session = again.body.data.find((s) => s.sessionId === sessionId);
  assert.equal(session.timesCompleted, 1, 'a finished session should be counted');
});

test('recovery: a completed session reaches the timeline', async () => {
  // Counted on the account rather than only on the device.
  const user = await createTestUser();
  const listed = await api('GET', '/api/v1/recovery/sessions', { token: user.token });
  const sessionId = listed.body.data[0].sessionId;

  await api('POST', `/api/v1/recovery/sessions/${sessionId}/complete`, {
    token: user.token,
    body: { secondsListened: 60 },
  });

  const events = await api('GET', '/api/v1/events?eventTypes=recovery_session_completed', {
    token: user.token,
  });
  assert.equal(events.status, 200);
  assert.ok(events.body.data.length >= 1);
  assert.equal(events.body.data[0].payload.sessionId, sessionId);
});

test('recovery: completing an unknown session is refused', async () => {
  const user = await createTestUser();
  const done = await api('POST', '/api/v1/recovery/sessions/not_a_session/complete', {
    token: user.token,
    body: {},
  });
  assert.equal(done.status, 404);
});

test('recovery: one account never sees another account completions', async () => {
  const mine = await createTestUser();
  const theirs = await createTestUser();

  const listed = await api('GET', '/api/v1/recovery/sessions', { token: theirs.token });
  const sessionId = listed.body.data[0].sessionId;
  await api('POST', `/api/v1/recovery/sessions/${sessionId}/complete`, {
    token: theirs.token,
    body: {},
  });

  const mineListed = await api('GET', '/api/v1/recovery/sessions', { token: mine.token });
  const session = mineListed.body.data.find((s) => s.sessionId === sessionId);
  assert.equal(session.timesCompleted, 0);
});

/* ------------------------------------------------------------------ *
 * Stage education articles (spec section 27)
 *
 * These were seven hardcoded `learnFeeds` maps inside the dashboard -- 74
 * clinical articles written into the widget tree with no reviewer, no review
 * date and no locale. They pass the same gate as everything else now.
 * ------------------------------------------------------------------ */

test('education: seeded articles are served for a life stage', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-03-01' } },
  });

  const listed = await api('GET', '/api/v1/content?contentType=article&limit=50', {
    token: user.token,
  });

  assert.equal(listed.status, 200);
  const ids = listed.body.data.map((c) => c.contentId);
  assert.ok(
    ids.some((id) => id.startsWith('edu_pregnancy_')),
    'pregnancy education should reach someone in that stage',
  );
});

test('education: a stage only receives its own articles', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-03-01' } },
  });

  const listed = await api('GET', '/api/v1/content?contentType=article&limit=50', {
    token: user.token,
  });
  const ids = listed.body.data.map((c) => c.contentId);

  // Menopause bone health has no business on a pregnancy dashboard.
  assert.ok(!ids.some((id) => id.startsWith('edu_menopause_')));
  assert.ok(!ids.some((id) => id.startsWith('edu_postpartum_')));
});

test('education: every seeded article carries review metadata', async () => {
  // The whole point of moving them: clinical copy with a named reviewer and a
  // review date, rather than a literal in a widget.
  const { STAGE_EDUCATION_SEED } = await import('../src/config/stageEducationSeed.js');

  assert.ok(STAGE_EDUCATION_SEED.length >= 70, 'all the articles should have moved');
  for (const entry of STAGE_EDUCATION_SEED) {
    assert.ok(entry.contentId, 'each article needs an id');
    assert.ok(entry.title && entry.title.length > 0);
    assert.ok(entry.body && entry.body.length > 0);
    assert.equal(entry.contentType, 'article');
    assert.ok(Array.isArray(entry.lifeStages) && entry.lifeStages.length > 0,
      `${entry.contentId} must name the stage it belongs to`);
    assert.ok(Array.isArray(entry.topics) && entry.topics.length > 0);
  }
});

test('education: unapproved articles are not served', async () => {
  const { seedContentIfMissing, CONTENT_STATES } = await import(
    '../src/repositories/medicalContentRepository.js'
  );
  const user = await createTestUser();

  await seedContentIfMissing([{
    contentId: 'edu_unreviewed_test',
    title: 'Unreviewed education',
    body: 'Should not be served.',
    contentType: 'article',
    audience: 'female_user',
    status: CONTENT_STATES.CLINICAL_REVIEW,
  }], 'test');

  const listed = await api('GET', '/api/v1/content?contentType=article&limit=100', {
    token: user.token,
  });
  const ids = listed.body.data.map((c) => c.contentId);
  assert.ok(!ids.includes('edu_unreviewed_test'), 'clinical copy awaiting review must not reach anyone');
});

/* ------------------------------------------------------------------ *
 * Clinical content review (spec section 27)
 *
 * The review API existed from the start and nothing called it, so a reviewer
 * had no route and no button and 74 education articles sat unreviewed. These
 * cover the path the new screen drives.
 * ------------------------------------------------------------------ */

test('review: the queue shows what is waiting', async () => {
  const admin = await createTestUser({ role: 'admin' });

  const queue = await api('GET', '/api/v1/content/admin/review-queue', { token: admin.token });

  assert.equal(queue.status, 200);
  assert.ok(Array.isArray(queue.body.data.awaitingReview));
  assert.ok(Array.isArray(queue.body.data.reviewOverdue));
});

test('review: only an admin can see the queue or change a status', async () => {
  const woman = await createTestUser({ role: 'woman' });

  const queue = await api('GET', '/api/v1/content/admin/review-queue', { token: woman.token });
  assert.ok(queue.status === 403 || queue.status === 401);

  const forced = await api('POST', '/api/v1/content/admin/edu_pregnancy_fetal_lung_surfactant/status', {
    token: woman.token,
    body: { status: 'approved', reviewer: 'Not A Reviewer' },
  });
  assert.ok(forced.status === 403 || forced.status === 401);
});

test('review: approving without a reviewer is refused', async () => {
  // The name is the whole point of the gate: it records who stood behind the
  // text. Approval without one would make the audit trail meaningless.
  const admin = await createTestUser({ role: 'admin' });
  const { seedContentIfMissing, CONTENT_STATES } = await import(
    '../src/repositories/medicalContentRepository.js'
  );

  await seedContentIfMissing([{
    contentId: 'rev_needs_reviewer',
    title: 'Needs a reviewer',
    body: 'Clinical text.',
    contentType: 'article',
    audience: 'female_user',
    source: 'test',
    status: CONTENT_STATES.CLINICAL_REVIEW,
  }], 'test');

  const noName = await api('POST', '/api/v1/content/admin/rev_needs_reviewer/status', {
    token: admin.token,
    body: { status: 'approved' },
  });
  assert.equal(noName.status, 409, 'approval requires a named reviewer');
});

test('review: approving serves the article and records who approved it', async () => {
  const admin = await createTestUser({ role: 'admin' });
  const reader = await createTestUser({ role: 'woman' });
  const { seedContentIfMissing, CONTENT_STATES } = await import(
    '../src/repositories/medicalContentRepository.js'
  );

  await seedContentIfMissing([{
    contentId: 'rev_approve_flow',
    title: 'Reviewable article',
    body: 'Clinical text under review.',
    summary: 'Clinical text under review.',
    contentType: 'article',
    audience: 'female_user',
    source: 'test',
    status: CONTENT_STATES.CLINICAL_REVIEW,
  }], 'test');

  const before = await api('GET', '/api/v1/content?contentType=article&limit=100', {
    token: reader.token,
  });
  assert.ok(!before.body.data.map((c) => c.contentId).includes('rev_approve_flow'));

  const approved = await api('POST', '/api/v1/content/admin/rev_approve_flow/status', {
    token: admin.token,
    body: { status: 'approved', reviewer: 'Dr Test Reviewer, MBBS' },
  });
  assert.equal(approved.status, 200);
  assert.equal(approved.body.data.reviewer, 'Dr Test Reviewer, MBBS');
  assert.ok(approved.body.data.reviewDate, 'the date has to be recorded too');

  const after = await api('GET', '/api/v1/content?contentType=article&limit=100', {
    token: reader.token,
  });
  assert.ok(after.body.data.map((c) => c.contentId).includes('rev_approve_flow'));

  const audit = await api('GET', '/api/v1/content/admin/rev_approve_flow/audit', {
    token: admin.token,
  });
  assert.ok(audit.body.data.length > 0, 'the approval must leave a trail');
});

test('review: sending one back stops it being served', async () => {
  const admin = await createTestUser({ role: 'admin' });
  const reader = await createTestUser({ role: 'woman' });
  const { seedContentIfMissing, CONTENT_STATES } = await import(
    '../src/repositories/medicalContentRepository.js'
  );

  await seedContentIfMissing([{
    contentId: 'rev_send_back',
    title: 'Sent back article',
    body: 'Needs work.',
    contentType: 'article',
    audience: 'female_user',
    source: 'test',
    status: CONTENT_STATES.CLINICAL_REVIEW,
  }], 'test');

  const sentBack = await api('POST', '/api/v1/content/admin/rev_send_back/status', {
    token: admin.token,
    body: { status: 'draft' },
  });
  assert.equal(sentBack.status, 200);

  const listed = await api('GET', '/api/v1/content?contentType=article&limit=100', {
    token: reader.token,
  });
  assert.ok(!listed.body.data.map((c) => c.contentId).includes('rev_send_back'));
});

test('admin role: a normally signed-in user gets their role from the account record', async () => {
  // Login signs {userId, tokenVersion} with no role, so req.user.role was
  // undefined for everyone and requireRole('admin') could never pass. The
  // admin surfaces were unreachable whatever the database said.
  const { signAccessToken } = await import('../src/services/tokenService.js');
  const admin = await createTestUser({ role: 'admin' });

  // A token shaped exactly like the one login issues: no role claim.
  const loginStyleToken = signAccessToken({ userId: admin.userId, tokenVersion: 1 });

  const queue = await api('GET', '/api/v1/content/admin/review-queue', {
    token: loginStyleToken,
  });
  assert.equal(queue.status, 200, 'an admin must reach admin routes after a normal sign in');
});

test('admin role: a token claiming admin cannot promote a non-admin account', async () => {
  // The record is authoritative, so a forged or stale role claim is ignored.
  const { signAccessToken } = await import('../src/services/tokenService.js');
  const woman = await createTestUser({ role: 'woman' });

  const forged = signAccessToken({ userId: woman.userId, tokenVersion: 1, role: 'admin' });

  const queue = await api('GET', '/api/v1/content/admin/review-queue', { token: forged });
  assert.equal(queue.status, 403, 'the account record decides, not the token');
});

test('relationship AI: the person whose data is shared cannot ask it', async () => {
  // Sharing runs one way. Asked from her side it gathered context about him
  // while gating on her own switches -- the wrong direction -- and the partner
  // shell has no Sia and no M Studio, so he logs nothing to gather.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {
    general_ai_insights: true,
    mood: true,
  });

  const asked = await api('POST', `/ai/relationship-advice/${connectionId}`, {
    token: woman.token,
    body: { question: 'How is he doing?' },
  });

  assert.equal(asked.status, 403, 'the owner of the permissions is not the audience for this');

  // But a disclosure of harm is still answered, whoever it came from: the
  // safety evaluation runs before this authorization check.
  const distress = await api('POST', `/ai/relationship-advice/${connectionId}`, {
    token: woman.token,
    body: { question: 'I keep thinking about how to kill myself after we argue' },
  });
  assert.equal(distress.status, 200, 'safety guidance must not be gated behind a role check');
  assert.equal(distress.body.aiGenerated, false);
});

test('relationship AI: the supporting partner can still ask', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {
    general_ai_insights: true,
    mood: true,
  });

  const asked = await api('POST', `/ai/relationship-advice/${connectionId}`, {
    token: man.token,
    body: { question: 'What could I do for her tonight?' },
  });

  // No AI provider in tests, so generation fails -- but not with the 403 that
  // would mean the guard had caught the wrong side.
  assert.notEqual(asked.status, 403, 'the supporting partner is who this is for');
  assert.notEqual(asked.status, 500);
});

test('password reset: a delivery failure does not reveal whether an account exists', async () => {
  // The generic "if an account exists" message is only worth anything if both
  // answers look the same. An unhandled send failure made a real address throw
  // while an unknown one returned the generic message, which answers the exact
  // question that message exists to hide.
  const { emailAuthService } = await import('../src/services/emailAuthService.js');
  const { emailService } = await import('../src/services/emailService.js');
  const db = getDb();

  const email = `reset-${randomUUID().slice(0, 8)}@example.test`;
  await createResettableUser(db, { email });

  const original = emailService.sendVerificationLink;
  emailService.sendVerificationLink = async () => {
    throw new Error('SMTP is down');
  };

  try {
    const real = await emailAuthService.sendPasswordResetCode({ email });
    const unknown = await emailAuthService.sendPasswordResetCode({
      email: `nobody-${randomUUID().slice(0, 8)}@example.test`,
    });

    assert.equal(real.message, unknown.message, 'both answers must read the same');
    assert.ok(!/\d{6}/.test(JSON.stringify(real)), 'and no code is handed back');
  } finally {
    emailService.sendVerificationLink = original;
  }
});

test('signup: the verification code is never returned in the response in production', async () => {
  // With email delivery broken the server fell back to returning the code and
  // the verification token in the API response. That is a development
  // convenience and an account takeover in production: anyone can register an
  // address they do not control, because the server hands them the code.
  const { env } = await import('../src/utils/env.js');

  const previous = env.emailDeliveryFallbackEnabled;
  env.emailDeliveryFallbackEnabled = false;
  try {
    const result = await api('POST', '/api/auth/send-email-verification', {
      body: {
        email: `closed-${randomUUID().slice(0, 8)}@example.test`,
        password: 'a-long-enough-password',
        role: 'woman',
        mode: 'signup',
      },
    });

    const body = JSON.stringify(result.body ?? {});
    assert.ok(!/"code"\s*:\s*"?\d{6}/.test(body), 'a verification code must not be handed back');
    assert.ok(!body.includes('verificationLink'), 'nor the signed verification link');
  } finally {
    env.emailDeliveryFallbackEnabled = previous;
  }
});

test('partner: nothing is shared by default', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId);

  await api('POST', '/api/v1/life-stage/transition', { token: woman.token, body: { toStage: 'cycle_tracking' } });
  await api('POST', '/api/v1/events', { token: woman.token, body: { eventType: 'energy_logged', payload: { level: 2 } } });
  await api('POST', '/api/v1/events', { token: woman.token, body: { eventType: 'mood_logged', payload: { mood: 'low' } } });

  const partnerHome = await api('GET', `/api/v1/partner/connections/${connectionId}/home`, { token: partner.token });
  assert.equal(partnerHome.status, 200);
  assert.equal(partnerHome.body.data.nothingShared, true);
  assert.equal(partnerHome.body.data.permittedContext.energyLevel, undefined);
  assert.equal(partnerHome.body.data.permittedContext.mood, undefined);
  // Partner Home still works with nothing shared (spec §25).
  assert.ok(partnerHome.body.data.greeting.prompt);
});

test('partner: enabling energy shares energy and only energy', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId);

  await api('POST', '/api/v1/life-stage/transition', { token: woman.token, body: { toStage: 'cycle_tracking' } });
  await api('POST', '/api/v1/events', { token: woman.token, body: { eventType: 'energy_logged', payload: { level: 2 } } });
  await api('POST', '/api/v1/events', { token: woman.token, body: { eventType: 'mood_logged', payload: { mood: 'low' } } });

  const update = await api('PATCH', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
    body: { permissions: { energy: true } },
  });
  assert.equal(update.status, 200);
  assert.equal(update.body.data.permissions.energy, true);

  const context = await api('GET', `/api/v1/partner/connections/${connectionId}/context`, { token: partner.token });
  assert.equal(context.body.data.energyLevel.value, 2);
  assert.equal(context.body.data.mood, undefined);
  assert.ok(context.body.permissions.allowedGrants.includes('log.energy'));
  assert.ok(context.body.permissions.restrictedGrants.includes('log.mood'));
});

test('partner: revoking a permission stops the data on the very next request', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, { energy: true });

  await api('POST', '/api/v1/life-stage/transition', { token: woman.token, body: { toStage: 'cycle_tracking' } });
  await api('POST', '/api/v1/events', { token: woman.token, body: { eventType: 'energy_logged', payload: { level: 2 } } });

  const before = await api('GET', `/api/v1/partner/connections/${connectionId}/context`, { token: partner.token });
  assert.ok(before.body.data.energyLevel);

  await api('PATCH', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
    body: { permissions: { energy: false } },
  });

  const after = await api('GET', `/api/v1/partner/connections/${connectionId}/context`, { token: partner.token });
  assert.equal(after.body.data.energyLevel, undefined);

  // The change is auditable (spec §10).
  const audit = await api('GET', `/api/v1/partner/connections/${connectionId}/sharing/history`, { token: woman.token });
  assert.equal(audit.status, 200);
  assert.ok(audit.body.data.length >= 1);
  assert.equal(audit.body.data[0].changes.energy.to, false);
});

test('partner: a partner cannot change what is shared about them', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId);

  const attempt = await api('PATCH', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: partner.token,
    body: { permissions: { journal: true, mood: true } },
  });

  assert.equal(attempt.status, 403);
  assert.equal(attempt.body.errorCode, 'FORBIDDEN');
});

test('partner: an inactive relationship returns nothing', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, { energy: true, mood: true });

  await api('POST', '/api/v1/events', { token: woman.token, body: { eventType: 'energy_logged', payload: { level: 3 } } });
  await getDb().collection('partner_connections').updateOne(
    { connection_id: connectionId },
    { $set: { status: 'ended' } },
  );

  const context = await api('GET', `/api/v1/partner/connections/${connectionId}/context`, { token: partner.token });
  assert.equal(context.body.state, 'restricted');
  assert.equal(context.body.errorCode, 'RELATIONSHIP_INACTIVE');
  assert.equal(context.body.data.relationshipActive, false);
});

test('IDOR: an unrelated user cannot read a connection, and cannot tell it exists', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const outsider = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, { energy: true, mood: true, journal: true });

  for (const path of ['home', 'context', 'us', 'sharing']) {
    const result = await api('GET', `/api/v1/partner/connections/${connectionId}/${path}`, { token: outsider.token });
    assert.equal(result.status, 404, `${path} should be indistinguishable from a missing connection`);
  }

  const fabricated = await api('GET', `/api/v1/partner/connections/${randomUUID()}/context`, { token: outsider.token });
  assert.equal(fabricated.status, 404);
});

test('IDOR: a user cannot read or delete another user event', async () => {
  const owner = await createTestUser();
  const attacker = await createTestUser();

  const created = await api('POST', '/api/v1/events', {
    token: owner.token,
    body: { eventType: 'mood_logged', payload: { mood: 'low' } },
  });
  const eventId = created.body.data.event.eventId;

  assert.equal((await api('GET', `/api/v1/events/${eventId}`, { token: attacker.token })).status, 404);
  assert.equal((await api('DELETE', `/api/v1/events/${eventId}`, { token: attacker.token })).status, 404);
  assert.equal((await api('GET', `/api/v1/events/${eventId}`, { token: owner.token })).status, 200);
});

/* ================================================================== *
 * Support requests (spec §11)
 * ================================================================== */

test('support requests: the partner receives the request and nothing else', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId);

  await api('POST', '/api/v1/events', { token: woman.token, body: { eventType: 'symptom_logged', payload: { symptom: 'cramps', severity: 7 } } });

  const created = await api('POST', `/api/v1/partner/connections/${connectionId}/support-requests`, {
    token: woman.token,
    body: { type: 'rest' },
  });
  assert.equal(created.status, 201);

  const partnerView = await api('GET', `/api/v1/partner/connections/${connectionId}/support-requests`, { token: partner.token });
  assert.equal(partnerView.body.data.length, 1);

  const request = partnerView.body.data[0];
  assert.equal(request.type, 'rest');
  assert.ok(request.message);
  // No medical data travels with the request (spec §11).
  const serialized = JSON.stringify(request);
  assert.ok(!serialized.includes('cramps'));
  assert.equal(request.requesterUserId, undefined);

  const acknowledged = await api('PATCH', `/api/v1/partner/support-requests/${request.requestId}`, {
    token: partner.token,
    body: { state: 'acknowledged' },
  });
  assert.equal(acknowledged.status, 200);

  // The requester cannot acknowledge on the partner's behalf.
  const invalid = await api('PATCH', `/api/v1/partner/support-requests/${request.requestId}`, {
    token: woman.token,
    body: { state: 'completed' },
  });
  assert.equal(invalid.status, 409);
});

test('support requests: a partner cannot raise one on the other person behalf', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId);

  const attempt = await api('POST', `/api/v1/partner/connections/${connectionId}/support-requests`, {
    token: partner.token,
    body: { type: 'rest' },
  });
  assert.equal(attempt.status, 403);
});

/* ================================================================== *
 * Notifications (spec §19, §24)
 * ================================================================== */

test('notifications: a reminder is cancelled when its source event is deleted', async () => {
  const user = await createTestUser();

  const created = await api('POST', '/api/v1/events', {
    token: user.token,
    body: { eventType: 'appointment_logged', payload: { title: 'Scan', date: '2027-01-05' } },
  });
  const eventId = created.body.data.event.eventId;

  const reminder = await api('POST', '/api/v1/notifications/reminders', {
    token: user.token,
    body: {
      category: 'appointment_reminder',
      title: 'Scan tomorrow',
      body: 'Your scan is tomorrow.',
      entityType: 'health_event',
      entityId: eventId,
    },
  });
  assert.equal(reminder.status, 201);
  // Sensitive categories are redacted on the lock screen by default.
  assert.equal(reminder.body.data.lockScreenTitle, 'Blushy');

  await api('DELETE', `/api/v1/events/${eventId}`, { token: user.token });

  const notifications = await api('GET', '/api/v1/notifications', { token: user.token });
  assert.ok(!notifications.body.data.some((n) => n.entityId === eventId));
});

test('notifications: a disabled category suppresses scheduling', async () => {
  const user = await createTestUser();

  await api('PATCH', '/api/v1/notifications/preferences', {
    token: user.token,
    body: { categories: { appointment_reminder: false } },
  });

  const reminder = await api('POST', '/api/v1/notifications/reminders', {
    token: user.token,
    body: { category: 'appointment_reminder', title: 'x', entityType: 'health_event', entityId: 'e1' },
  });

  assert.equal(reminder.body.state, 'restricted');
  assert.equal(reminder.body.errorCode, 'NOTIFICATION_SUPPRESSED');
});

test('notifications: safety notices cannot be switched off', async () => {
  const user = await createTestUser();
  const result = await api('PATCH', '/api/v1/notifications/preferences', {
    token: user.token,
    body: { categories: { safety_escalation: false } },
  });
  assert.equal(result.body.data.categories.safety_escalation, true);
});

/* ================================================================== *
 * Analytics (spec §26)
 * ================================================================== */

test('analytics: only the defined events are accepted and health text is stripped', async () => {
  const user = await createTestUser();

  const rejected = await api('POST', '/api/v1/notifications/analytics/track', {
    token: user.token,
    body: { eventName: 'journal_text_captured', properties: {} },
  });
  assert.equal(rejected.status, 400);

  const accepted = await api('POST', '/api/v1/notifications/analytics/track', {
    token: user.token,
    body: {
      eventName: 'insight_viewed',
      properties: { insightType: 'sleep_mood', journalText: 'my private thoughts', symptom: 'cramps' },
    },
  });
  assert.equal(accepted.status, 202);

  const stored = await getDb().collection('analytics_events').findOne({ user_id: user.userId, event_name: 'insight_viewed' });
  assert.equal(stored.properties.insightType, 'sleep_mood');
  assert.equal(stored.properties.journalText, undefined);
  assert.equal(stored.properties.symptom, undefined);
  // Analytics is keyed on a pseudonymous id (spec §26).
  assert.ok(stored.pseudonymous_id.startsWith('px_'));
});

/* ================================================================== *
 * Content library (spec §13, §17)
 * ================================================================== */

test('content: only approved content is served, and partner content is audience tagged', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });

  const womanLibrary = await api('GET', '/api/v1/content?audience=female_user', { token: woman.token });
  assert.equal(womanLibrary.status, 200);
  assert.ok(womanLibrary.body.data.length > 0);
  assert.ok(womanLibrary.body.data.every((item) => item.audience === 'female_user'));
  assert.ok(womanLibrary.body.data.every((item) => item.source), 'every clinical item must cite a source');
  assert.ok(womanLibrary.body.data.every((item) => item.version));

  const partnerLibrary = await api('GET', '/api/v1/content', { token: partner.token });
  assert.ok(partnerLibrary.body.data.length > 0);
  assert.ok(partnerLibrary.body.data.every((item) => item.audience === 'partner'));
});

test('content: progress and bookmarks persist', async () => {
  const user = await createTestUser();
  const library = await api('GET', '/api/v1/content?audience=female_user', { token: user.token });
  const contentId = library.body.data[0].contentId;

  await api('PUT', `/api/v1/content/${contentId}/progress`, { token: user.token, body: { progressPercent: 60 } });
  await api('PUT', `/api/v1/content/${contentId}/bookmark`, { token: user.token, body: { bookmarked: true } });

  const saved = await api('GET', '/api/v1/content/saved', { token: user.token });
  assert.equal(saved.body.data.length, 1);
  assert.equal(saved.body.data[0].contentId, contentId);
  assert.equal(saved.body.data[0].progress.progressPercent, 60);

  await api('PUT', `/api/v1/content/${contentId}/progress`, { token: user.token, body: { completed: true } });
  const completed = await api('GET', '/api/v1/content/completed', { token: user.token });
  assert.equal(completed.body.data[0].progressPercent, 100);
});

test('content: a draft is never served to users', async () => {
  const draftId = `mc_test_draft_${randomUUID().slice(0, 8)}`;
  await getDb().collection('medical_content').insertOne({
    content_id: draftId,
    title: 'Unreviewed draft',
    body: 'Should never be served.',
    status: 'draft',
    life_stages: ['cycle_tracking'],
    topics: [],
    audience: 'female_user',
    version: '0.1.0',
    locale: 'en',
    created_at: new Date(),
    updated_at: new Date(),
  });

  const user = await createTestUser();
  const result = await api('GET', `/api/v1/content/${draftId}`, { token: user.token });
  assert.equal(result.status, 404);
});

/* ================================================================== *
 * Doctor companion (spec §18)
 * ================================================================== */

test('conditions: only what the user reported, never inferred from logs', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'hormonal_health' } });

  // Logging symptoms that might suggest a condition must not create one.
  for (let i = 0; i < 5; i += 1) {
    await api('POST', '/api/v1/events', {
      token: user.token,
      body: {
        eventType: 'symptom_logged',
        payload: { symptom: 'pelvic pain', severity: 6 },
        timestamp: new Date(Date.now() - (i + 1) * 86400000).toISOString(),
      },
    });
  }

  const before = await api('GET', '/api/v1/conditions', { token: user.token });
  assert.equal(before.body.state, 'empty');
  assert.deepEqual(before.body.data.conditions, []);
  assert.equal(before.body.data.inferredFromLogs, false);
  // No estimated hormone levels are ever offered (spec §14).
  assert.equal(before.body.data.hormoneLevelsSupported, false);

  const saved = await api('PUT', '/api/v1/conditions', {
    token: user.token,
    body: { conditions: ['PCOS', 'Endometriosis'], diagnosedBy: 'clinician' },
  });
  assert.equal(saved.status, 201);

  const after = await api('GET', '/api/v1/conditions', { token: user.token });
  assert.equal(after.body.state, 'ready');
  assert.equal(after.body.data.conditions.length, 2);
  assert.equal(after.body.data.diagnosedBy, 'clinician');
  assert.equal(after.body.data.inferredFromLogs, false);
  assert.equal(after.body.data.hormoneLevelsSupported, false);

  // Reviewed education is attached where it exists, and its absence is stated
  // rather than filled in.
  const pcos = after.body.data.conditions.find((c) => c.condition === 'PCOS');
  assert.ok(pcos);
  assert.equal(pcos.contentAvailable, true);
  assert.ok(pcos.content.every((article) => article.source));
});

test('conditions: "Not diagnosed" is not stored as a condition', async () => {
  const user = await createTestUser();
  await api('PUT', '/api/v1/conditions', {
    token: user.token,
    body: { conditions: ['Not diagnosed'] },
  });

  const result = await api('GET', '/api/v1/conditions', { token: user.token });
  assert.equal(result.body.state, 'empty');
  assert.deepEqual(result.body.data.conditions, []);
});

test('conditions: an empty submission is rejected rather than clearing silently', async () => {
  const user = await createTestUser();
  const result = await api('PUT', '/api/v1/conditions', { token: user.token, body: { conditions: [] } });
  assert.equal(result.status, 400);
  assert.equal(result.body.errorCode, 'VALIDATION_FAILED');
});

test('doctor companion: removed entries do not reach the saved summary', async () => {
  // Spec §18 requires the user can remove entries before export or share.
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'hormonal_health' } });

  for (const symptom of ['pelvic pain', 'fatigue', 'bloating']) {
    for (let i = 0; i < 3; i += 1) {
      await api('POST', '/api/v1/events', {
        token: user.token,
        body: {
          eventType: 'symptom_logged',
          payload: { symptom, severity: 5 },
          timestamp: new Date(Date.now() - (i + 1) * 86400000).toISOString(),
        },
      });
    }
  }

  const preview = await api('GET', '/api/v1/safety/doctor-summary/preview', { token: user.token });
  const symptoms = preview.body.data.sections.find((s) => s.key === 'symptoms');
  assert.ok(symptoms.items.length >= 3);

  // Keep only the first entry, as the screen does when the rest are removed.
  const trimmed = { ...symptoms, items: [symptoms.items[0]] };

  const saved = await api('POST', '/api/v1/safety/doctor-summary', {
    token: user.token,
    body: {
      from: preview.body.data.from,
      to: preview.body.data.to,
      sections: [trimmed],
      questions: ['Could this be endometriosis?', 'Should I be referred?'],
    },
  });
  assert.equal(saved.status, 201);

  const stored = await api('GET', `/api/v1/safety/doctor-summary/${saved.body.data.summaryId}`, { token: user.token });
  const storedSymptoms = stored.body.data.sections.find((s) => s.key === 'symptoms');

  assert.equal(storedSymptoms.items.length, 1, 'removed entries must not be stored');
  assert.equal(stored.body.data.questions.length, 2);
  assert.equal(stored.body.data.isDiagnosis, false);

  // Nothing the user removed is recoverable from the saved record.
  const serialized = JSON.stringify(stored.body.data);
  const dropped = symptoms.items.slice(1).map((i) => i.text);
  for (const text of dropped) {
    assert.ok(!serialized.includes(text), `removed entry leaked: ${text}`);
  }
});

test('doctor companion: screening scores are excluded unless asked for', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/events', {
    token: user.token,
    body: { eventType: 'mood_logged', payload: { mood: 'low' } },
  });
  await api('POST', '/api/v1/safety/screening/submit', {
    token: user.token,
    body: { instrumentId: 'EPDS', responses: [1, 1, 2, 1, 2, 2, 2, 2, 2, 0] },
  });

  const without = await api('GET', '/api/v1/safety/doctor-summary/preview', { token: user.token });
  assert.ok(!without.body.data.sections.some((s) => s.key === 'screenings'));

  const withScores = await api('GET', '/api/v1/safety/doctor-summary/preview?includeScreenings=true', { token: user.token });
  const section = withScores.body.data.sections.find((s) => s.key === 'screenings');
  assert.ok(section, 'screenings should appear when requested');
  assert.equal(section.provenance, 'app_generated');
});

test('doctor companion: the summary is labelled and separates reported from generated', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'hormonal_health' } });

  for (let i = 0; i < 5; i += 1) {
    await api('POST', '/api/v1/events', {
      token: user.token,
      body: {
        eventType: 'symptom_logged',
        payload: { symptom: 'pelvic pain', severity: 6 },
        timestamp: new Date(Date.now() - (i + 1) * 86400000).toISOString(),
      },
    });
  }

  const preview = await api('GET', '/api/v1/safety/doctor-summary/preview', { token: user.token });
  assert.equal(preview.body.state, 'ready');
  assert.equal(preview.body.data.isDiagnosis, false);
  assert.ok(preview.body.data.disclaimer.includes('not a diagnosis'));

  const symptomSection = preview.body.data.sections.find((s) => s.key === 'symptoms');
  assert.equal(symptomSection.provenance, 'user_reported');

  // The user can remove entries before saving (spec §18).
  const saved = await api('POST', '/api/v1/safety/doctor-summary', {
    token: user.token,
    body: {
      from: preview.body.data.from,
      to: preview.body.data.to,
      sections: [symptomSection],
      questions: ['Could this be endometriosis?'],
    },
  });
  assert.equal(saved.status, 201);
  assert.equal(saved.body.data.sections.length, 1);
  assert.equal(saved.body.data.isDiagnosis, false);
});

/* ================================================================== *
 * Reflections (spec §12)
 * ================================================================== */

test('reflections: a response survives being written and read back', async () => {
  // The card used to acknowledge "Send" locally and discard the answer. The
  // spec requires the response to be persisted.
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  const before = await api('GET', '/api/v1/reflections/current', { token: user.token });
  assert.equal(before.body.state, 'empty');
  assert.equal(before.body.data.reflection, null);

  const saved = await api('PUT', '/api/v1/reflections', {
    token: user.token,
    body: { state: 'difficult', response: 'A heavy month, but I rested more.' },
  });
  assert.equal(saved.status, 200);

  const after = await api('GET', '/api/v1/reflections/current', { token: user.token });
  assert.equal(after.body.state, 'ready');
  assert.equal(after.body.data.reflection.response, 'A heavy month, but I rested more.');
  assert.equal(after.body.data.reflection.state, 'difficult');
  assert.equal(after.body.data.reflection.sharedWithPartner, false);

  // Editing the same period updates rather than creating a second entry.
  await api('PUT', '/api/v1/reflections', {
    token: user.token,
    body: { state: 'neutral', response: 'Actually more mixed than hard.' },
  });
  const history = await api('GET', '/api/v1/reflections', { token: user.token });
  assert.equal(history.body.data.length, 1);
  assert.equal(history.body.data[0].state, 'neutral');
});

test('reflections: TTC gets neutral outcome states, not a mood question', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'ttc' } });

  const card = await api('GET', '/api/v1/reflections/current', { token: user.token });
  const states = card.body.data.prompt.allowedStates;

  // A cycle that ended without pregnancy is a factual state, not "difficult".
  assert.ok(states.includes('cycle_completed_without_pregnancy'));
  assert.ok(states.includes('pregnancy_confirmed'));
  assert.ok(states.includes('incomplete_or_unknown'));

  const saved = await api('PUT', '/api/v1/reflections', {
    token: user.token,
    body: { state: 'cycle_completed_without_pregnancy' },
  });
  assert.equal(saved.status, 200);
  assert.equal(saved.body.data.state, 'cycle_completed_without_pregnancy');
});

test('reflections: an unknown state is rejected rather than stored', async () => {
  const user = await createTestUser();
  const result = await api('PUT', '/api/v1/reflections', {
    token: user.token,
    body: { state: 'ecstatic', response: 'x' },
  });
  assert.equal(result.status, 400);
  assert.equal(result.body.errorCode, 'VALIDATION_FAILED');
});

test('reflections: prompts are stage aware and responses are private by default', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'ttc' } });

  const card = await api('GET', '/api/v1/reflections/current', { token: user.token });
  assert.equal(card.status, 200);
  assert.ok(card.body.data.prompt.allowedStates.includes('cycle_completed_without_pregnancy'));

  const saved = await api('PUT', '/api/v1/reflections', {
    token: user.token,
    body: { state: 'cycle_completed_without_pregnancy', response: 'A hard month.' },
  });
  assert.equal(saved.status, 200);
  assert.equal(saved.body.data.sharedWithPartner, false);
});

/* ================================================================== *
 * Timeline (spec §11)
 * ================================================================== */

test('timeline: returns chronological records with pagination and no interpretation', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  for (let i = 0; i < 5; i += 1) {
    await api('POST', '/api/v1/events', {
      token: user.token,
      body: { eventType: 'mood_logged', payload: { mood: 'good' }, timestamp: new Date(Date.now() - (i + 1) * 86400000).toISOString() },
    });
  }

  const timeline = await api('GET', '/api/v1/events/timeline?limit=3', { token: user.token });
  assert.equal(timeline.body.state, 'ready');
  assert.equal(timeline.body.data.entries.length, 3);
  assert.equal(timeline.body.data.pagination.total, 5);
  assert.equal(timeline.body.data.pagination.hasMore, true);

  for (const entry of timeline.body.data.entries) {
    assert.ok(entry.displayText);
    assert.equal(entry.confidence, undefined, 'timeline must not carry interpretation');
  }
});

test('timeline: an AI-derived entry is marked so it is not shown as the user own record', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  await api('POST', '/api/v1/events', {
    token: user.token,
    body: { eventType: 'mood_logged', payload: { mood: 'good' }, source: 'manual' },
  });
  await api('POST', '/api/v1/events', {
    token: user.token,
    body: { eventType: 'mood_logged', payload: { mood: 'low' }, source: 'ai_derived' },
  });

  const timeline = await api('GET', '/api/v1/events/timeline', { token: user.token });
  const entries = timeline.body.data.entries;

  const manual = entries.find((e) => e.source === 'manual');
  const derived = entries.find((e) => e.source === 'ai_derived');

  assert.ok(manual && derived);
  assert.equal(manual.editable, true);
  // The card labels this one rather than presenting it as something the user
  // logged themselves (spec §6).
  assert.equal(derived.editable, false);
  assert.equal(derived.userConfirmed, false);
});

test('timeline: entries come back newest first and paginate without gaps', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  for (let i = 0; i < 25; i += 1) {
    await api('POST', '/api/v1/events', {
      token: user.token,
      body: {
        eventType: 'energy_logged',
        payload: { level: 3 },
        timestamp: new Date(Date.now() - (i + 1) * 3600000).toISOString(),
      },
    });
  }

  const first = await api('GET', '/api/v1/events/timeline?limit=20', { token: user.token });
  assert.equal(first.body.data.entries.length, 20);
  assert.equal(first.body.data.pagination.total, 25);
  assert.equal(first.body.data.pagination.hasMore, true);

  // Newest first.
  const dates = first.body.data.entries.map((e) => new Date(e.date).getTime());
  assert.deepEqual(dates, [...dates].sort((a, b) => b - a));

  const second = await api('GET', '/api/v1/events/timeline?limit=20&skip=20', { token: user.token });
  assert.equal(second.body.data.entries.length, 5);
  assert.equal(second.body.data.pagination.hasMore, false);

  // The two pages together cover every entry exactly once.
  const ids = [...first.body.data.entries, ...second.body.data.entries].map((e) => e.eventId);
  assert.equal(new Set(ids).size, 25);
});

test('timeline: menopause history excludes cycle records', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });
  await api('POST', '/api/v1/cycle/periods', {
    token: user.token,
    body: { startDate: daysAgoIso(20) },
  });
  await api('POST', '/api/v1/events', { token: user.token, body: { eventType: 'hot_flash_logged', payload: { severity: 6 } } });

  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'menopause', confirmed: true },
  });

  const timeline = await api('GET', '/api/v1/events/timeline', { token: user.token });
  assert.equal(timeline.body.data.historyType, 'wellness_and_symptoms');
  assert.ok(!timeline.body.data.entries.some((e) => e.eventType === 'period_logged'));
  assert.ok(timeline.body.data.entries.some((e) => e.eventType === 'hot_flash_logged'));
});

/* ================================================================== *
 * Export and deletion (spec §21, §28, §30)
 * ================================================================== */

test('export and deletion: a user can retrieve and erase their own records', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });
  await api('POST', '/api/v1/events', { token: user.token, body: { eventType: 'mood_logged', payload: { mood: 'good' } } });
  await api('POST', '/api/v1/events', { token: user.token, body: { eventType: 'sleep_logged', payload: { durationHours: 7 } } });

  const events = await api('GET', '/api/v1/events', { token: user.token });
  assert.equal(events.body.data.length, 2);

  const { purgeUserEvents } = await import('../src/repositories/healthEventRepository.js');
  const removed = await purgeUserEvents(user.userId);
  assert.equal(removed, 2);

  const after = await api('GET', '/api/v1/events', { token: user.token });
  assert.equal(after.body.data.length, 0);
  assert.equal(after.body.state, 'empty');
});

test('soft delete: a deleted event stops being returned but remains auditable', async () => {
  const user = await createTestUser();
  const created = await api('POST', '/api/v1/events', {
    token: user.token,
    body: { eventType: 'mood_logged', payload: { mood: 'low' } },
  });
  const eventId = created.body.data.event.eventId;

  await api('DELETE', `/api/v1/events/${eventId}`, { token: user.token });

  const list = await api('GET', '/api/v1/events', { token: user.token });
  assert.equal(list.body.data.length, 0);

  const row = await getDb().collection('health_events').findOne({ event_id: eventId });
  assert.ok(row.deleted_at, 'the row should be soft deleted, not destroyed');
});

/* ================================================================== *
 * Community moderation (spec §12, §22)
 * ================================================================== */

test('moderation: a new post is evaluated before it can be served', async () => {
  const user = await createTestUser({ role: 'woman' });

  const created = await api('POST', '/posts', {
    token: user.token,
    body: { title: 'My PCOS journey', text: 'I was diagnosed with PCOS last year and wanted to share how it has gone.' },
  });

  assert.equal(created.status, 201);
  assert.ok(created.body.moderation, 'a post must carry a moderation decision');
  assert.equal(created.body.moderation.state, 'warned');
  assert.ok(created.body.moderation.sensitiveTopics.includes('pcos'));
  assert.ok(created.body.moderation.notice.includes('not medical advice'));
});

test('moderation: a treatment claim is routed for clinical review, not published quietly', async () => {
  const user = await createTestUser({ role: 'woman' });
  const admin = await createTestUser({ role: 'admin' });

  const created = await api('POST', '/posts', {
    token: user.token,
    body: {
      title: 'PCOS cure',
      text: 'You should stop taking metformin. Inositol cures PCOS, doctors are wrong.',
    },
  });
  assert.equal(created.body.moderation.state, 'medical_review');
  assert.equal(created.body.moderation.requiresHumanReview, true);

  const queue = await api('GET', '/api/v1/moderation/queue', { token: admin.token });
  assert.equal(queue.status, 200);
  assert.ok(queue.body.data.some((p) => p.postId === created.body.post.postId));
});

test('moderation: the review queue is admin only', async () => {
  const user = await createTestUser({ role: 'woman' });
  const result = await api('GET', '/api/v1/moderation/queue', { token: user.token });
  assert.equal(result.status, 403);
});

test('moderation: only a human can clear or remove a post, and it is audited', async () => {
  const user = await createTestUser({ role: 'woman' });
  const admin = await createTestUser({ role: 'admin' });

  const created = await api('POST', '/posts', {
    token: user.token,
    body: { title: 'HRT doses', text: 'I take 100mg of progesterone nightly.' },
  });
  const postId = created.body.post.postId;
  assert.equal(created.body.moderation.state, 'medical_review');

  const cleared = await api('POST', `/api/v1/moderation/posts/${postId}/action`, {
    token: admin.token,
    body: { action: 'attach_warning', notes: 'Personal experience, notice attached.' },
  });
  assert.equal(cleared.status, 200);
  assert.equal(cleared.body.data.moderationState, 'warned');
  assert.equal(cleared.body.data.requiresHumanReview, false);
  assert.equal(cleared.body.data.reviewedBy, admin.userId);

  // The decision is auditable (spec §27).
  const audit = await api('GET', `/api/v1/moderation/posts/${postId}/audit`, { token: admin.token });
  assert.ok(audit.body.data.some((a) => a.action === 'attach_warning' && a.actorId === admin.userId));

  const queue = await api('GET', '/api/v1/moderation/queue', { token: admin.token });
  assert.ok(!queue.body.data.some((p) => p.postId === postId));
});

test('moderation: an unknown moderator action is rejected', async () => {
  const admin = await createTestUser({ role: 'admin' });
  const user = await createTestUser({ role: 'woman' });
  const created = await api('POST', '/posts', { token: user.token, body: { title: 'Hi', text: 'Hello' } });

  const result = await api('POST', `/api/v1/moderation/posts/${created.body.post.postId}/action`, {
    token: admin.token,
    body: { action: 'delete_everything' },
  });
  assert.equal(result.status, 400);
  assert.equal(result.body.errorCode, 'VALIDATION_FAILED');
});

test('moderation: reporting is acknowledged without revealing the outcome', async () => {
  const author = await createTestUser({ role: 'woman' });
  const reporter = await createTestUser({ role: 'woman' });

  const created = await api('POST', '/posts', {
    token: author.token,
    body: { title: 'Fertility', text: 'This is what happened during my IVF cycle.' },
  });
  const postId = created.body.post.postId;

  const reported = await api('POST', `/api/v1/moderation/posts/${postId}/report`, {
    token: reporter.token,
    body: { reason: 'misinformation' },
  });

  assert.equal(reported.status, 200);
  assert.equal(reported.body.data.acknowledged, true);

  const invalid = await api('POST', `/api/v1/moderation/posts/${postId}/report`, {
    token: reporter.token,
    body: { reason: 'i_just_dislike_it' },
  });
  assert.equal(invalid.status, 400);
});

test('moderation: blocking is mutual and listed', async () => {
  const a = await createTestUser({ role: 'woman' });
  const b = await createTestUser({ role: 'woman' });

  const blocked = await api('POST', `/api/v1/moderation/blocks/${b.userId}`, { token: a.token });
  assert.equal(blocked.status, 200);

  // Both sides stop seeing each other, so blocking does not leave the blocker
  // exposed to the person they blocked.
  const forA = await api('GET', '/api/v1/moderation/blocks', { token: a.token });
  assert.ok(forA.body.data.includes(b.userId));
  const forB = await api('GET', '/api/v1/moderation/blocks', { token: b.token });
  assert.ok(forB.body.data.includes(a.userId));

  await api('DELETE', `/api/v1/moderation/blocks/${b.userId}`, { token: a.token });
  const after = await api('GET', '/api/v1/moderation/blocks', { token: a.token });
  assert.ok(!after.body.data.includes(b.userId));
});

test('moderation: you cannot block yourself', async () => {
  const user = await createTestUser({ role: 'woman' });
  const result = await api('POST', `/api/v1/moderation/blocks/${user.userId}`, { token: user.token });
  assert.equal(result.status, 400);
});

test('moderation: posts carry the audience they were written for', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const admin = await createTestUser({ role: 'admin' });

  const fromWoman = await api('POST', '/posts', { token: woman.token, body: { title: 'W', text: 'Hello' } });
  const fromPartner = await api('POST', '/posts', { token: partner.token, body: { title: 'P', text: 'Hello' } });

  const womanView = await api('GET', `/api/v1/moderation/posts/${fromWoman.body.post.postId}`, { token: admin.token });
  const partnerView = await api('GET', `/api/v1/moderation/posts/${fromPartner.body.post.postId}`, { token: admin.token });

  assert.equal(womanView.body.data.audience, 'female_user');
  assert.equal(partnerView.body.data.audience, 'partner');
  // The partner community is anonymous by default (spec §12).
  assert.equal(partnerView.body.data.anonymous, true);
  assert.equal(womanView.body.data.anonymous, false);
});

test('moderation: the feed itself enforces audience separation and blocks', async () => {
  // Spec §28: never rely on the frontend hiding data. These are the checks the
  // feed endpoint applies, not the client.
  const woman = await createTestUser({ role: 'woman' });
  const otherWoman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });

  const womanPost = await api('POST', '/posts', {
    token: otherWoman.token,
    body: { title: 'Womens community', text: 'A post for the womens feed.' },
  });
  const partnerPost = await api('POST', '/posts', {
    token: partner.token,
    body: { title: 'Partner community', text: 'A post for the partner feed.' },
  });

  const womanFeed = await api('GET', '/posts/feed', { token: woman.token });
  const womanFeedIds = womanFeed.body.posts.map((p) => p.postId);
  assert.ok(womanFeedIds.includes(womanPost.body.post.postId));
  // A partner post never reaches the female feed.
  assert.ok(!womanFeedIds.includes(partnerPost.body.post.postId));

  const partnerFeed = await api('GET', '/posts/feed', { token: partner.token });
  const partnerFeedIds = partnerFeed.body.posts.map((p) => p.postId);
  assert.ok(!partnerFeedIds.includes(womanPost.body.post.postId));

  // Blocking removes that author from the feed.
  await api('POST', `/api/v1/moderation/blocks/${otherWoman.userId}`, { token: woman.token });
  const afterBlock = await api('GET', '/posts/feed', { token: woman.token });
  assert.ok(!afterBlock.body.posts.map((p) => p.postId).includes(womanPost.body.post.postId));
});

test('moderation: a post held for review leaves the feed but its author still sees it', async () => {
  const author = await createTestUser({ role: 'woman' });
  const reader = await createTestUser({ role: 'woman' });

  const created = await api('POST', '/posts', {
    token: author.token,
    body: { title: 'PCOS cure', text: 'You should stop taking metformin, inositol cures PCOS.' },
  });
  assert.equal(created.body.moderation.state, 'medical_review');

  const readerFeed = await api('GET', '/posts/feed', { token: reader.token });
  assert.ok(!readerFeed.body.posts.map((p) => p.postId).includes(created.body.post.postId));

  // The author is not left wondering where their post went.
  const authorFeed = await api('GET', '/posts/feed', { token: author.token });
  assert.ok(authorFeed.body.posts.map((p) => p.postId).includes(created.body.post.postId));
});

test('moderation: the notice travels with the post to the feed', async () => {
  const author = await createTestUser({ role: 'woman' });
  const reader = await createTestUser({ role: 'woman' });

  const created = await api('POST', '/posts', {
    token: author.token,
    body: { title: 'My endometriosis story', text: 'Sharing how my endometriosis diagnosis went.' },
  });
  assert.equal(created.body.moderation.state, 'warned');

  const feed = await api('GET', '/posts/feed', { token: reader.token });
  const post = feed.body.posts.find((p) => p.postId === created.body.post.postId);

  assert.ok(post, 'a warned post stays in the feed');
  assert.ok(post.moderationNotice.includes('not medical advice'));
  assert.equal(post.isClinicallyReviewed, false);
});

test('moderation: partner posts reach the partner feed anonymously', async () => {
  const partner = await createTestUser({ role: 'man' });
  const otherPartner = await createTestUser({ role: 'man' });

  const created = await api('POST', '/posts', {
    token: otherPartner.token,
    body: { title: 'Supporting her', text: 'How do you all handle the hard weeks?' },
  });

  const feed = await api('GET', '/posts/feed', { token: partner.token });
  const post = feed.body.posts.find((p) => p.postId === created.body.post.postId);

  assert.ok(post, 'the partner feed shows partner posts');
  // Anonymity is applied server side: the author id never reaches the reader.
  assert.equal(post.authorId, null);
  assert.equal(post.authorName, 'Community member');
});

test('moderation: a comment is evaluated by the same rules as a post', async () => {
  const author = await createTestUser({ role: 'woman' });

  const post = await api('POST', '/posts', {
    token: author.token,
    body: { title: 'Question', text: 'Has anyone tried anything for this?' },
  });

  const comment = await api('POST', `/posts/${post.body.post.postId}/comments`, {
    token: author.token,
    body: { text: 'I was diagnosed with PCOS too and this is what my experience has been.' },
  });

  assert.equal(comment.status, 201);
  assert.ok(comment.body.moderation, 'a comment must carry a moderation decision');
  assert.equal(comment.body.moderation.state, 'warned');
  assert.ok(comment.body.moderation.sensitiveTopics.includes('pcos'));
  assert.ok(comment.body.moderation.notice.includes('not medical advice'));
});

test('moderation: a treatment claim in a comment is held, not published', async () => {
  const author = await createTestUser({ role: 'woman' });
  const reader = await createTestUser({ role: 'woman' });
  const admin = await createTestUser({ role: 'admin' });

  const post = await api('POST', '/posts', {
    token: author.token,
    body: { title: 'Question', text: 'Any tips?' },
  });
  const postId = post.body.post.postId;

  const comment = await api('POST', `/posts/${postId}/comments`, {
    token: author.token,
    body: { text: 'You should stop taking metformin, inositol cures PCOS.' },
  });
  assert.equal(comment.body.moderation.state, 'medical_review');
  assert.equal(comment.body.moderation.requiresHumanReview, true);

  // A reader does not see it.
  const readerView = await api('GET', `/posts/${postId}/comments`, { token: reader.token });
  assert.ok(!readerView.body.comments.some((c) => c.commentId === comment.body.comment.commentId));

  // The author still does, so it does not silently vanish for them.
  const authorView = await api('GET', `/posts/${postId}/comments`, { token: author.token });
  assert.ok(authorView.body.comments.some((c) => c.commentId === comment.body.comment.commentId));

  // And it reaches the same review queue as posts, tagged by type.
  const queue = await api('GET', '/api/v1/moderation/queue', { token: admin.token });
  const queued = queue.body.data.find((q) => q.commentId === comment.body.comment.commentId);
  assert.ok(queued, 'the comment should be in the moderator queue');
  assert.equal(queued.targetType, 'comment');
});

test('moderation: a moderator can clear a held comment, and it is audited', async () => {
  const author = await createTestUser({ role: 'woman' });
  const reader = await createTestUser({ role: 'woman' });
  const admin = await createTestUser({ role: 'admin' });

  const post = await api('POST', '/posts', { token: author.token, body: { title: 'Q', text: 'Hi' } });
  const postId = post.body.post.postId;

  const comment = await api('POST', `/posts/${postId}/comments`, {
    token: author.token,
    body: { text: 'I take 50mg of something for my endometriosis.' },
  });
  const commentId = comment.body.comment.commentId;
  assert.equal(comment.body.moderation.state, 'medical_review');

  const cleared = await api('POST', `/api/v1/moderation/comments/${commentId}/action`, {
    token: admin.token,
    body: { action: 'attach_warning', notes: 'Personal experience.' },
  });
  assert.equal(cleared.status, 200);
  assert.equal(cleared.body.data.moderationState, 'warned');
  assert.equal(cleared.body.data.reviewedBy, admin.userId);

  // Now visible to readers, with the notice.
  const readerView = await api('GET', `/posts/${postId}/comments`, { token: reader.token });
  const visible = readerView.body.comments.find((c) => c.commentId === commentId);
  assert.ok(visible, 'a cleared comment becomes visible');
  assert.ok(visible.moderationNotice.includes('not medical advice'));
  assert.equal(visible.isClinicallyReviewed, false);

  const audit = await api('GET', `/api/v1/moderation/posts/${commentId}/audit`, { token: admin.token });
  assert.ok(audit.body.data.some((a) => a.action === 'attach_warning' && a.actorId === admin.userId));
});

test('moderation: comments can be reported, and blocked authors disappear from a thread', async () => {
  const author = await createTestUser({ role: 'woman' });
  const reader = await createTestUser({ role: 'woman' });

  const post = await api('POST', '/posts', { token: reader.token, body: { title: 'Q', text: 'Hi' } });
  const postId = post.body.post.postId;

  const comment = await api('POST', `/posts/${postId}/comments`, {
    token: author.token,
    body: { text: 'Just a normal reply.' },
  });
  const commentId = comment.body.comment.commentId;

  const reported = await api('POST', `/api/v1/moderation/comments/${commentId}/report`, {
    token: reader.token,
    body: { reason: 'harassment' },
  });
  assert.equal(reported.status, 200);
  assert.equal(reported.body.data.acknowledged, true);

  const invalid = await api('POST', `/api/v1/moderation/comments/${commentId}/report`, {
    token: reader.token,
    body: { reason: 'i_dislike_it' },
  });
  assert.equal(invalid.status, 400);

  // Blocking the author removes their comment from the thread.
  await api('POST', `/api/v1/moderation/blocks/${author.userId}`, { token: reader.token });
  const afterBlock = await api('GET', `/posts/${postId}/comments`, { token: reader.token });
  assert.ok(!afterBlock.body.comments.some((c) => c.commentId === commentId));
});

test('moderation: comment moderator actions are validated', async () => {
  const admin = await createTestUser({ role: 'admin' });
  const author = await createTestUser({ role: 'woman' });

  const post = await api('POST', '/posts', { token: author.token, body: { title: 'Q', text: 'Hi' } });
  const comment = await api('POST', `/posts/${post.body.post.postId}/comments`, {
    token: author.token,
    body: { text: 'Hello' },
  });

  const result = await api('POST', `/api/v1/moderation/comments/${comment.body.comment.commentId}/action`, {
    token: admin.token,
    body: { action: 'nuke_it' },
  });
  assert.equal(result.status, 400);
  assert.equal(result.body.errorCode, 'VALIDATION_FAILED');
});

test('partner: legacy share flags are honoured by the current permission matrix', async () => {
  // A connection created before the 13-key matrix stores the old flags. The
  // filtered view must still honour them, or existing couples would silently
  // lose sharing they had already agreed to.
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, {
    shareCycle: true,
    shareMood: true,
  });

  await api('POST', '/api/v1/life-stage/transition', { token: woman.token, body: { toStage: 'cycle_tracking' } });
  await api('POST', '/api/v1/events', { token: woman.token, body: { eventType: 'mood_logged', payload: { mood: 'low' } } });

  const context = await api('GET', `/api/v1/partner/connections/${connectionId}/context`, { token: partner.token });
  assert.ok(context.body.data.mood, 'the legacy shareMood flag should still grant mood');
  assert.ok(context.body.permissions.allowedGrants.includes('log.mood'));
  assert.ok(context.body.permissions.allowedGrants.includes('cycle.phase'));
});

test('partner: using the new sharing screen replaces the old flags without losing consent', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, { shareMood: true });

  await api('POST', '/api/v1/events', { token: woman.token, body: { eventType: 'mood_logged', payload: { mood: 'good' } } });
  await api('POST', '/api/v1/events', { token: woman.token, body: { eventType: 'energy_logged', payload: { level: 2 } } });

  // She turns energy on. Mood was already shared under the old flag and must
  // survive the migration.
  const updated = await api('PATCH', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
    body: { permissions: { energy: true } },
  });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.data.permissions.mood, true, 'existing consent must not be dropped');
  assert.equal(updated.body.data.permissions.energy, true);

  const context = await api('GET', `/api/v1/partner/connections/${connectionId}/context`, { token: partner.token });
  assert.ok(context.body.data.mood);
  assert.ok(context.body.data.energyLevel);
});

test('partner: revoking cycle sharing blanks the partner cycle view', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, { shareCycle: true });

  await api('POST', '/api/v1/life-stage/transition', { token: woman.token, body: { toStage: 'cycle_tracking' } });
  for (const daysAgo of [56, 28]) {
    const date = daysAgoIso(daysAgo);
    await api('POST', '/api/v1/cycle/periods', { token: woman.token, body: { startDate: date } });
  }

  const before = await api('GET', `/api/v1/partner/connections/${connectionId}/context`, { token: partner.token });
  assert.ok(before.body.data.cyclePhase, 'cycle context should be shared initially');

  await api('PATCH', `/api/v1/partner/connections/${connectionId}/sharing`, {
    token: woman.token,
    body: { permissions: { cycle_insights: false } },
  });

  const after = await api('GET', `/api/v1/partner/connections/${connectionId}/context`, { token: partner.token });
  assert.equal(after.body.data.cyclePhase, undefined, 'revocation must blank the cycle view');
  assert.ok(after.body.permissions.restrictedGrants.includes('cycle.phase'));

  // The Us surface agrees rather than disagreeing with the context.
  const us = await api('GET', `/api/v1/partner/connections/${connectionId}/us`, { token: partner.token });
  const cycleSection = us.body.data.sections.find((s) => s.key === 'cycle_context');
  assert.equal(cycleSection.enabled, false);
  assert.equal(cycleSection.items.length, 0);
});

/* ================================================================== *
 * Offline queue replay (spec §25)
 * ================================================================== */

test('offline sync: replaying the same queued batch does not double-log', async () => {
  // The client queues writes it could not deliver and retries them. A write
  // that actually succeeded but whose response was lost must not be recorded
  // twice when the queue is flushed again.
  const user = await createTestUser();
  const batch = [
    { eventType: 'mood_logged', payload: { mood: 'good' }, clientEventId: 'q1' },
    { eventType: 'energy_logged', payload: { level: 3, reportedAs: 'Medium' }, clientEventId: 'q2' },
    { eventType: 'sleep_logged', payload: { durationHours: 7, reportedAs: '6-8h' }, clientEventId: 'q3' },
  ];

  const first = await api('POST', '/api/v1/events/sync', { token: user.token, body: { events: batch } });
  assert.equal(first.body.data.acceptedCount, 3);

  const replay = await api('POST', '/api/v1/events/sync', { token: user.token, body: { events: batch } });
  assert.equal(replay.body.data.acceptedCount, 3);
  assert.equal(replay.body.data.rejectedCount, 0);
  assert.ok(replay.body.data.accepted.every((a) => a.deduplicated === true));

  const stored = await api('GET', '/api/v1/events', { token: user.token });
  assert.equal(stored.body.data.length, 3, 'a replayed queue must not duplicate events');
});

test('offline sync: an invalid queued item is rejected without blocking the rest', async () => {
  // The client drops permanently rejected items, so one bad payload cannot
  // block everything queued behind it.
  const user = await createTestUser();

  const result = await api('POST', '/api/v1/events/sync', {
    token: user.token,
    body: {
      events: [
        { eventType: 'mood_logged', payload: { mood: 'good' }, clientEventId: 'ok1' },
        { eventType: 'sleep_logged', payload: { durationHours: 99 }, clientEventId: 'bad1' },
        { eventType: 'energy_logged', payload: { level: 3 }, clientEventId: 'ok2' },
      ],
    },
  });

  assert.equal(result.body.data.acceptedCount, 2);
  assert.equal(result.body.data.rejectedCount, 1);
  assert.equal(result.body.data.rejected[0].clientEventId, 'bad1');
  assert.ok(result.body.data.rejected[0].error);

  const stored = await api('GET', '/api/v1/events', { token: user.token });
  assert.equal(stored.body.data.length, 2);
});

test('offline sync: queued events keep the timestamp they were made at', async () => {
  const user = await createTestUser();
  const madeAt = new Date(Date.now() - 3 * 86400000).toISOString();

  await api('POST', '/api/v1/events/sync', {
    token: user.token,
    body: {
      events: [
        { eventType: 'mood_logged', payload: { mood: 'low' }, clientEventId: 'past1', timestamp: madeAt },
      ],
    },
  });

  const stored = await api('GET', '/api/v1/events', { token: user.token });
  // Logged three days ago offline, not backdated to the sync time.
  assert.equal(stored.body.data[0].timestamp, madeAt);
});

/* ================================================================== *
 * Journal privacy (spec §6, §10, §26)
 * ================================================================== */

test('journal: the entry reaches the timeline without its text leaving the device', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', { token: user.token, body: { toStage: 'cycle_tracking' } });

  // The client sends a word count, not the body.
  const logged = await api('POST', '/api/v1/events', {
    token: user.token,
    body: { eventType: 'journal_created', payload: { text: '[128 words]' }, clientEventId: 'journal:1' },
  });
  assert.equal(logged.status, 201);

  const timeline = await api('GET', '/api/v1/events/timeline', { token: user.token });
  const entry = timeline.body.data.entries.find((e) => e.eventType === 'journal_created');
  assert.ok(entry, 'a journal entry should appear on the timeline');
  assert.equal(entry.displayText, 'Journal entry');
});

test('journal: entries are not shared with a partner by default', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const partner = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, partner.userId, { shareMood: true });

  await api('POST', '/api/v1/events', {
    token: woman.token,
    body: { eventType: 'journal_created', payload: { text: '[40 words]' } },
  });

  const context = await api('GET', `/api/v1/partner/connections/${connectionId}/context`, { token: partner.token });
  // Journal needs its own explicit grant, which sharing mood does not confer.
  assert.equal(context.body.data.journalEntries, undefined);
  assert.ok(context.body.permissions.restrictedGrants.includes('journal.entry'));
});

/* ================================================================== *
 * Onboarding into the life stage engine (spec §3, §23)
 * ================================================================== */

/* ------------------------------------------------------------------ *
 * Community feed counts (spec §12)
 * ------------------------------------------------------------------ */

async function createFeedPost(user, title = 'A question') {
  const created = await api('POST', '/api/posts', {
    token: user.token,
    body: { title, text: 'Body text.', tags: [] },
  });
  assert.ok(created.status === 200 || created.status === 201, `post create failed: ${created.status}`);
  return created.body.postId ?? created.body.data?.postId ?? created.body.post?.postId;
}

async function feedPost(user, postId) {
  const feed = await api('GET', '/api/posts/feed', { token: user.token });
  const posts = feed.body.data ?? feed.body.posts ?? feed.body;
  return (Array.isArray(posts) ? posts : []).find((p) => p.postId === postId);
}

/* ------------------------------------------------------------------ *
 * Daily chat summaries, user-facing (spec §20)
 * ------------------------------------------------------------------ */

/* ------------------------------------------------------------------ *
 * Shared activities (spec §10, §16)
 * ------------------------------------------------------------------ */

/* ------------------------------------------------------------------ *
 * Journal persistence (spec §6)
 * ------------------------------------------------------------------ */

/* ------------------------------------------------------------------ *
 * Session refresh (spec §2)
 * ------------------------------------------------------------------ */

/* ------------------------------------------------------------------ *
 * Sign-out and session revocation (spec §2)
 * ------------------------------------------------------------------ */

test('logout: the access token stops working afterwards', async () => {
  const user = await createTestUser();

  const before = await api('GET', '/api/v1/home', { token: user.token });
  assert.equal(before.status, 200);

  await api('POST', '/api/auth/logout', { token: user.token });

  const after = await api('GET', '/api/v1/home', { token: user.token });
  assert.equal(after.status, 401, 'a signed-out token must not keep working');
});

test('logout: a refresh token issued before it cannot resurrect the session', async () => {
  // The app now refreshes automatically on a 401. If a pre-logout refresh
  // token still worked, signing out would undo itself on the very next
  // request.
  const { signRefreshToken } = await import('../src/services/tokenService.js');
  const user = await createTestUser();

  const refreshToken = signRefreshToken({ userId: user.userId, tokenVersion: 1 });
  await api('POST', '/api/auth/logout', { token: user.token });

  const refreshed = await api('POST', '/api/auth/refresh', { body: { refreshToken } });
  assert.ok(refreshed.status >= 400, 'signing out has to survive the automatic refresh');
});

test('logout: signing out on one device does not need the other to cooperate', async () => {
  // tokenVersion is per account, so revoking covers every issued token.
  const { signAccessToken } = await import('../src/services/tokenService.js');
  const user = await createTestUser();

  const secondDevice = signAccessToken({ userId: user.userId, tokenVersion: 1 });
  const worksBefore = await api('GET', '/api/v1/home', { token: secondDevice });
  assert.equal(worksBefore.status, 200);

  await api('POST', '/api/auth/logout', { token: user.token });

  const worksAfter = await api('GET', '/api/v1/home', { token: secondDevice });
  assert.equal(worksAfter.status, 401, 'a lost phone is the reason this matters');
});

/* ------------------------------------------------------------------ *
 * Free-text safety screening (spec §22)
 * ------------------------------------------------------------------ */

test('safety: text describing an emergency is escalated', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-03-01' } },
  });

  const result = await api('POST', '/api/v1/safety/check-text', {
    token: user.token,
    body: { text: 'I have heavy bleeding soaking a pad every hour and feel faint' },
  });

  assert.equal(result.status, 200);
  assert.ok(result.body.data, 'a safety check must always return a decision');
  assert.equal(result.body.data.triggered, true,
    'a described emergency must not come back as ordinary text');
  assert.ok(
    ['emergency', 'urgent', 'contact_provider', 'monitor'].includes(result.body.data.level),
    `expected a real escalation level, got ${result.body.data.level}`,
  );
  assert.ok(result.body.data.flow, 'an escalation has to carry the guidance with it');
});

test('safety: ordinary text is not escalated', async () => {
  // A screen that cried emergency at everything would be ignored when it
  // mattered. Same stage as the escalating case, so only the text differs.
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-03-01' } },
  });

  const result = await api('POST', '/api/v1/safety/check-text', {
    token: user.token,
    body: { text: 'I went for a nice walk today and felt calm' },
  });

  assert.equal(result.status, 200);
  assert.equal(result.body.data.triggered, false,
    'a screen that flags everything gets ignored when it matters');
  assert.equal(result.body.data.suppressWellnessContent, false,
    'ordinary text must not suppress the rest of the app');
});

test('safety: the check works without an AI provider configured', async () => {
  // Red flag detection is deterministic on purpose (spec §22); it must not
  // depend on a model being reachable.
  const previous = process.env.GROK_API_KEY;
  delete process.env.GROK_API_KEY;
  try {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-03-01' } },
  });
    const result = await api('POST', '/api/v1/safety/check-text', {
      token: user.token,
      body: { text: 'I have heavy bleeding soaking a pad every hour and feel faint' },
    });
    assert.equal(result.status, 200);
    assert.equal(result.body.data.triggered, true,
      'red flag detection is deterministic and must not need a model');
  } finally {
    if (previous !== undefined) process.env.GROK_API_KEY = previous;
  }
});

test('refresh: a valid refresh token returns a usable access token', async () => {
  // The app stored a refresh token from day one and never used it, so once the
  // access token expired every request failed until the user signed in again.
  const { signRefreshToken } = await import('../src/services/tokenService.js');
  const user = await createTestUser();

  const refreshToken = signRefreshToken({ userId: user.userId, tokenVersion: 1 });
  const refreshed = await api('POST', '/api/auth/refresh', { body: { refreshToken } });

  assert.equal(refreshed.status, 200);
  assert.equal(typeof refreshed.body.token, 'string');
  assert.ok(refreshed.body.token.length > 0);

  // The point of the exercise: the new token has to actually work.
  const me = await api('GET', '/api/v1/home', { token: refreshed.body.token });
  assert.equal(me.status, 200);
});

test('refresh: a rotated refresh token comes back, so the old one is not reused forever', async () => {
  const { signRefreshToken } = await import('../src/services/tokenService.js');
  const user = await createTestUser();

  const refreshToken = signRefreshToken({ userId: user.userId, tokenVersion: 1 });
  const refreshed = await api('POST', '/api/auth/refresh', { body: { refreshToken } });

  assert.equal(typeof refreshed.body.refreshToken, 'string');
  assert.ok(refreshed.body.refreshToken.length > 0);
});

test('refresh: a missing or junk token is rejected, not silently accepted', async () => {
  const empty = await api('POST', '/api/auth/refresh', { body: {} });
  assert.ok(empty.status >= 400, `expected a rejection, got ${empty.status}`);

  const junk = await api('POST', '/api/auth/refresh', { body: { refreshToken: 'not-a-token' } });
  assert.ok(junk.status >= 400, `expected a rejection, got ${junk.status}`);
});

test('refresh: a token from a bumped token version is refused', async () => {
  // Signing out everywhere bumps tokenVersion; an old refresh token must not
  // resurrect that session.
  const { signRefreshToken } = await import('../src/services/tokenService.js');
  const user = await createTestUser();

  const stale = signRefreshToken({ userId: user.userId, tokenVersion: 99 });
  const result = await api('POST', '/api/auth/refresh', { body: { refreshToken: stale } });

  assert.ok(result.status >= 400, 'a superseded session must not be refreshable');
});

test('journal: an entry saved to the account comes back on a fresh device', async () => {
  // Journals were written to device storage only, so a reinstall or a move
  // between web and Android lost them. The server storage existed all along
  // and nothing was writing to it.
  const user = await createTestUser();

  const saved = await api('PUT', '/api/auth/me/journal', {
    token: user.token,
    body: {
      entryDate: '2026-08-29',
      summary: 'A quiet day',
      entries: [
        { id: 'e1', date: '2026-08-29', title: 'A quiet day', body: 'Walked after lunch.', moodKey: 'calm' },
      ],
    },
  });
  assert.equal(saved.status, 200);

  const fetched = await api('GET', '/api/auth/me/journal', { token: user.token });
  assert.equal(fetched.status, 200);
  const day = fetched.body.journals.find((j) => j.entryDate === '2026-08-29');
  assert.ok(day, 'the saved day should come back');
  assert.equal(day.entries.length, 1);
  assert.equal(day.entries[0].title, 'A quiet day');
});

test('journal: several entries on one day are all kept', async () => {
  // The server groups by day, so a second entry must not replace the first.
  const user = await createTestUser();

  await api('PUT', '/api/auth/me/journal', {
    token: user.token,
    body: {
      entryDate: '2026-08-30',
      summary: '2 entries',
      entries: [
        { id: 'a', date: '2026-08-30', title: 'Morning', body: 'Slept well.' },
        { id: 'b', date: '2026-08-30', title: 'Evening', body: 'Long walk.' },
      ],
    },
  });

  const fetched = await api('GET', '/api/auth/me/journal', { token: user.token });
  const day = fetched.body.journals.find((j) => j.entryDate === '2026-08-30');
  assert.equal(day.entries.length, 2);
});

test('journal: re-saving a day replaces it rather than accumulating', async () => {
  const user = await createTestUser();
  const body = (title) => ({
    entryDate: '2026-08-28',
    summary: title,
    entries: [{ id: 'only', date: '2026-08-28', title, body: 'text' }],
  });

  await api('PUT', '/api/auth/me/journal', { token: user.token, body: body('First draft') });
  await api('PUT', '/api/auth/me/journal', { token: user.token, body: body('Edited') });

  const fetched = await api('GET', '/api/auth/me/journal', { token: user.token });
  const days = fetched.body.journals.filter((j) => j.entryDate === '2026-08-28');
  assert.equal(days.length, 1, 'editing a day must not create a second copy of it');
  assert.equal(days[0].entries[0].title, 'Edited');
});

test('journal: one account never receives another account journals', async () => {
  const mine = await createTestUser();
  const theirs = await createTestUser();

  await api('PUT', '/api/auth/me/journal', {
    token: theirs.token,
    body: {
      entryDate: '2026-08-27',
      summary: 'Private',
      entries: [{ id: 'p', date: '2026-08-27', title: 'Private', body: 'Not yours.' }],
    },
  });

  const fetched = await api('GET', '/api/auth/me/journal', { token: mine.token });
  assert.deepEqual(fetched.body.journals, [], 'a journal is the most private thing in the app');
});

test('activities: a new connection lists every activity as not started', async () => {
  // The tab used to render five cards, four of which did nothing at all.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const result = await api('GET', `/partner/connections/${connectionId}/activities`, {
    token: woman.token,
  });
  assert.equal(result.status, 200);
  assert.ok(result.body.activities.length >= 5);
  assert.ok(result.body.activities.every((a) => a.status === 'not_started'));
  assert.ok(result.body.activities.every((a) => typeof a.title === 'string' && a.title.length > 0));
});

test('activities: what one partner starts, the other sees', async () => {
  // This is the whole point of a shared activity: one state, two people.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const started = await api(
    'POST',
    `/partner/connections/${connectionId}/activities/daily_gratitude`,
    { token: woman.token, body: { status: 'in_progress' } },
  );
  assert.equal(started.status, 200);

  const asSeenByPartner = await api(
    'GET',
    `/partner/connections/${connectionId}/activities`,
    { token: man.token },
  );
  const gratitude = asSeenByPartner.body.activities.find((a) => a.key === 'daily_gratitude');
  assert.equal(gratitude.status, 'in_progress');
  assert.equal(gratitude.startedByUserId, woman.userId);
});

test('activities: completing records who completed it and counts the run', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});
  const url = `/partner/connections/${connectionId}/activities/weekend_planner`;

  await api('POST', url, { token: woman.token, body: { status: 'in_progress' } });
  const done = await api('POST', url, { token: man.token, body: { status: 'completed' } });

  const planner = done.body.activities.find((a) => a.key === 'weekend_planner');
  assert.equal(planner.status, 'completed');
  assert.equal(planner.completedByUserId, man.userId);
  assert.equal(planner.startedByUserId, woman.userId, 'the starter is not overwritten by the finisher');
  assert.equal(planner.completionCount, 1);
});

test('activities: completing twice in a row is rejected', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});
  const url = `/partner/connections/${connectionId}/activities/date_planner`;

  await api('POST', url, { token: woman.token, body: { status: 'completed' } });
  const again = await api('POST', url, { token: woman.token, body: { status: 'completed' } });

  assert.equal(again.status, 400, 'a second completion would inflate the count');
});

test('activities: a repeatable activity can be started again after completion', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});
  const url = `/partner/connections/${connectionId}/activities/daily_gratitude`;

  await api('POST', url, { token: woman.token, body: { status: 'completed' } });
  const restarted = await api('POST', url, { token: man.token, body: { status: 'in_progress' } });

  assert.equal(restarted.status, 200, 'a daily ritual has to be repeatable');
  const gratitude = restarted.body.activities.find((a) => a.key === 'daily_gratitude');
  assert.equal(gratitude.status, 'in_progress');
  assert.equal(gratitude.completionCount, 1, 'the earlier completion still counts');
});

test('activities: an unknown activity key is rejected', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const result = await api(
    'POST',
    `/partner/connections/${connectionId}/activities/not_a_real_activity`,
    { token: woman.token, body: { status: 'in_progress' } },
  );
  assert.equal(result.status, 400);
});

test('activities: someone outside the connection cannot read or change them', async () => {
  // Activity state is shared relationship data, not public to anyone holding
  // a connection id.
  const woman = await createTestUser({ role: 'woman' });
  const man = await createTestUser({ role: 'man' });
  const outsider = await createTestUser({ role: 'woman' });
  const connectionId = await connectPartners(woman.userId, man.userId, {});

  const read = await api('GET', `/partner/connections/${connectionId}/activities`, {
    token: outsider.token,
  });
  assert.equal(read.status, 404);

  const write = await api(
    'POST',
    `/partner/connections/${connectionId}/activities/daily_gratitude`,
    { token: outsider.token, body: { status: 'completed' } },
  );
  assert.equal(write.status, 404);
});

test('daily summaries: a user with no history gets an empty list, not filler', async () => {
  // M Studio used to invent a letter here, quoting a conversation that never
  // happened. An empty list is what lets it show an honest empty state.
  const user = await createTestUser();

  const result = await api('GET', '/api/ai/daily-summaries', { token: user.token });
  assert.equal(result.status, 200);
  assert.deepEqual(result.body.summaries, []);
});

test('daily summaries: a generated summary is returned to the user it belongs to', async () => {
  const { aiChatSummaryRepository } = await import('../src/repositories/aiChatSummaryRepository.js');
  const user = await createTestUser();

  await aiChatSummaryRepository.upsertDailySummary({
    userKey: `user:${user.userId}`,
    role: 'woman',
    summaryDateIst: '2026-08-29',
    messageCount: 6,
    firstMessageAt: new Date('2026-08-29T04:00:00Z'),
    lastMessageAt: new Date('2026-08-29T09:00:00Z'),
    summaryText: 'Turns: 6. Topics: sleep, hydration.',
  });

  const result = await api('GET', '/api/ai/daily-summaries', { token: user.token });
  assert.equal(result.status, 200);
  assert.equal(result.body.summaries.length, 1);
  assert.equal(result.body.summaries[0].summaryText, 'Turns: 6. Topics: sleep, hydration.');
  assert.equal(result.body.summaries[0].summaryDateIst, '2026-08-29');
  assert.equal(result.body.summaries[0].messageCount, 6);
});

test('daily summaries: one user never sees another user summary', async () => {
  const { aiChatSummaryRepository } = await import('../src/repositories/aiChatSummaryRepository.js');
  const mine = await createTestUser();
  const theirs = await createTestUser();

  await aiChatSummaryRepository.upsertDailySummary({
    userKey: `user:${theirs.userId}`,
    role: 'woman',
    summaryDateIst: '2026-08-29',
    messageCount: 3,
    firstMessageAt: new Date(),
    lastMessageAt: new Date(),
    summaryText: 'Private to the other account.',
  });

  const result = await api('GET', '/api/ai/daily-summaries', { token: mine.token });
  assert.deepEqual(result.body.summaries, [], 'summaries are per-account health data');
});

test('daily summaries: come back newest first', async () => {
  const { aiChatSummaryRepository } = await import('../src/repositories/aiChatSummaryRepository.js');
  const user = await createTestUser();

  for (const date of ['2026-08-27', '2026-08-29', '2026-08-28']) {
    await aiChatSummaryRepository.upsertDailySummary({
      userKey: `user:${user.userId}`,
      role: 'woman',
      summaryDateIst: date,
      messageCount: 2,
      firstMessageAt: new Date(),
      lastMessageAt: new Date(),
      summaryText: `Summary for ${date}.`,
    });
  }

  const result = await api('GET', '/api/ai/daily-summaries', { token: user.token });
  const dates = result.body.summaries.map((s) => s.summaryDateIst);
  assert.deepEqual(dates, ['2026-08-29', '2026-08-28', '2026-08-27']);
});

test('daily summaries: require a signed-in user', async () => {
  const result = await api('GET', '/api/ai/daily-summaries');
  assert.ok(result.status === 401 || result.status === 403, `expected auth failure, got ${result.status}`);
});

test('community: a post with no comments reports zero, not a placeholder', async () => {
  // The app was showing "4" on every post that had no score, because the feed
  // never carried a comment count and the UI invented one.
  const user = await createTestUser();
  const postId = await createFeedPost(user, 'Nobody has replied to this');

  const post = await feedPost(user, postId);
  assert.ok(post, 'the new post should be in the feed');
  assert.equal(post.commentCount, 0);
});

test('community: the feed count matches the comments the post actually has', async () => {
  const author = await createTestUser();
  const replier = await createTestUser();
  const postId = await createFeedPost(author, 'Counting replies');

  for (const text of ['First', 'Second', 'Third']) {
    const res = await api('POST', `/api/posts/${postId}/comments`, {
      token: replier.token,
      body: { text },
    });
    assert.ok(res.status === 200 || res.status === 201, `comment failed: ${res.status}`);
  }

  const post = await feedPost(author, postId);
  assert.equal(post.commentCount, 3);

  // The number on the feed has to equal what the reader sees on opening it,
  // which is the whole point of showing it.
  const listed = await api('GET', `/api/posts/${postId}/comments`, { token: author.token });
  const comments = listed.body.data ?? listed.body.comments ?? listed.body;
  assert.equal((Array.isArray(comments) ? comments : []).length, post.commentCount);
});

test('community: the comment count is independent of the vote score', async () => {
  // The old UI derived comments from score (score ~/ 3), so an upvoted post
  // with no replies claimed to have some.
  const author = await createTestUser();
  const voter = await createTestUser();
  const postId = await createFeedPost(author, 'Popular but unanswered');

  await api('POST', `/api/posts/${postId}/vote`, { token: voter.token, body: { vote: 1 } });

  const post = await feedPost(author, postId);
  assert.equal(post.score, 1);
  assert.equal(post.commentCount, 0, 'votes are not replies');
});

test('life stage: correcting a due date goes through the context endpoint', async () => {
  // A transition to the stage you are already in is refused (ALREADY_IN_STAGE),
  // so the only way to fix a mistyped due date is PUT /life-stage/context.
  // Nothing in the app was calling it.
  const user = await createTestUser();

  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-03-01' } },
  });

  const retry = await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-04-15' } },
  });
  assert.equal(retry.body.errorCode, 'ALREADY_IN_STAGE', 'a re-entry is not how context is corrected');

  const corrected = await api('PUT', '/api/v1/life-stage/context', {
    token: user.token,
    body: { context: { due_date: '2027-04-15' } },
  });
  assert.equal(corrected.status, 200);

  const pregnancy = await api('GET', '/api/v1/pregnancy', { token: user.token });
  assert.equal(pregnancy.body.data.dueDate, '2027-04-15', 'the corrected date must reach the module');
});

test('life stage: correcting context leaves the history alone', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-03-01' } },
  });

  const before = await api('GET', '/api/v1/life-stage/history', { token: user.token });
  await api('PUT', '/api/v1/life-stage/context', {
    token: user.token,
    body: { context: { due_date: '2027-04-15' } },
  });
  const after = await api('GET', '/api/v1/life-stage/history', { token: user.token });

  assert.equal(after.body.data.length, before.body.data.length,
    'fixing a typo is not a life stage change');
});

test('life stage: a real change is still recorded', async () => {
  const user = await createTestUser();

  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'cycle_tracking', confirmed: true, context: { cycle_pattern: 'Regular' } },
  });
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'pregnancy', confirmed: true, context: { due_date: '2027-03-01' } },
  });

  const history = await api('GET', '/api/v1/life-stage/history', { token: user.token });
  assert.ok(
    history.body.data.some((h) => h.toStage === 'pregnancy'),
    'guarding no-ops must not swallow genuine transitions',
  );
});

test('life stage: a transition succeeds when onboarding_answers is null', async () => {
  // Reported from the app:
  //   POST /api/v1/life-stage/transition failed: Cannot create field
  //   'life_stage' in element {onboarding_answers: null}
  //
  // A dotted $set can create a missing path, but not one whose parent is
  // explicitly null -- which is what a user who has never saved an answer has.
  const user = await createTestUser();
  await getDb().collection(user.collection).updateOne(
    { user_id: user.userId },
    { $set: { onboarding_answers: null } },
  );

  const result = await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'cycle_tracking', confirmed: true, context: { cycle_pattern: 'Regular' } },
  });

  assert.equal(result.status, 200, 'a null answers object must not block the transition');
  assert.equal(result.body.data.stage.lifeStage, 'cycle_tracking');

  // The legacy mirror still has to happen, since the prediction suppression
  // rules read user.life_stage rather than the engine's own state.
  const row = await getDb().collection(user.collection).findOne({ user_id: user.userId });
  assert.equal(row.life_stage, 'cycle_tracking');
  assert.equal(row.onboarding_answers.life_stage, 'cycle_tracking');
});

test('life stage: a transition preserves existing onboarding answers', async () => {
  // The mirror rebuilds the answers object, so it must merge rather than replace.
  const user = await createTestUser({
    onboardingAnswers: { preferred_name: 'Aditi', cycle_length: '28' },
  });

  const result = await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'cycle_tracking', confirmed: true, context: { cycle_pattern: 'Regular' } },
  });
  assert.equal(result.status, 200);

  const row = await getDb().collection(user.collection).findOne({ user_id: user.userId });
  assert.equal(row.onboarding_answers.preferred_name, 'Aditi', 'existing answers must survive');
  assert.equal(row.onboarding_answers.cycle_length, '28');
  assert.equal(row.onboarding_answers.life_stage, 'cycle_tracking');
});

test('onboarding: a due date given during onboarding reaches the pregnancy module', async () => {
  // Regression for the gap this closed: onboarding wrote life_stage into the
  // answers but never entered the engine, so branchContext stayed empty and a
  // user who had just given a due date was asked for one again.
  const user = await createTestUser();

  const transition = await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: {
      toStage: 'pregnancy',
      confirmed: true,
      context: { due_date: '2027-03-01' },
    },
  });
  assert.equal(transition.status, 200);

  const pregnancy = await api('GET', '/api/v1/pregnancy', { token: user.token });
  assert.equal(pregnancy.body.state, 'ready', 'the module must not ask again for a date just given');
  assert.equal(pregnancy.body.data.dueDate, '2027-03-01');
  assert.ok(Number.isInteger(pregnancy.body.data.gestationalWeek));
});

test('onboarding: legacy Flutter stage names are accepted by the engine', async () => {
  // The wizard passes Dart enum names such as reproductiveYears.
  const cases = [
    ['reproductiveYears', 'cycle_tracking'],
    ['firstPeriodNotStarted', 'first_period'],
    ['pregnancy', 'pregnancy'],
  ];

  for (const [given, expected] of cases) {
    const user = await createTestUser();
    const body = { toStage: given, confirmed: true, context: {} };
    if (expected === 'pregnancy') body.context = { due_date: '2027-03-01' };

    const result = await api('POST', '/api/v1/life-stage/transition', { token: user.token, body });
    assert.equal(result.status, 200, `${given} should be accepted`);
    assert.equal(result.body.data.stage.lifeStage, expected);
  }
});

test('onboarding: a postpartum birth date reaches the recovery timeline', async () => {
  const user = await createTestUser();
  const birthDate = utcDaysAgoIso(14);

  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'postpartum', confirmed: true, context: { baby_birth_date: birthDate } },
  });

  const postpartum = await api('GET', '/api/v1/postpartum', { token: user.token });
  assert.equal(postpartum.body.state, 'ready');
  assert.equal(postpartum.body.data.daysSinceBirth, 14);
});

test('onboarding: conditions selected during onboarding are stored as self-reported', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'hormonal_health', confirmed: true, context: {} },
  });

  await api('PUT', '/api/v1/conditions', {
    token: user.token,
    body: { conditions: ['PCOS'], diagnosedBy: 'self_reported' },
  });

  const profile = await api('GET', '/api/v1/conditions', { token: user.token });
  assert.equal(profile.body.state, 'ready');
  assert.equal(profile.body.data.diagnosedBy, 'self_reported');
  // Never inferred from logged data (spec §14).
  assert.equal(profile.body.data.inferredFromLogs, false);
});

test('onboarding: completing it makes Home render the chosen branch', async () => {
  const user = await createTestUser();

  const before = await api('GET', '/api/v1/home', { token: user.token });
  assert.equal(before.body.data.onboardingRequired, true);

  await api('POST', '/api/v1/life-stage/transition', {
    token: user.token,
    body: { toStage: 'cycle_tracking', confirmed: true, context: { cycle_pattern: 'Regular' } },
  });

  const after = await api('GET', '/api/v1/home', { token: user.token });
  assert.equal(after.body.data.onboardingRequired, false);
  assert.equal(after.body.data.lifeStage, 'cycle_tracking');
  assert.ok(after.body.data.modules.some((m) => m.moduleId === 'hero_tracker'));

  // And the transition is recorded, so history is preserved (spec §23).
  const history = await api('GET', '/api/v1/life-stage/history', { token: user.token });
  assert.ok(history.body.data.some((h) => h.toStage === 'cycle_tracking'));
});

/* ================================================================== *
 * Push devices and redaction (spec §19, §24)
 * ================================================================== */

test('push: a device registers once and its token is never returned', async () => {
  const user = await createTestUser();

  const first = await api('POST', '/api/v1/notifications/devices', {
    token: user.token,
    body: { token: 'device-token-abc', platform: 'android', appVersion: '1.2.3' },
  });
  assert.equal(first.status, 201);

  // Re-registering the same device does not accumulate duplicates.
  await api('POST', '/api/v1/notifications/devices', {
    token: user.token,
    body: { token: 'device-token-abc', platform: 'android' },
  });

  const devices = await api('GET', '/api/v1/notifications/devices', { token: user.token });
  assert.equal(devices.body.data.length, 1);
  assert.equal(devices.body.data[0].platform, 'android');
  // The token is a sending credential, so it is not echoed back.
  assert.equal(devices.body.data[0].token, undefined);
});

test('push: an unknown platform is rejected', async () => {
  const user = await createTestUser();
  const result = await api('POST', '/api/v1/notifications/devices', {
    token: user.token,
    body: { token: 'abc', platform: 'blackberry' },
  });
  assert.equal(result.status, 400);
  assert.equal(result.body.errorCode, 'VALIDATION_FAILED');
});

test('push: unregistering removes the device, so notifications stop reaching it', async () => {
  const user = await createTestUser();
  await api('POST', '/api/v1/notifications/devices', {
    token: user.token,
    body: { token: 'device-to-remove', platform: 'ios' },
  });

  await api('DELETE', '/api/v1/notifications/devices', {
    token: user.token,
    body: { token: 'device-to-remove' },
  });

  const devices = await api('GET', '/api/v1/notifications/devices', { token: user.token });
  assert.equal(devices.body.data.length, 0);
});

test('push: a sensitive notification is redacted before it could reach a lock screen', async () => {
  // This is the property that has to be right before a provider is connected:
  // once notifications actually reach a lock screen, sending the wrong text is
  // not recoverable.
  const { buildPushPayload } = await import('../src/services/pushDeliveryService.js');
  const { defaultNotificationPreferences } = await import('../src/domain/notifications.js');

  const built = buildPushPayload({
    notification: {
      notificationId: 'n1',
      category: 'period_reminder',
      title: 'Your period may start tomorrow',
      body: 'Based on your logged cycles.',
    },
    preferences: defaultNotificationPreferences(),
  });

  assert.equal(built.deliverable, true);
  assert.equal(built.payload.title, 'Blushy');
  assert.ok(!built.payload.body.toLowerCase().includes('period'));
  // The category still travels in the data payload so the app can route it.
  assert.equal(built.payload.data.category, 'period_reminder');
});

test('push: a non-sensitive notification keeps its text', async () => {
  const { buildPushPayload } = await import('../src/services/pushDeliveryService.js');
  const { defaultNotificationPreferences } = await import('../src/domain/notifications.js');

  const built = buildPushPayload({
    notification: { notificationId: 'n2', category: 'community', title: 'New reply', body: 'Someone replied.' },
    preferences: defaultNotificationPreferences(),
  });

  assert.equal(built.payload.title, 'New reply');
  assert.equal(built.payload.body, 'Someone replied.');
});

test('push: with no provider configured, delivery reports failure rather than claiming success', async () => {
  const { deliver } = await import('../src/services/pushDeliveryService.js');
  const user = await createTestUser();

  await api('POST', '/api/v1/notifications/devices', {
    token: user.token,
    body: { token: 'device-xyz', platform: 'android' },
  });

  const result = await deliver(user.userId, {
    notificationId: 'n3',
    category: 'community',
    title: 'New reply',
    body: 'Someone replied.',
  });

  assert.equal(result.delivered, false);
  assert.equal(result.reason, 'no_provider_configured');
  // What it would have sent is available for inspection, but nothing is
  // reported as delivered.
  assert.ok(result.wouldHaveSent);

  const log = await api('GET', '/api/v1/notifications/delivery-log', { token: user.token });
  assert.ok(log.body.data.some((entry) => entry.reason === 'no_provider_configured' && entry.delivered === false));
});

/* ------------------------------------------------------------------ *
 * FCM transport (spec §19, §24)
 * ------------------------------------------------------------------ */

/** A throwaway service account, so the JWT signing path really runs. */
function fakeServiceAccount() {
  const { privateKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    publicKeyEncoding: { type: 'spki', format: 'pem' },
  });
  return JSON.stringify({
    project_id: 'blushy-test',
    client_email: 'push@blushy-test.iam.gserviceaccount.com',
    private_key: privateKey,
  });
}

/** Answers the OAuth exchange, then hands each send to `onSend`. */
function fcmStub(onSend) {
  return async (url, init) => {
    if (String(url).includes('oauth2.googleapis.com')) {
      return {
        ok: true,
        status: 200,
        json: async () => ({ access_token: 'test-access-token', expires_in: 3600 }),
        text: async () => '',
      };
    }
    return onSend(String(url), JSON.parse(init.body));
  };
}

const FCM_OK = {
  ok: true,
  status: 200,
  json: async () => ({ name: 'projects/blushy-test/messages/1' }),
  text: async () => '',
};

function fcmError(status, errorCode) {
  return {
    ok: false,
    status,
    json: async () => ({ error: { status: errorCode, details: [{ errorCode }] } }),
    text: async () => errorCode,
  };
}

async function withFcm(onSend, run) {
  const fcm = await import('../src/services/fcmClient.js');
  const previous = process.env.FCM_SERVICE_ACCOUNT_JSON;
  process.env.FCM_SERVICE_ACCOUNT_JSON = fakeServiceAccount();
  fcm.__setFetchForTests(fcmStub(onSend));
  fcm.__resetTokenCacheForTests();
  try {
    return await run();
  } finally {
    fcm.__setFetchForTests(null);
    fcm.__resetTokenCacheForTests();
    if (previous === undefined) delete process.env.FCM_SERVICE_ACCOUNT_JSON;
    else process.env.FCM_SERVICE_ACCOUNT_JSON = previous;
  }
}

async function userWithDevice(deviceToken = 'fcm-token-1') {
  const user = await createTestUser();
  await api('POST', '/api/v1/notifications/devices', {
    token: user.token,
    body: { token: deviceToken, platform: 'android' },
  });
  return user;
}

test('push: with a provider configured, a notification is actually sent', async () => {
  const { deliver } = await import('../src/services/pushDeliveryService.js');
  const user = await userWithDevice();
  const sent = [];

  const result = await withFcm(
    (_url, body) => { sent.push(body); return FCM_OK; },
    () => deliver(user.userId, {
      notificationId: 'n-send',
      category: 'community',
      title: 'New reply',
      body: 'Someone replied.',
    }),
  );

  assert.equal(result.delivered, true);
  assert.equal(result.deliveredCount, 1);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].message.token, 'fcm-token-1');
  assert.equal(sent[0].message.notification.title, 'New reply');

  const log = await api('GET', '/api/v1/notifications/delivery-log', { token: user.token });
  assert.ok(log.body.data.some((entry) => entry.delivered === true && entry.reason === 'sent'));
});

test('push: what reaches the transport is the redacted text, never the subject', async () => {
  // The last line of defence. Everything upstream can be right and this still
  // has to be, because a lock screen is not recoverable.
  const { deliver } = await import('../src/services/pushDeliveryService.js');
  const user = await userWithDevice('fcm-token-redact');
  const sent = [];

  await withFcm(
    (_url, body) => { sent.push(body); return FCM_OK; },
    () => deliver(user.userId, {
      notificationId: 'n-redact',
      category: 'period_reminder',
      title: 'Your period may start tomorrow',
      body: 'Based on your logged cycles.',
    }),
  );

  assert.equal(sent.length, 1);
  const message = sent[0].message;
  assert.equal(message.notification.title, 'Blushy');
  assert.ok(!JSON.stringify(message.notification).toLowerCase().includes('period'));
  // The category still travels in data so the app can route the tap.
  assert.equal(message.data.category, 'period_reminder');
  // FCM rejects non-string data values outright.
  for (const value of Object.values(message.data)) {
    assert.equal(typeof value, 'string');
  }
});

test('push: a token FCM calls dead is removed, so it is not retried forever', async () => {
  const { deliver } = await import('../src/services/pushDeliveryService.js');
  const user = await userWithDevice('fcm-token-dead');

  const result = await withFcm(
    () => fcmError(404, 'UNREGISTERED'),
    () => deliver(user.userId, {
      notificationId: 'n-dead',
      category: 'community',
      title: 'New reply',
      body: 'Someone replied.',
    }),
  );

  assert.equal(result.delivered, false);
  assert.equal(result.prunedCount, 1);

  const devices = await api('GET', '/api/v1/notifications/devices', { token: user.token });
  assert.equal(devices.body.data.length, 0, 'an unregistered token must not survive');
});

test('push: a transient failure keeps the device registered', async () => {
  const { deliver } = await import('../src/services/pushDeliveryService.js');
  const user = await userWithDevice('fcm-token-flaky');

  const result = await withFcm(
    () => fcmError(503, 'UNAVAILABLE'),
    () => deliver(user.userId, {
      notificationId: 'n-flaky',
      category: 'community',
      title: 'New reply',
      body: 'Someone replied.',
    }),
  );

  assert.equal(result.delivered, false);
  assert.equal(result.prunedCount, 0);

  const devices = await api('GET', '/api/v1/notifications/devices', { token: user.token });
  assert.equal(devices.body.data.length, 1, 'a 503 is not a reason to forget the device');
});

test('push: an auth failure is reported as such, not as a delivery', async () => {
  const { deliver } = await import('../src/services/pushDeliveryService.js');
  const fcm = await import('../src/services/fcmClient.js');
  const user = await userWithDevice('fcm-token-auth');

  const previous = process.env.FCM_SERVICE_ACCOUNT_JSON;
  process.env.FCM_SERVICE_ACCOUNT_JSON = fakeServiceAccount();
  fcm.__resetTokenCacheForTests();
  fcm.__setFetchForTests(async () => ({
    ok: false, status: 401, json: async () => ({}), text: async () => 'invalid_grant',
  }));
  try {
    const result = await deliver(user.userId, {
      notificationId: 'n-auth',
      category: 'community',
      title: 'New reply',
      body: 'Someone replied.',
    });
    assert.equal(result.delivered, false);
    assert.equal(result.reason, 'provider_auth_failed');
  } finally {
    fcm.__setFetchForTests(null);
    fcm.__resetTokenCacheForTests();
    if (previous === undefined) delete process.env.FCM_SERVICE_ACCOUNT_JSON;
    else process.env.FCM_SERVICE_ACCOUNT_JSON = previous;
  }
});

test('push: a half-filled service account counts as no provider, not a failure', async () => {
  const { deliver } = await import('../src/services/pushDeliveryService.js');
  const user = await userWithDevice('fcm-token-bad-sa');

  const previous = process.env.FCM_SERVICE_ACCOUNT_JSON;
  process.env.FCM_SERVICE_ACCOUNT_JSON = '{"project_id":"only-this"}';
  try {
    const result = await deliver(user.userId, {
      notificationId: 'n-bad-sa',
      category: 'community',
      title: 'New reply',
      body: 'Someone replied.',
    });
    assert.equal(result.reason, 'no_provider_configured');
  } finally {
    if (previous === undefined) delete process.env.FCM_SERVICE_ACCOUNT_JSON;
    else process.env.FCM_SERVICE_ACCOUNT_JSON = previous;
  }
});

/* ------------------------------------------------------------------ *
 * Push dispatch worker (spec §19, §24)
 * ------------------------------------------------------------------ */

test('dispatch: a due notification is delivered and marked delivered', async () => {
  // Before this worker existed, scheduleNotification wrote rows that nothing
  // ever picked up, so no notification could be sent at all.
  const { runPushDispatchOnce } = await import('../src/services/pushDispatchService.js');
  const { scheduleNotification } = await import('../src/repositories/notificationRepository.js');
  const user = await userWithDevice('fcm-dispatch-1');

  await scheduleNotification(user.userId, {
    category: 'community',
    title: 'New reply',
    body: 'Someone replied.',
    entityType: 'post',
    entityId: 'p1',
  });

  const summary = await withFcm(() => FCM_OK, () => runPushDispatchOnce());
  assert.ok(summary.delivered >= 1);

  const listed = await api('GET', '/api/v1/notifications', { token: user.token });
  const row = listed.body.data.find((n) => n.category === 'community');
  assert.ok(row, 'the notification should still be listed');
  assert.equal(row.status, 'delivered');
});

test('dispatch: a notification scheduled for later is left alone', async () => {
  const { runPushDispatchOnce } = await import('../src/services/pushDispatchService.js');
  const { scheduleNotification } = await import('../src/repositories/notificationRepository.js');
  const user = await userWithDevice('fcm-dispatch-future');

  await scheduleNotification(user.userId, {
    category: 'community',
    title: 'Later',
    body: 'Not yet.',
    entityType: 'post',
    entityId: 'p-future',
    scheduledFor: new Date(Date.now() + 3600_000),
  });

  const sent = [];
  await withFcm(
    (_url, body) => { sent.push(body); return FCM_OK; },
    () => runPushDispatchOnce(),
  );

  assert.equal(
    sent.filter((m) => m.message.token === 'fcm-dispatch-future').length,
    0,
    'a future notification must not be sent early',
  );
});

test('dispatch: a category the user turned off is cancelled, not retried', async () => {
  const { runPushDispatchOnce } = await import('../src/services/pushDispatchService.js');
  const { scheduleNotification } = await import('../src/repositories/notificationRepository.js');
  const user = await userWithDevice('fcm-dispatch-off');

  await scheduleNotification(user.userId, {
    category: 'community',
    title: 'New reply',
    body: 'Someone replied.',
    entityType: 'post',
    entityId: 'p-off',
  });

  // Turned off after scheduling, which is exactly when the queue can go stale.
  await api('PATCH', '/api/v1/notifications/preferences', {
    token: user.token,
    body: { categories: { community: false } },
  });

  const summary = await withFcm(() => FCM_OK, () => runPushDispatchOnce());
  assert.ok(summary.cancelled >= 1, 'a disabled category can never succeed, so it is not retried');
});

test('dispatch: repeated failures stop after the attempt limit', async () => {
  const { runPushDispatchOnce } = await import('../src/services/pushDispatchService.js');
  const {
    scheduleNotification,
    MAX_DELIVERY_ATTEMPTS,
  } = await import('../src/repositories/notificationRepository.js');
  const user = await userWithDevice('fcm-dispatch-fail');

  await scheduleNotification(user.userId, {
    category: 'community',
    title: 'New reply',
    body: 'Someone replied.',
    entityType: 'post',
    entityId: 'p-fail',
  });

  // A transient failure every time: the row must not be retried forever.
  for (let i = 0; i < MAX_DELIVERY_ATTEMPTS + 1; i++) {
    await withFcm(() => fcmError(503, 'UNAVAILABLE'), () => runPushDispatchOnce());
  }

  const after = await withFcm(() => fcmError(503, 'UNAVAILABLE'), () => runPushDispatchOnce());
  const stillQueued = after.considered;
  assert.equal(stillQueued, 0, 'an undeliverable notification must eventually be abandoned');
});

test('dispatch: with no transport configured, nothing is marked delivered', async () => {
  const { runPushDispatchOnce } = await import('../src/services/pushDispatchService.js');
  const { scheduleNotification } = await import('../src/repositories/notificationRepository.js');
  const user = await userWithDevice('fcm-dispatch-noprovider');

  await scheduleNotification(user.userId, {
    category: 'community',
    title: 'New reply',
    body: 'Someone replied.',
    entityType: 'post',
    entityId: 'p-noprov',
  });

  const previous = process.env.FCM_SERVICE_ACCOUNT_JSON;
  delete process.env.FCM_SERVICE_ACCOUNT_JSON;
  try {
    const summary = await runPushDispatchOnce();
    assert.equal(summary.delivered, 0, 'an unconfigured deployment must not report deliveries');
  } finally {
    if (previous !== undefined) process.env.FCM_SERVICE_ACCOUNT_JSON = previous;
  }
});

test('push: delivery is not attempted for a category the user turned off', async () => {
  const { deliver } = await import('../src/services/pushDeliveryService.js');
  const user = await createTestUser();

  await api('POST', '/api/v1/notifications/devices', {
    token: user.token,
    body: { token: 'device-off', platform: 'web' },
  });
  await api('PATCH', '/api/v1/notifications/preferences', {
    token: user.token,
    body: { categories: { community: false } },
  });

  const result = await deliver(user.userId, {
    notificationId: 'n4',
    category: 'community',
    title: 'New reply',
    body: 'Someone replied.',
  });

  assert.equal(result.delivered, false);
  assert.equal(result.reason, 'category_disabled');
});
