import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';

import { randomUUID } from 'node:crypto';

import { startTestServer, stopTestServer, getDb } from './helpers/testServer.js';
import { calculatePeriodPredictions } from '../src/services/periodPredictionService.js';

/**
 * Her partner has to be looking at her cycle, not at a reconstruction of it.
 *
 * Two things were wrong, and both showed up as the ring on his screen
 * disagreeing with the ring on hers.
 *
 * **The day.** `partnerSafeService` asked for her cycle with
 * `referenceDate.toISOString().slice(0, 10)` -- the UTC calendar date -- which
 * overrode the timezone handling this service already does. Her phone counts
 * the day locally, so anywhere east of UTC he was a day behind for part of
 * every day. Reported from India: she read Day 16, he read Day 15.
 *
 * **The shape.** Her cycle length was computed here, used for every other
 * number, and never reported. Anything drawing a ring from this block had to
 * assume 28 days -- a shape belonging to nobody, under a heading with her name
 * on it.
 */

before(async () => { await startTestServer(); });
after(async () => { await stopTestServer(); });

let seq = 0;
const nextUser = () => `cycle_parity_${Date.now()}_${seq++}`;

/// Three period starts 30 days apart, so the computed length is 30 and not the
/// 28 a default would produce.
async function seedCycle(userId, startDates) {
  // The prediction reads `user_period_logs_woman` via `getPeriodEntries`, not
  // the health-event stream, so that is what has to be seeded.
  for (const date of startDates) {
    await getDb().collection('user_period_logs_woman').insertOne({
      _id: randomUUID(),
      user_id: userId,
      period_start_date: date,
      period_end_date: null,
      source: 'manual_tracker',
      created_at: new Date(),
      updated_at: new Date(),
    });
  }
  await getDb().collection('users_woman').updateOne(
    { user_id: userId },
    {
      $set: {
        user_id: userId,
        role: 'woman',
        timezone: 'Asia/Kolkata',
        life_stage: 'cycle_tracking',
        onboarding_answers: { life_stage: 'cycle_tracking' },
      },
    },
    { upsert: true },
  );
  await getDb().collection('user_life_stage').updateOne(
    { user_id: userId },
    { $set: { user_id: userId, life_stage: 'cycle_tracking', timezone: 'Asia/Kolkata' } },
    { upsert: true },
  );
}

test('the cycle length it computes is the one it reports', async () => {
  const userId = nextUser();
  await seedCycle(userId, ['2026-07-02', '2026-08-01', '2026-08-31']);

  const result = await calculatePeriodPredictions(userId, { referenceDate: '2026-09-15' });

  assert.equal(result.hasData, true);
  assert.equal(
    result.currentCycle.cycleLengthDays,
    30,
    'the 30-day gap she actually logged, not a 28-day default',
  );
});

test('and the day it reports is measured against that same length', async () => {
  const userId = nextUser();
  await seedCycle(userId, ['2026-07-02', '2026-08-01', '2026-08-31']);

  const result = await calculatePeriodPredictions(userId, { referenceDate: '2026-09-15' });

  // 2026-08-31 is Day 1, so 2026-09-15 is Day 16 -- the number she sees.
  assert.equal(result.currentCycle.currentCycleDay, 16);
});

test('a timezone ahead of UTC is counted in her zone, not ours', async () => {
  // The failure was time-of-day dependent, which is why it looked intermittent:
  // in Asia/Kolkata every moment before 05:30 local is still "yesterday" in
  // UTC. Asking in her zone has to give her day.
  const userId = nextUser();
  await seedCycle(userId, ['2026-08-31']);

  const inHerZone = await calculatePeriodPredictions(userId, { timezone: 'Asia/Kolkata' });
  const utcDate = new Date().toISOString().slice(0, 10);
  const asUtcDate = await calculatePeriodPredictions(userId, { referenceDate: utcDate });

  assert.equal(
    inHerZone.todayDate,
    new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(new Date()),
    'today is the date it is in her zone',
  );

  // Whenever the two calendars disagree, hers is the one that must win. The
  // difference is never more than a day.
  const diff = Math.abs(
    (new Date(inHerZone.todayDate) - new Date(asUtcDate.todayDate)) / 86400000,
  );
  assert.ok(diff <= 1, `unexpected gap of ${diff} days`);
  assert.equal(
    inHerZone.currentCycle.currentCycleDay - asUtcDate.currentCycle.currentCycleDay,
    Math.round((new Date(inHerZone.todayDate) - new Date(asUtcDate.todayDate)) / 86400000),
    'the day count moves exactly with the calendar it was asked about',
  );
});

