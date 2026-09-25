import { scheduleNotification } from '../repositories/notificationRepository.js';
import { calculatePeriodPredictions } from './periodPredictionService.js';
import { buildCycleNotifications } from '../domain/cycleNotifications.js';
import { logger } from '../utils/logger.js';

/// Generates the day's health/cycle notifications for a user.
///
/// The notification inbox, delivery (FCM) and preferences already exist; only
/// generation was missing for the cycle/health categories. This fills that gap
/// idempotently: the pure [buildCycleNotifications] decides what she should have
/// today (each with a per-day dedupeKey), and scheduleNotification persists them
/// while enforcing preferences, quiet hours and lock-screen redaction.

export { buildCycleNotifications };

/**
 * Gathers the user's cycle state and schedules today's notifications. Safe to
 * call on every home load: dedupeKeys make it idempotent, and each schedule is
 * wrapped so one failure cannot block the others.
 */
export async function syncForUser(userId, { hasLoggedToday = false, hasDailyNote = false } = {}) {
  if (!userId) return { scheduled: 0 };

  let predictions = null;
  try {
    predictions = await calculatePeriodPredictions(userId, {});
  } catch (_) {
    predictions = null;
  }

  const specs = buildCycleNotifications({
    now: new Date(),
    predictions,
    hasLoggedToday,
    hasDailyNote,
  });

  let scheduled = 0;
  for (const spec of specs) {
    try {
      const result = await scheduleNotification(userId, spec);
      if (result?.ok && !result.deduplicated && !result.skipped) scheduled++;
    } catch (err) {
      logger.warn(
        `cycleNotifications: could not schedule ${spec.category}: ${err?.message ?? err}`,
      );
    }
  }
  return { scheduled };
}

export const cycleNotificationService = { buildCycleNotifications, syncForUser };
