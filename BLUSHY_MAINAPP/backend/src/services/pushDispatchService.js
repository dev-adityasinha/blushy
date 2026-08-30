import { env } from '../utils/env.js';
import { logger } from '../utils/logger.js';
import { deliver } from './pushDeliveryService.js';
import {
  findDueNotifications,
  markNotificationDelivered,
  recordDeliveryAttempt,
  cancelNotification,
} from '../repositories/notificationRepository.js';

/**
 * Turns scheduled notifications into actual sends (spec §19, §24).
 *
 * `scheduleNotification` writes rows with `status: 'scheduled'`; without this
 * worker they sat there and nothing was ever delivered. Each pass takes the
 * ones whose time has come and hands them to the transport.
 *
 * Outcomes are not all equal, so they are not all treated the same:
 *
 *  - delivered              -> done
 *  - quiet hours            -> left scheduled, picked up on a later pass. This
 *                              is the deferral working, not a failure.
 *  - category switched off  -> cancelled; it can never succeed
 *  - anything else          -> counted as an attempt, and abandoned after
 *                              MAX_DELIVERY_ATTEMPTS so one bad row cannot be
 *                              retried forever
 */

/** Reasons that will never change on a retry. */
const TERMINAL_REASONS = new Set(['category_disabled', 'unknown_category']);

/** Reasons that mean "not yet", not "no". */
const DEFERRABLE_REASONS = new Set(['quiet_hours']);

export async function runPushDispatchOnce({ now = new Date(), limit = 100 } = {}) {
  const due = await findDueNotifications({ now, limit });

  let delivered = 0;
  let deferred = 0;
  let cancelled = 0;
  let failed = 0;

  for (const notification of due) {
    let result;
    try {
      result = await deliver(notification.userId, notification);
    } catch (error) {
      await recordDeliveryAttempt(notification.notificationId, `exception:${error?.message ?? error}`);
      failed += 1;
      continue;
    }

    if (result.delivered) {
      await markNotificationDelivered(notification.notificationId);
      delivered += 1;
      continue;
    }

    if (DEFERRABLE_REASONS.has(result.reason)) {
      deferred += 1;
      continue;
    }

    if (TERMINAL_REASONS.has(result.reason)) {
      await cancelNotification(notification.notificationId, result.reason);
      cancelled += 1;
      continue;
    }

    await recordDeliveryAttempt(notification.notificationId, result.reason);
    failed += 1;
  }

  return { considered: due.length, delivered, deferred, cancelled, failed };
}

export function startPushDispatchScheduler({ intervalMs = 60 * 1000 } = {}) {
  // Without a transport every pass would be a no-op that still walks the
  // queue, so the worker stays off until one is configured.
  if (!env.pushProviderConfigured) {
    logger.info('Push dispatch scheduler disabled: FCM_SERVICE_ACCOUNT_JSON is not set.');
    return () => {};
  }

  let running = false;

  const tick = async () => {
    // Passes must not overlap: two workers would deliver the same row twice.
    if (running) return;
    running = true;
    try {
      const summary = await runPushDispatchOnce();
      if (summary.considered > 0) {
        logger.info(
          `Push dispatch: considered=${summary.considered} delivered=${summary.delivered} ` +
          `deferred=${summary.deferred} cancelled=${summary.cancelled} failed=${summary.failed}`,
        );
      }
    } catch (error) {
      logger.error(`Push dispatch failed: ${error?.message ?? error}`);
    } finally {
      running = false;
    }
  };

  const timer = setInterval(tick, intervalMs);
  tick();

  logger.info(`Push dispatch scheduler started (every ${Math.round(intervalMs / 1000)}s).`);

  return () => clearInterval(timer);
}
