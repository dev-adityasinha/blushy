import { test } from 'node:test';
import assert from 'node:assert/strict';

import { buildCycleNotifications } from '../src/domain/cycleNotifications.js';

/**
 * The notification inbox, delivery and preferences already existed; only the
 * generation of cycle/health notifications was missing. buildCycleNotifications
 * is the pure core of that generation, so it is tested directly (the DB-facing
 * syncForUser just persists what this returns).
 */

const now = new Date('2026-05-10T08:00:00.000Z');
const cats = (specs) => specs.map((s) => s.category);

test('a due-soon period schedules one period reminder, not a late one', () => {
  const specs = buildCycleNotifications({
    now,
    predictions: {
      currentCycle: { isOverdue: false },
      prediction: { nextPeriodStartDate: '2026-05-12', daysUntilNextPeriod: 2 },
    },
  });
  const period = specs.filter((s) => s.category === 'period_reminder');
  assert.equal(period.length, 1);
  assert.match(period[0].dedupeKey, /^period_due_2026-05-12$/);
  assert.doesNotMatch(period[0].title.toLowerCase(), /late|overdue/);
});

test('a far-off period does not nag', () => {
  const specs = buildCycleNotifications({
    now,
    predictions: {
      currentCycle: { isOverdue: false },
      prediction: { nextPeriodStartDate: '2026-05-30', daysUntilNextPeriod: 20 },
    },
  });
  assert.equal(cats(specs).includes('period_reminder'), false);
});

test('an overdue cycle sends a calm, non-alarming note', () => {
  const specs = buildCycleNotifications({
    now,
    predictions: {
      currentCycle: { isOverdue: true, daysOverdue: 6 },
      prediction: { nextPeriodStartDate: null, daysUntilNextPeriod: null },
    },
  });
  const period = specs.filter((s) => s.category === 'period_reminder');
  assert.equal(period.length, 1);
  assert.match(period[0].dedupeKey, /^period_late_/);
  assert.doesNotMatch(period[0].title.toLowerCase(), /alert|overdue|warning/);
});

test('the check-in reminder appears only when nothing was logged today', () => {
  const withReminder = buildCycleNotifications({ now, hasLoggedToday: false });
  const without = buildCycleNotifications({ now, hasLoggedToday: true });
  assert.equal(cats(withReminder).includes('checkin_reminder'), true);
  assert.equal(cats(without).includes('checkin_reminder'), false);
});

test('a fresh Docsy note is announced only when there is one', () => {
  const withNote = buildCycleNotifications({ now, hasDailyNote: true });
  const without = buildCycleNotifications({ now, hasDailyNote: false });
  assert.equal(cats(withNote).includes('sia_proactive'), true);
  assert.equal(cats(without).includes('sia_proactive'), false);
});

test('a rotating library tip is always offered, keyed once per day', () => {
  const specs = buildCycleNotifications({ now });
  const tip = specs.find((s) => s.category === 'content_recommendation');
  assert.ok(tip, 'expected a content_recommendation tip');
  assert.match(tip.dedupeKey, /^tip_2026-05-10$/);
});

test('every spec carries a dedupe key so repeated syncs never duplicate', () => {
  const specs = buildCycleNotifications({
    now,
    predictions: {
      currentCycle: { isOverdue: false },
      prediction: { nextPeriodStartDate: '2026-05-12', daysUntilNextPeriod: 1 },
    },
    hasLoggedToday: false,
    hasDailyNote: true,
  });
  assert.ok(specs.length >= 4);
  for (const s of specs) {
    assert.equal(typeof s.dedupeKey, 'string');
    assert.ok(s.dedupeKey.length > 0);
    assert.ok(s.category && s.title && s.body);
  }
});
