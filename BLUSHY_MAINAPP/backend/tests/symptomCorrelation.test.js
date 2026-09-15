import test from 'node:test';
import assert from 'node:assert/strict';

import { computePatterns, MIN_PAIRED_OBSERVATIONS } from '../src/domain/patterns.js';

/**
 * Symptoms set against the daily check-in.
 *
 * Every correlation in this engine used to be check-in against check-in --
 * sleep, mood, energy, stress, pain. Symptoms only ever produced frequency
 * counts and cycle-phase timing, so the cross-signal observation people
 * actually want ("this shows up on my low-sleep days") could not be made.
 *
 * The trap these tests exist for: a symptom is present or absent, and absence
 * only means something on a day she logged. Counting every day in the window
 * as a zero would turn the days she did not open the app into evidence.
 */

const DAY = 86400000;

function at(dayOffset) {
  // Fixed base so the day bucketing is not sensitive to when this runs.
  return new Date(Date.UTC(2026, 0, 10) + dayOffset * DAY).toISOString();
}

function sleep(dayOffset, hours) {
  return {
    eventId: `s${dayOffset}`,
    eventType: 'sleep_logged',
    timestamp: at(dayOffset),
    payload: { durationHours: hours },
  };
}

function symptom(dayOffset, name) {
  return {
    eventId: `y${dayOffset}-${name}`,
    eventType: 'symptom_logged',
    timestamp: at(dayOffset),
    payload: { symptom: name },
  };
}

const reference = new Date(Date.UTC(2026, 1, 20));

test('a symptom that tracks short sleep is surfaced', () => {
  const events = [];
  // Ten logged days: headache on the short-sleep ones, not on the long ones.
  const hours = [5, 8, 5, 8, 5, 8, 5, 8, 5, 8];
  hours.forEach((h, i) => {
    events.push(sleep(i, h));
    if (h === 5) events.push(symptom(i, 'headache'));
  });

  const result = computePatterns({ events, referenceDate: reference });
  assert.equal(result.state, 'ready');

  const found = result.insights.find((i) => i.type === 'symptom_sleep');
  assert.ok(found, 'expected a headache/sleep insight');
  assert.match(found.description, /headache/);
  assert.match(found.description, /shorter sleep/);
  assert.equal(found.causalClaim, false, 'an association is never a cause');
  assert.equal(found.observationCount, 10);
  assert.equal(found.metadata.daysWithSymptom, 5);
});

test('days she did not log are not counted as symptom-free', () => {
  // Only six logged days, all with the symptom and all short sleep. There is
  // no contrast, so nothing may be claimed -- even though a naive engine that
  // filled the rest of the window with zeros would find a perfect correlation.
  const events = [];
  for (let i = 0; i < 6; i++) {
    events.push(sleep(i, 5));
    events.push(symptom(i, 'cramps'));
  }

  const result = computePatterns({ events, referenceDate: reference });
  const found = (result.insights ?? []).find((i) => i.type === 'symptom_sleep');
  assert.equal(found, undefined, 'a flat series cannot correlate');
});

test('one day is never a pattern', () => {
  const events = [sleep(0, 5), symptom(0, 'fatigue')];
  const result = computePatterns({ events, referenceDate: reference });

  assert.equal(result.state, 'insufficient_data');
  assert.equal(result.insights.length, 0);
  assert.equal(result.reason, 'not_enough_paired_observations');
});

test('below the paired-observation floor nothing is claimed', () => {
  // One short of the floor, with a clean alternating signal that would
  // otherwise correlate perfectly.
  const events = [];
  for (let i = 0; i < MIN_PAIRED_OBSERVATIONS - 1; i++) {
    const short = i % 2 === 0;
    events.push(sleep(i, short ? 5 : 8));
    if (short) events.push(symptom(i, 'headache'));
  }

  const result = computePatterns({ events, referenceDate: reference });
  const found = (result.insights ?? []).find((i) => i.type === 'symptom_sleep');
  assert.equal(found, undefined, `under ${MIN_PAIRED_OBSERVATIONS} pairs nothing may be said`);
});

test('a symptom logged on every logged day yields no correlation', () => {
  const events = [];
  for (let i = 0; i < 10; i++) {
    events.push(sleep(i, i % 2 === 0 ? 5 : 8));
    events.push(symptom(i, 'bloating'));
  }

  const result = computePatterns({ events, referenceDate: reference });
  const found = (result.insights ?? []).find(
    (i) => i.type === 'symptom_sleep' && i.metadata?.symptom === 'bloating');
  assert.equal(found, undefined, 'present every day is a flat series');
});

test('an AI-derived event is never evidence for a symptom correlation', () => {
  const events = [];
  const hours = [5, 8, 5, 8, 5, 8, 5, 8, 5, 8];
  hours.forEach((h, i) => {
    events.push(sleep(i, h));
    if (h === 5) events.push({ ...symptom(i, 'headache'), source: 'ai_derived' });
  });

  const result = computePatterns({ events, referenceDate: reference });
  const found = (result.insights ?? []).find((i) => i.type === 'symptom_sleep');
  assert.equal(found, undefined, 'the model must not become its own evidence');
});

test('stress and energy are correlated against too', () => {
  const events = [];
  for (let i = 0; i < 10; i++) {
    const bad = i % 2 === 0;
    events.push({
      eventId: `st${i}`,
      eventType: 'stress_logged',
      timestamp: at(i),
      payload: { level: bad ? 5 : 1 },
    });
    if (bad) events.push(symptom(i, 'insomnia'));
  }

  const result = computePatterns({ events, referenceDate: reference });
  const found = result.insights.find((i) => i.type === 'symptom_stress');
  assert.ok(found, 'expected an insomnia/stress insight');
  assert.match(found.description, /higher logged stress/);
});
