import test from 'node:test';
import assert from 'node:assert/strict';

import { calculatePeriodPredictions } from '../src/services/periodPredictionService.js';
import { LIFE_STAGES, getBranchCapabilities } from '../src/domain/lifeStages.js';
import { closeDb, db } from '../src/utils/db.js';

/**
 * Cycle tracking is suppressed exactly where the branch does not do it.
 *
 * The rule was a hardcoded list compared against the raw stage string, and it
 * disagreed with `BRANCH_CAPABILITIES` both ways: `everyday_wellness` and
 * `exploring` declare `cycleTracking: false` and were still given a full
 * countdown — someone who opted out of cycle tracking was shown "Day 29,
 * Late / Overdue Cycle" — while an account stored as `firstPeriodNotStarted`
 * was suppressed and the same stage stored as `first_period` was not.
 *
 * Found by running every stage through the pipeline with generated data.
 */
async function makeUser(stage, suffix) {
  const uid = `test_supp_${suffix}`;
  await db.collection('users_woman').insertOne({
    user_id: uid, role: 'woman', timezone: 'Asia/Kolkata',
    created_at: new Date('2026-04-01'), life_stage: stage,
    onboarding_answers: { life_stage: stage, last_period: '2026-08-03' },
  });
  return uid;
}

test('suppression matches what each branch declares', async (t) => {
  const created = [];
  t.after(async () => {
    try {
      await db.collection('users_woman').deleteMany({ user_id: { $in: created } });
    } catch (_) {}
  });

  for (const stage of Object.values(LIFE_STAGES)) {
    const uid = await makeUser(stage, `${stage}_${Date.now()}`);
    created.push(uid);

    const result = await calculatePeriodPredictions(uid, { referenceDate: '2026-08-31' });
    const expected = !getBranchCapabilities(stage).cycleTracking;

    assert.equal(result.trackingSuppressed === true, expected,
      `${stage}: cycleTracking=${!expected} but suppressed=${result.trackingSuppressed}`);
  }
});

test('a first period that has not started is still suppressed', async (t) => {
  const created = [];
  t.after(async () => {
    try {
      await db.collection('users_woman').deleteMany({ user_id: { $in: created } });
    } catch (_) {}
  });

  // The aliases fold "not started" and "started" into one stage, so the
  // capability alone cannot tell them apart. A countdown for someone who has
  // not had a period yet would be meaningless.
  for (const spelling of ['firstPeriodNotStarted', 'first_period_not_started']) {
    const uid = await makeUser(spelling, `nps_${spelling}_${Date.now()}`);
    created.push(uid);

    const result = await calculatePeriodPredictions(uid, { referenceDate: '2026-08-31' });
    assert.equal(result.trackingSuppressed, true, `${spelling} must be suppressed`);
  }

  // Whereas someone whose periods have started does get a cycle.
  const started = await makeUser('firstPeriodStarted', `ps_${Date.now()}`);
  created.push(started);
  const result = await calculatePeriodPredictions(started, { referenceDate: '2026-08-31' });
  assert.equal(result.trackingSuppressed, false);
});

test('the Flutter enum names resolve to the right branch', async (t) => {
  const created = [];
  t.after(async () => {
    try {
      await db.collection('users_woman').deleteMany({ user_id: { $in: created } });
    } catch (_) {}
  });

  // The app sends its own enum names verbatim, so these are what real accounts
  // actually hold.
  for (const [spelling, suppressed] of [
    ['reproductiveYears', false],
    ['tryingToConceive', false],
    ['pregnancy', true],
    ['postpartum', true],
    ['menopause', true],
  ]) {
    const uid = await makeUser(spelling, `enum_${spelling}_${Date.now()}`);
    created.push(uid);

    const result = await calculatePeriodPredictions(uid, { referenceDate: '2026-08-31' });
    assert.equal(result.trackingSuppressed === true, suppressed, `${spelling}`);
  }
});

test('teardown', async () => {
  await closeDb();
});
