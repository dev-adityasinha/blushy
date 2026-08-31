import test from 'node:test';
import assert from 'node:assert/strict';

// Only the pure exports: the service's AI path is exercised through them, and
// importing anything database-backed would hold the process open.
import {
  FOCUS_AREAS,
  deriveFocusAreas,
  reconcileFocusAreas,
} from '../src/services/onboardingAnalysisService.js';

test('the focus areas come from what she actually answered', () => {
  const ttc = deriveFocusAreas({
    life_stage: 'tryingToConceive',
    ttc_tracking_method: 'Basal body temperature',
    symptoms: ['Cramps', 'Anxiety'],
  });

  assert.ok(ttc.includes('fertility'), 'BBT is a fertility answer');
  assert.ok(ttc.includes('symptoms'), 'cramps are a symptom answer');
  assert.ok(ttc.includes('mood'), 'anxiety is a mood answer');
  assert.ok(!ttc.includes('pregnancy'), 'trying to conceive is not pregnancy');
});

test('an answer she never gave produces no focus', () => {
  const areas = deriveFocusAreas({ life_stage: 'menopause', symptoms: ['Hot flashes'] });
  assert.ok(areas.includes('menopause'));
  assert.ok(!areas.includes('fertility'));
  assert.ok(!areas.includes('recovery'));
});

test('the model may reorder but never add', () => {
  const allowed = ['cycle', 'symptoms', 'mood'];

  // A model naming something she gave no basis for, plus a real one.
  const result = reconcileFocusAreas(['pregnancy', 'mood', 'fertility'], allowed);

  assert.ok(!result.includes('pregnancy'), 'invented area must be dropped');
  assert.ok(!result.includes('fertility'), 'invented area must be dropped');
  assert.equal(result[0], 'mood', 'its ordering of a permitted area is kept');
  assert.deepEqual([...result].sort(), [...allowed].sort(),
    'everything the rules allowed is still present');
});

test('a useless model reply falls back to the rules intact', () => {
  const allowed = ['cycle', 'sleep'];
  for (const reply of [null, undefined, [], 'cycle', [{}], ['', '  ']]) {
    assert.deepEqual(reconcileFocusAreas(reply, allowed), allowed,
      `a reply of ${JSON.stringify(reply)} must not lose her focus areas`);
  }
});

test('duplicates from the model collapse', () => {
  const result = reconcileFocusAreas(['mood', 'mood', 'MOOD'], ['mood', 'sleep']);
  assert.deepEqual(result, ['mood', 'sleep']);
});

test('tracker and check-in keys are not treated as answers', () => {
  // These are records of what she logged, not what she asked for. Feeding them
  // in would let yesterday's check-in redefine her focus.
  const areas = deriveFocusAreas({
    log_peri_hot_flashes: 'Mild',
    daily_mood: 'Low',
  });
  assert.deepEqual(areas, [], 'logged values must not set focus areas');
});

test('every rule maps to a declared focus area', () => {
  const derived = deriveFocusAreas({
    symptoms: FOCUS_AREAS.join(' '),
  });
  for (const area of derived) {
    assert.ok(FOCUS_AREAS.includes(area), `${area} is not a declared focus area`);
  }
});
