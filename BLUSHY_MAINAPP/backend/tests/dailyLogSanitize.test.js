import test from 'node:test';
import assert from 'node:assert/strict';

import { sanitizeDailyLogFields } from '../src/domain/dailyLogFields.js';

/**
 * A check-in has to be stored as it was given.
 *
 * Two answers were being changed on the way in, both silently and both with a
 * 200 back:
 *
 *   - `energyLevel` was kept only when it was a string. A client sending the
 *     number 7 got a stored null, with nothing anywhere to say the answer had
 *     been dropped. The app happens to send labels ("Low", "Balanced"), which
 *     is the only reason this was not visible.
 *   - `sleepHours` was rounded to whole hours, so 7.5 was written as 8 and
 *     read back as a figure nobody had entered.
 *
 * Measured against the live API before the fix: posting
 * `{energyLevel: 7, sleepHours: 7.5}` returned `energyLevel: null` and
 * `sleepHours: 8`.
 */

test('a fractional sleep length is kept, not rounded to the hour', () => {
  assert.equal(sanitizeDailyLogFields({ sleepHours: 7.5 }).sleepHours, 7.5);
  assert.equal(sanitizeDailyLogFields({ sleepHours: 6.5 }).sleepHours, 6.5);
  assert.equal(sanitizeDailyLogFields({ sleep_hours: 8.5 }).sleepHours, 8.5);

  // Whole hours are untouched, and anything finer than a half hour settles on
  // the nearest one rather than being stored to arbitrary precision.
  assert.equal(sanitizeDailyLogFields({ sleepHours: 8 }).sleepHours, 8);
  assert.equal(sanitizeDailyLogFields({ sleepHours: 7.4 }).sleepHours, 7.5);
  assert.equal(sanitizeDailyLogFields({ sleepHours: 7.1 }).sleepHours, 7);
});

test('sleep stays inside a real day', () => {
  assert.equal(sanitizeDailyLogFields({ sleepHours: -3 }).sleepHours, 0);
  assert.equal(sanitizeDailyLogFields({ sleepHours: 99 }).sleepHours, 24);
  assert.equal(sanitizeDailyLogFields({ sleepHours: 'eight' }).sleepHours, null);
  assert.equal(sanitizeDailyLogFields({}).sleepHours, null);
});

test('a numeric energy level is kept rather than dropped', () => {
  assert.equal(sanitizeDailyLogFields({ energyLevel: 7 }).energyLevel, '7');
  assert.equal(sanitizeDailyLogFields({ energy_level: 3 }).energyLevel, '3');

  // Zero is a real answer. `??` rather than `||` is what keeps it.
  assert.equal(sanitizeDailyLogFields({ energyLevel: 0 }).energyLevel, '0');
});

test('the labels the app actually sends still work', () => {
  for (const label of ['Low', 'Balanced', 'High']) {
    assert.equal(sanitizeDailyLogFields({ energyLevel: label }).energyLevel, label);
  }
  assert.equal(sanitizeDailyLogFields({}).energyLevel, null);
  assert.equal(sanitizeDailyLogFields({ energyLevel: {} }).energyLevel, null);
});

test('the other fields keep their existing bounds', () => {
  const out = sanitizeDailyLogFields({
    mood: 'x'.repeat(80),
    notes: 'n'.repeat(600),
    symptoms: ['  Cramps  ', '', 'Fatigue', 42],
  });
  assert.equal(out.mood.length, 50);
  assert.equal(out.notes.length, 500);
  assert.deepEqual(out.symptoms, ['Cramps', 'Fatigue']);
  assert.equal(out.source, 'manual_checkin');
});
