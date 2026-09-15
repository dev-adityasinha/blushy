import test from 'node:test';
import assert from 'node:assert/strict';

import { buildCycleInfo } from '../src/services/partnerSuggestionService.js';

/**
 * Logging a period start before today reported Day 1, as though the date had
 * not been accepted.
 *
 * `buildCycleInfo` took the most recent of every source it knew: the logged
 * start, and five onboarding answers. Those answers are a one-time seed that is
 * never updated, so one sitting later in the calendar than the period she had
 * just logged silently replaced it. With `period_last_start_date` of Aug 31 on
 * file, logging Aug 24 reported Day 1 instead of Day 8.
 */
const TODAY = '2026-08-31';

test('a logged start date is used even when an answer holds a later one', () => {
  // Measured before the fix: Day 8, Day 2, Day 1 respectively.
  const cases = [
    ['nothing else on file', {}],
    ['an answer six days later', { period_last_start_date: '2026-08-30' }],
    ['an answer dated today', { period_last_start_date: '2026-08-31' }],
    ['a multi-month answer later', { period_last_month_1_start: '2026-08-29' }],
  ];

  for (const [label, answers] of cases) {
    const info = buildCycleInfo('2026-08-24', answers, TODAY, []);
    assert.equal(info.currentCycleDay, 8,
      `${label}: the day must come from the date she logged`);
  }
});

test('the onboarding answers still supply a start when nothing is logged', () => {
  // They are a seed, not noise: without a logged entry they are all there is.
  const info = buildCycleInfo(null, { period_last_start_date: '2026-08-24' }, TODAY, []);
  assert.equal(info.currentCycleDay, 8);
});

test('with no dates at all there is no cycle to report', () => {
  assert.equal(buildCycleInfo(null, {}, TODAY, []), null);
});

test('cycle length ignores a seed dated after the logged start', () => {
  // Length is the gap between consecutive starts. A later seed would otherwise
  // be differenced against the start actually in use and give a nonsense gap.
  const info = buildCycleInfo(
    '2026-08-24',
    {
      period_last_month_1_start: '2026-07-27', // 28 days before
      period_last_start_date: '2026-08-30',    // a stale seed, after the log
    },
    TODAY,
    [],
  );

  assert.equal(info.currentCycleDay, 8);
  assert.equal(info.cycleFrequencyDays, 28,
    'the length must come from the two real consecutive starts');
});

test('a start date in the future does not report a negative day', () => {
  const info = buildCycleInfo('2026-09-10', {}, TODAY, []);
  assert.ok(info.currentCycleDay >= 1,
    `a future start reported day ${info.currentCycleDay}`);
});
