import test from 'node:test';
import assert from 'node:assert/strict';

import { validateEvent } from '../src/domain/healthEvents.js';

/**
 * The values the app sends for cervical mucus and LH tests are values this
 * server accepts.
 *
 * Both event types were defined here from the start, with validators and
 * summary lines, and the app never sent one: the two selectors saved the
 * answer and never recorded an event. So the strongest two fertility signals
 * a person can log reached storage and nothing else.
 *
 * Now that the app does send them, this pins the join. The client maps
 * "Eggwhite" to `egg_white` because the card says it as one word and this
 * validator does not accept that spelling -- a mismatch here would be rejected
 * server side, which is the same silent loss in a different place.
 */
const CLIENT_SENDS = {
  cervical_mucus_logged: [
    // Dry, Sticky, Creamy, Eggwhite, in the form the mapper produces.
    { observation: 'dry' },
    { observation: 'sticky' },
    { observation: 'creamy' },
    { observation: 'egg_white' },
  ],
  lh_test_logged: [
    { result: 'low' },
    { result: 'high' },
    { result: 'peak' },
  ],
  // Postpartum feeding. `pumping` was added to the server's allowed list
  // because the app offers it and expressed milk is not nursing.
  feeding_logged: [
    { method: 'breast' },
    { method: 'bottle' },
    { method: 'pumping' },
  ],
  // Hot flashes and night sweats, on the 0-10 severity scale. Both selectors
  // send the same event; `nightSweat` is what tells them apart.
  hot_flash_logged: [
    { severity: 0, nightSweat: false },
    { severity: 3, nightSweat: false },
    { severity: 8, nightSweat: true },
  ],
  // Adherence. `taken: false` is a real answer, not a missing one.
  medication_logged: [
    { kind: 'medication', taken: true, reportedAs: 'Taken' },
    { kind: 'vitamin', taken: false, reportedAs: 'Not Taken' },
    { kind: 'hormone_therapy', taken: true, reportedAs: 'Taken' },
  ],
  // Pelvic floor exercise, as a numeric recovery metric.
  recovery_metric_logged: [
    { metric: 'pelvic_floor', value: 1, scale: 'binary' },
    { metric: 'pelvic_floor', value: 0, scale: 'binary' },
  ],
};

test('every value the app sends is accepted', () => {
  for (const [eventType, payloads] of Object.entries(CLIENT_SENDS)) {
    for (const payload of payloads) {
      const result = validateEvent({ eventType, payload });
      assert.equal(result.ok, true,
        `${eventType} ${JSON.stringify(payload)} rejected: ${result.error}`);
    }
  }
});

test('the spelling the card uses is not accepted raw', () => {
  // This is why the mapper translates rather than lowercasing. If this ever
  // starts passing, the translation is no longer load-bearing and the comment
  // explaining it is wrong.
  const raw = validateEvent(
    { eventType: 'cervical_mucus_logged', payload: { observation: 'eggwhite' } });
  assert.equal(raw.ok, false,
    'the server accepts "eggwhite" now; the mapper no longer needs to translate it');
});

test('the night sweat flag survives validation', () => {
  // The two selectors are only distinguishable by this field, so a validator
  // that dropped it would merge night sweats into hot flashes.
  const result = validateEvent({
    eventType: 'hot_flash_logged',
    payload: { severity: 8, nightSweat: true },
  });
  assert.equal(result.ok, true);
  // The validated payload comes back under `event`, not `value`.
  assert.equal(result.event.payload.nightSweat, true);
});

test('adherence needs an explicit taken, not a missing one', () => {
  // Omitting it must fail rather than default. A silent false would record a
  // dose as skipped on a day nobody answered.
  const missing = validateEvent({
    eventType: 'medication_logged',
    payload: { kind: 'vitamin' },
  });
  assert.equal(missing.ok, false);

  const wrongKind = validateEvent({
    eventType: 'medication_logged',
    payload: { kind: 'supplement', taken: true },
  });
  assert.equal(wrongKind.ok, false);
});

test('a value neither side offers is refused', () => {
  assert.equal(
    validateEvent({ eventType: 'lh_test_logged', payload: { result: 'very high' } }).ok,
    false);
  assert.equal(
    validateEvent(
      { eventType: 'cervical_mucus_logged', payload: { observation: 'slippery' } }).ok,
    false);
});
