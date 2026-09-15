import test from 'node:test';
import assert from 'node:assert/strict';

import { evaluateRedFlags } from '../src/domain/safety.js';

/**
 * The names three cards record under decide whether an emergency alert fires.
 *
 * `evaluateRedFlags` matches by substring against clinically reviewed rules,
 * and both rules involved here are ungated -- `minSeverity: null` -- so a match
 * raises an emergency escalation on its own. The names are therefore not a
 * naming preference; they are the behaviour.
 *
 * This pins all three, in both directions: what must fire, and what must not.
 * Changing a name without changing this test is how a postpartum card starts
 * telling well people to call emergency services.
 */
const fires = (lifeStage, symptom, gestationalWeek = null, severity = 1) =>
  evaluateRedFlags({
    lifeStage,
    symptoms: [{ symptom, severity }],
    gestationalWeek,
  });

test('quiet fetal movement raises the reviewed RCOG flag', () => {
  // rf_pg_reduced_movements, RCOG Green-top Guideline No. 57. The rule existed
  // and nothing could trigger it, because the card recorded nothing at all.
  const r = fires('pregnancy', 'reduced movement', 28);
  assert.equal(r.triggered, true);
  assert.equal(r.level, 'emergency');
  assert.equal(r.rules[0].ruleId, 'rf_pg_reduced_movements');
});

test('the rule keeps its own gestational gate', () => {
  // The rule applies from 24 weeks. Recording the symptom earlier must not
  // manufacture an alert the rule does not make.
  assert.equal(fires('pregnancy', 'reduced movement', 20).triggered, false);
});

test('normal movement raises nothing', () => {
  // Matching is by substring, so a name for the ordinary answer has to be
  // checked rather than assumed -- this is recorded on good days too.
  assert.equal(fires('pregnancy', 'fetal movements normal', 28).triggered, false);
});

test('contractions raise nothing on their own', () => {
  // Deliberate. The rules that exist cover abdominal pain and severe cramping;
  // preterm labour has none. Naming this into the pain rule would be inventing
  // a clinical threshold in a mapper. The data is recorded so a reviewed rule
  // can be written against it.
  assert.equal(fires('pregnancy', 'contractions', 28, 8).triggered, false);
});

test('postpartum bleeding is recorded as lochia, and lochia raises nothing', () => {
  assert.equal(fires('postpartum', 'lochia', null, 2).triggered, false);
});

test('and this is why it is not called bleeding', () => {
  // rf_pp_heavy_bleeding matches the bare word "bleeding" with no severity
  // gate. Any symptom name containing it raises an emergency escalation --
  // including the one meaning there is none.
  for (const name of ['postpartum bleeding', 'bleeding none', 'light bleeding']) {
    const r = fires('postpartum', name);
    assert.equal(r.triggered, true, `${name} should demonstrate the hazard`);
    assert.equal(r.level, 'emergency');
    assert.equal(r.rules[0].ruleId, 'rf_pp_heavy_bleeding');
  }

  // If this ever stops being true the rule has been rewritten, and the choice
  // to record lochia under its own name should be revisited rather than left
  // in place with a comment explaining a hazard that no longer exists.
});
