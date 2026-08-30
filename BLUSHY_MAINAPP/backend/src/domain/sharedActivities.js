/**
 * Shared relationship activities (spec §10, §16).
 *
 * These belong to the connection, not to one person: whatever one partner does
 * the other sees. The catalogue lives here so the two clients cannot drift
 * apart about what an activity is called or what states it can be in.
 *
 * Dependency-free like the rest of `domain/`.
 */

export const ACTIVITY_STATES = Object.freeze({
  NOT_STARTED: 'not_started',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
});

/**
 * The catalogue. `key` is the stable identifier; the copy is here rather than
 * in the app so both partners read the same words.
 */
export const SHARED_ACTIVITIES = Object.freeze({
  daily_gratitude: {
    key: 'daily_gratitude',
    title: 'Daily Gratitude Challenge',
    description: 'Each of you names one thing you appreciated today.',
    icon: 'gratitude',
    repeatable: true,
  },
  weekend_planner: {
    key: 'weekend_planner',
    title: 'Weekend Planner',
    description: 'Build a shared list of things to do together.',
    icon: 'calendar',
    repeatable: true,
  },
  date_planner: {
    key: 'date_planner',
    title: 'Date Planner',
    description: 'Plan and agree your next date.',
    icon: 'date',
    repeatable: true,
  },
  shared_canvas: {
    key: 'shared_canvas',
    title: 'Shared Canvas',
    description: 'Draw something together.',
    icon: 'canvas',
    repeatable: true,
  },
  virtual_bouquet: {
    key: 'virtual_bouquet',
    title: 'Virtual Bouquet',
    description: 'Arrange and send digital flowers.',
    icon: 'bouquet',
    repeatable: true,
  },
});

export const ACTIVITY_KEYS = Object.freeze(Object.keys(SHARED_ACTIVITIES));

export function isKnownActivity(key) {
  return Object.prototype.hasOwnProperty.call(SHARED_ACTIVITIES, key);
}

/**
 * Which transitions are legal.
 *
 * A repeatable activity can be started again after completion, which is how a
 * weekly ritual works. Completing something never started is allowed too: one
 * partner may simply mark it done.
 */
export function canTransition(from, to, { repeatable = true } = {}) {
  if (!Object.values(ACTIVITY_STATES).includes(to)) return false;

  switch (to) {
    case ACTIVITY_STATES.IN_PROGRESS:
      return from !== ACTIVITY_STATES.IN_PROGRESS
        && (from !== ACTIVITY_STATES.COMPLETED || repeatable);
    case ACTIVITY_STATES.COMPLETED:
      return from !== ACTIVITY_STATES.COMPLETED;
    case ACTIVITY_STATES.NOT_STARTED:
      return from !== ACTIVITY_STATES.NOT_STARTED;
    default:
      return false;
  }
}

/**
 * Merges the catalogue with whatever state a connection has recorded, so a
 * connection that has done nothing still returns the full list with every
 * activity plainly `not_started` rather than an empty response the client has
 * to interpret.
 */
export function buildActivityList(stateByKey = {}) {
  return ACTIVITY_KEYS.map((key) => {
    const definition = SHARED_ACTIVITIES[key];
    const state = stateByKey[key] ?? null;

    return {
      ...definition,
      status: state?.status ?? ACTIVITY_STATES.NOT_STARTED,
      startedByUserId: state?.startedByUserId ?? null,
      completedByUserId: state?.completedByUserId ?? null,
      startedAt: state?.startedAt ?? null,
      completedAt: state?.completedAt ?? null,
      completionCount: state?.completionCount ?? 0,
    };
  });
}
