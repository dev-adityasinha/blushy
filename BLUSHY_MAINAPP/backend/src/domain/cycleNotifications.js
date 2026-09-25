/// Pure logic for the day's health/cycle notifications.
///
/// No database or service imports, so it is unit-testable in isolation (the DB
/// import chain otherwise keeps the test process alive and hangs `node --test`).
/// The service layer (cycleNotificationService) persists what this returns.

function isoDay(d) {
  return new Date(d).toISOString().split('T')[0];
}

function atHourToday(now, hour) {
  const d = new Date(now);
  d.setHours(hour, 0, 0, 0);
  return d;
}

const LIBRARY_TIPS = [
  'New read: why your period may not be on time for the first 2 years.',
  'New read: how to use and change pads comfortably at school.',
  'New read: what are breast buds, and why are they sore?',
  'New read: dealing with mood swings without feeling overwhelmed.',
  'New read: why period blood is sometimes dark brown.',
];

/**
 * Turns a user's cycle state into the notifications she should have today.
 *
 * Every spec carries a per-day (or per-cycle) dedupeKey, so persisting them
 * repeatedly never produces duplicates.
 */
export function buildCycleNotifications({
  now = new Date(),
  predictions = null,
  hasLoggedToday = false,
  hasDailyNote = false,
} = {}) {
  const specs = [];
  const today = isoDay(now);

  const cycle = predictions?.currentCycle ?? null;
  const pred = predictions?.prediction ?? null;

  // 1. Period due soon, or gently late (never alarming).
  if (cycle?.isOverdue) {
    specs.push({
      category: 'period_reminder',
      title: 'Taking a little longer this month',
      body: "Your period hasn't arrived yet, and in your first couple of years " +
          'that is completely normal. Tap for a gentle explainer.',
      dedupeKey: `period_late_${today}`,
      scheduledFor: now,
      deepLink: 'blushy://home',
    });
  } else if (
    pred?.nextPeriodStartDate &&
    typeof pred.daysUntilNextPeriod === 'number' &&
    pred.daysUntilNextPeriod >= 0 &&
    pred.daysUntilNextPeriod <= 3
  ) {
    const next = new Date(pred.nextPeriodStartDate);
    const remindAt = new Date(next);
    remindAt.setDate(remindAt.getDate() - 1);
    remindAt.setHours(9, 0, 0, 0);
    specs.push({
      category: 'period_reminder',
      title: 'Your period may be on its way',
      body: `Blushy expects your next period around ${pred.nextPeriodStartDate}. ` +
          'A good moment to pop a spare pad in your bag.',
      dedupeKey: `period_due_${pred.nextPeriodStartDate}`,
      scheduledFor: remindAt > now ? remindAt : now,
      deepLink: 'blushy://home',
    });
  }

  // 2. Daily check-in reminder, only when she has not logged today.
  if (!hasLoggedToday) {
    const remind = atHourToday(now, 18);
    specs.push({
      category: 'checkin_reminder',
      title: 'How are you feeling today?',
      body: 'Take a moment to log your flow, cramps and mood in your daily check-in.',
      dedupeKey: `checkin_${today}`,
      scheduledFor: remind > now ? remind : now,
      deepLink: 'blushy://home',
    });
  }

  // 3. A fresh Docsy note is ready.
  if (hasDailyNote) {
    specs.push({
      category: 'sia_proactive',
      title: 'Docsy has a note for you',
      body: "There's a fresh reflection waiting for you today.",
      dedupeKey: `docsy_note_${today}`,
      scheduledFor: now,
      deepLink: 'blushy://home',
    });
  }

  // 4. A rotating health-library tip. content_recommendation is off by default,
  //    so this only reaches users who opted in.
  const dayIndex = Math.floor(new Date(now).getTime() / 86400000);
  specs.push({
    category: 'content_recommendation',
    title: 'Something to read today',
    body: LIBRARY_TIPS[dayIndex % LIBRARY_TIPS.length],
    dedupeKey: `tip_${today}`,
    scheduledFor: now,
    deepLink: 'blushy://home',
  });

  return specs;
}
