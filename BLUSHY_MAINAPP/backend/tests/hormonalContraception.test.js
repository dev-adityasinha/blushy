import test from 'node:test';
import assert from 'node:assert/strict';

import { calculatePeriodPredictions } from '../src/services/periodPredictionService.js';
import { closeDb, db } from '../src/utils/db.js';

/**
 * Hormonal contraception withholds the fertile window.
 *
 * The signup wizard asks "Are you currently using hormonal contraception?"
 * and the stage questionnaire asks which method, both writing
 * `contraception_choice`. Nothing read it: someone on an implant was shown an
 * estimated ovulation date and a fertile window calculated as though she were
 * cycling, which is the one thing this app must not guess at.
 *
 * The two screens store different vocabularies for the same key -- Yes/No
 * versus the method name -- so both are covered here. Handling one and not the
 * other would leave the answer ignored for everyone who arrived the other way,
 * and the wizard is the one every new account goes through.
 */
const REFERENCE = '2026-08-31';

async function makeUser(suffix, contraception) {
  const uid = `test_contra_${suffix}`;
  await db.collection('users_woman').insertOne({
    user_id: uid,
    role: 'woman',
    timezone: 'Asia/Kolkata',
    created_at: new Date('2026-04-01'),
    life_stage: 'reproductiveYears',
    onboarding_answers: {
      life_stage: 'reproductiveYears',
      last_period: '2026-08-20',
      ...(contraception === null ? {} : { contraception_choice: contraception }),
    },
  });
  return uid;
}

test('the fertile window is withheld on hormonal contraception', async (t) => {
  const created = [];
  t.after(async () => {
    await db.collection('users_woman').deleteMany({ user_id: { $in: created } });
  });

  // Both spellings a screen can store for "yes, hormonal".
  const hormonal = ['Yes', 'Birth control pill', 'Hormonal IUD / Implant'];

  for (const [i, answer] of hormonal.entries()) {
    const uid = await makeUser(`h${i}_${Date.now()}`, answer);
    created.push(uid);

    const r = await calculatePeriodPredictions(uid, { referenceDate: REFERENCE });
    const p = r.prediction ?? {};

    assert.equal(p.estimatedOvulationDate, null, `${answer}: ovulation date`);
    assert.equal(p.fertileWindowStart, null, `${answer}: fertile window start`);
    assert.equal(p.fertileWindowEnd, null, `${answer}: fertile window end`);
    assert.equal(p.isOvulationSupported, false, `${answer}: isOvulationSupported`);
    assert.equal(
      r.dataSufficiency?.confidenceLevel,
      'low_hormonal_contraception',
      `${answer}: confidence`,
    );
  }
});

test('everyone else still gets one', async (t) => {
  const created = [];
  t.after(async () => {
    await db.collection('users_woman').deleteMany({ user_id: { $in: created } });
  });

  // "No" and the copper coil are not hormonal, and an unanswered question must
  // not be read as a yes.
  const notHormonal = ['No', 'Non-hormonal IUD (Copper)', 'Prefer not to say', null];

  for (const [i, answer] of notHormonal.entries()) {
    const uid = await makeUser(`n${i}_${Date.now()}`, answer);
    created.push(uid);

    const r = await calculatePeriodPredictions(uid, { referenceDate: REFERENCE });
    const p = r.prediction ?? {};

    const label = answer === null ? '(unanswered)' : answer;
    assert.notEqual(
      r.dataSufficiency?.confidenceLevel,
      'low_hormonal_contraception',
      `${label}: must not be treated as hormonal`,
    );
    assert.equal(p.isOvulationSupported, true, `${label}: isOvulationSupported`);
    assert.ok(p.estimatedOvulationDate, `${label}: should still have an ovulation date`);
  }
});

test.after(async () => {
  await closeDb();
});
