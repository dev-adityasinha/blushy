import test from 'node:test';
import assert from 'node:assert/strict';

import { validateEvent, describeEvent, getInvalidationTargets } from '../src/domain/healthEvents.js';

/**
 * Basal temperature and weight.
 *
 * `bbt_logged` was defined here from the start, with a validator, a summary
 * line, a `log_bbt` home action, and `detectBbtShift` in fertility.js reading
 * it to confirm ovulation -- and the app never sent one. `weight_logged` did
 * not exist at all. Both are now entered from the check-in.
 *
 * The ranges are asserted here because the app enforces the same two before
 * sending: a value rejected on the wire shows nothing on screen, so the client
 * and this file have to agree.
 */
test('weight is accepted in kilograms and rounded to one decimal', () => {
  const ok = validateEvent({ eventType: 'weight_logged', payload: { kg: 61.44 } });
  assert.equal(ok.ok, true);
  // Scales report one decimal; keeping more implies precision the reading
  // does not have.
  assert.equal(ok.event.payload.kg, 61.4);
});

test('weight accepts the weightKg spelling too', () => {
  const ok = validateEvent({ eventType: 'weight_logged', payload: { weightKg: 72.3 } });
  assert.equal(ok.ok, true);
  assert.equal(ok.event.payload.kg, 72.3);
});

test('weight outside the range is rejected rather than stored', () => {
  for (const kg of [19.9, 400.1, 0, -5]) {
    const result = validateEvent({ eventType: 'weight_logged', payload: { kg } });
    assert.equal(result.ok, false, `${kg} should be rejected`);
  }
});

test('a missing weight says it is missing, not out of range', () => {
  const result = validateEvent({ eventType: 'weight_logged', payload: {} });
  assert.equal(result.ok, false);
  assert.match(result.error, /required/);
});

test('the client range for weight is the one this server enforces', () => {
  // NumericMetric.weight declares 20..400.
  assert.equal(validateEvent({ eventType: 'weight_logged', payload: { kg: 20 } }).ok, true);
  assert.equal(validateEvent({ eventType: 'weight_logged', payload: { kg: 400 } }).ok, true);
});

test('the client range for basal temperature is the one this server enforces', () => {
  // NumericMetric.bbt declares 33..43.
  assert.equal(validateEvent({ eventType: 'bbt_logged', payload: { celsius: 33 } }).ok, true);
  assert.equal(validateEvent({ eventType: 'bbt_logged', payload: { celsius: 43 } }).ok, true);
  assert.equal(validateEvent({ eventType: 'bbt_logged', payload: { celsius: 32.9 } }).ok, false);
  assert.equal(validateEvent({ eventType: 'bbt_logged', payload: { celsius: 43.1 } }).ok, false);
});

test('a basal temperature to two decimals survives, since the shift is 0.2', () => {
  // detectBbtShift compares against a 0.2C threshold, so rounding to one
  // decimal here would blur the signal it looks for.
  const ok = validateEvent({ eventType: 'bbt_logged', payload: { celsius: 36.55 } });
  assert.equal(ok.ok, true);
  assert.equal(ok.event.payload.celsius, 36.55);
});

test('both have a readable summary line', () => {
  assert.equal(
    describeEvent({ eventType: 'weight_logged', payload: { kg: 61.4 } }),
    'Weight 61.4 kg');
  assert.equal(
    describeEvent({ eventType: 'bbt_logged', payload: { celsius: 36.55 } }),
    'BBT 36.55°C');
});

test('a weight reading is not treated as a safety signal', () => {
  // No reviewed red-flag rule reads a weight, and routing it through safety
  // would put it in front of rules written for symptoms.
  const targets = getInvalidationTargets('weight_logged');
  assert.ok(!targets.includes('safety'), 'weight must not invalidate safety');
  assert.deepEqual(targets, ['patterns', 'timeline']);
});