test('the partner-safe path asks in her timezone and passes no UTC date', async () => {
  // Pinned on the source, because the bug was one argument: an explicit
  // reference date silently outranks the timezone logic underneath it.
  const { readFileSync } = await import('node:fs');
  const source = readFileSync('src/services/partnerSafeService.js', 'utf8');

  const call = source.slice(
    source.indexOf('const cycle = await getCycleState('),
    source.indexOf(';', source.indexOf('const cycle = await getCycleState(')),
  );

  assert.ok(call.includes('timezone'), 'her zone is passed');
  assert.ok(
    !call.includes('toISOString'),
    'a UTC calendar date here overrides the timezone handling underneath',
  );
});

test('the lengths his ring needs travel with the phase he already sees', async () => {
  // Under the same `cycle.phase` grant, not a new one: they are cycle facts,
  // no more revealing than the phase and day beside them.
  const { readFileSync } = await import('node:fs');
  const source = readFileSync('src/services/partnerSafeService.js', 'utf8');

  const block = source.slice(
    source.indexOf('context.cyclePhase = {'),
    source.indexOf('};', source.indexOf('context.cyclePhase = {')),
  );

  assert.ok(block.includes('cycleLengthDays'), block);
  assert.ok(block.includes('periodLengthDays'), block);
});

test('only the symptom groups a partner may see reach him', async () => {
  // Five categories in symptom_categories.dart write `symptom_logged`:
  // Symptoms, Intimate health, Vaginal discharge, Hair and skin, and
  // Digestion. Filtering on the event type handed her partner all five under
  // a switch labelled "Symptoms" -- "Vaginal itching" travelled to him on the
  // same permission as "Cramps".
  //
  // Two groups are open: her Symptoms section, and Digestion, which is
  // ordinary enough to be worth a partner knowing. The other three stay shut.
  const { readFileSync } = await import('node:fs');
  const source = readFileSync('src/services/partnerSafeService.js', 'utf8');

  const list = source.slice(
    source.indexOf('const PARTNER_VISIBLE_SYMPTOMS'),
    source.indexOf(']);', source.indexOf('const PARTNER_VISIBLE_SYMPTOMS')),
  );

  const allowedGroups = {
    symptoms: ['cramps', 'headache', 'tender breasts', 'backache', 'abdominal pain',
      'acne', 'fatigue', 'cravings', 'insomnia', 'swelling', 'dry skin', 'dry eyes'],
    digestion: ['nausea', 'bloating', 'constipation', 'diarrhea'],
  };
  for (const [group, names] of Object.entries(allowedGroups)) {
    for (const name of names) {
      assert.ok(list.includes(`'${name}'`), `${name} (${group}) should be visible`);
    }
  }

  for (const withheld of [
    'vaginal itching',
    'vaginal dryness',
    'unusual',
    'clumpy white',
    'grey',
    'hair thinning',
    'excess facial hair',
  ]) {
    assert.ok(!list.includes(`'${withheld}'`), `${withheld} must not be on this list`);
  }

  // An allowlist, not a blocklist: a new intimate-health option added later
  // must not reach a partner because nobody remembered to exclude it.
  const filter = source.slice(
    source.indexOf("filter((event) => event.eventType === 'symptom_logged')"),
    source.indexOf('.slice(0, 5)', source.indexOf("filter((event) => event.eventType === 'symptom_logged')")),
  );
  assert.ok(filter.includes('PARTNER_VISIBLE_SYMPTOMS.has'), filter);
});

test('a stage without predictions still shares its cycle day', async () => {
  // Reported as: she turned cycle sharing on and her partner still read
  // "Private".
  //
  // `contractStateFor` returns INSUFFICIENT_DATA whenever a branch does not
  // support predictions, and first period and perimenopause are two such
  // branches -- both with `cycleTracking: true`, both showing her a day and a
  // phase on her own home screen. The partner context read the phase only on
  // READY, so those two stages could never share a cycle, whatever she
  // permitted.
  const { readFileSync } = await import('node:fs');
  const source = readFileSync('src/services/partnerSafeService.js', 'utf8');

  const gate = source.slice(
    source.indexOf('const hasDay ='),
    source.indexOf('context.cyclePhase = {'),
  );

  assert.ok(gate.includes('INSUFFICIENT_DATA'), gate);
  assert.ok(gate.includes('currentCycleDay != null'),
    'a state alone is not enough -- there has to be a day in it');

  // And the forecast stays gated on its own, so those branches get the ring
  // and no countdown rather than an invented one.
  const window = source.slice(
    source.indexOf('context.cyclePhase = {'),
    source.indexOf('capabilities.fertility'),
  );
  assert.ok(window.includes('cycle.data.prediction?.nextPeriodStartDate'), window);
});

test('the two stages that were blanked declare tracking without predictions', async () => {
  // If this ever changes, the fix above is aimed at the wrong thing.
  const { getBranchCapabilities } = await import('../src/domain/lifeStages.js');

  for (const stage of ['first_period', 'perimenopause']) {
    const caps = getBranchCapabilities(stage);
    assert.equal(caps.cycleTracking, true, `${stage} tracks cycles`);
    assert.equal(caps.cyclePredictions, false, `${stage} does not predict`);
  }
});
