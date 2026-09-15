import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

import { buildFertilityIndicators } from '../src/domain/fertility.js';

/**
 * What the daily check-in is allowed to move, and what it is not.
 *
 * Ticking a follow-up card ("did you drink 2L?", "did you move today?") should
 * change what Docsy says and which patterns surface. It must NOT change the
 * predicted period date. Hydration and activity do not shift a cycle, and
 * showing that they do would be a causal claim the evidence does not support --
 * the same claim the engine marks `causalClaim: false` on every insight to
 * avoid.
 *
 * Ovulation confidence is the opposite case: it is *supposed* to move, and
 * only from the three signals that carry it.
 */

const DAY = 86400000;
const base = Date.UTC(2026, 0, 10);
const at = (d) => new Date(base + d * DAY).toISOString();

test('period prediction reads no health events at all', () => {
  // It is cycle-length arithmetic over recorded period start dates. This is a
  // structural guard: the moment it starts filtering eventType, a future
  // change can quietly let hydration or symptoms move the date.
  const src = fs.readFileSync('src/services/periodPredictionService.js', 'utf8');
  for (const forbidden of [
    'symptom_logged',
    'hydration_logged',
    'activity_logged',
    'energy_logged',
    'mood_logged',
    'stress_logged',
    'weight_logged',
  ]) {
    assert.ok(
      !src.includes(forbidden),
      `periodPredictionService must not read ${forbidden}: it would make the date respond to something that does not move a cycle`,
    );
  }
});

test('ovulation confidence moves on BBT, and only from real readings', () => {
  // A sustained rise of at least 0.2C. detectBbtShift wants nine readings --
  // six baseline days and three elevated ones -- before it will say anything,
  // which is the same refusal-to-guess the pattern engine applies.
  const events = [];
  const temps = [36.3, 36.25, 36.3, 36.28, 36.26, 36.3, 36.6, 36.62, 36.58];
  temps.forEach((celsius, i) => {
    events.push({
      eventId: `b${i}`,
      eventType: 'bbt_logged',
      timestamp: at(i),
      payload: { celsius },
    });
  });

  const withBbt = buildFertilityIndicators({
    events,
    referenceDate: new Date(base + 8 * DAY),
    ttcOptedIn: true,
  });
  const withoutBbt = buildFertilityIndicators({
    events: [],
    referenceDate: new Date(base + 8 * DAY),
    ttcOptedIn: true,
  });

  const shifted = (withBbt.indicators ?? []).some((i) => i.key === 'bbt_shift');
  const shiftedEmpty = (withoutBbt.indicators ?? []).some((i) => i.key === 'bbt_shift');

  assert.ok(shifted, 'a sustained rise should register');
  assert.ok(!shiftedEmpty, 'no readings, no indicator');
});

test('hydration and activity do not register as fertility indicators', () => {
  // These are exactly the events the generated check-in cards produce.
  const noise = [];
  for (let i = 0; i < 10; i++) {
    noise.push({
      eventId: `h${i}`,
      eventType: 'hydration_logged',
      timestamp: at(i),
      payload: { glasses: 8 },
    });
    noise.push({
      eventId: `a${i}`,
      eventType: 'activity_logged',
      timestamp: at(i),
      payload: { activity: 'walk', minutes: 30 },
    });
  }

  const result = buildFertilityIndicators({
    events: noise,
    referenceDate: new Date(base + 11 * DAY),
    ttcOptedIn: true,
  });

  assert.deepEqual(
    result.indicators ?? [],
    [],
    'only BBT, LH and cervical mucus carry ovulation confidence',
  );
});
