import {
  findDueCapsules,
  markCapsuleNotified,
} from '../repositories/timeCapsuleRepository.js';
import { scheduleNotification } from '../repositories/notificationRepository.js';
import { logger } from '../utils/logger.js';

/**
 * Delivers time capsules that have come due.
 *
 * "Deliver in 6 Months" used to deliver nothing: capsules lived in device
 * storage and no job ever looked at them. This is what makes the promise real.
 */
const TICK_MS = 60 * 1000;

export async function runCapsuleDeliveryOnce(now = new Date()) {
  const due = await findDueCapsules({ now });

  let delivered = 0;
  for (const capsule of due) {
    try {
      await scheduleNotification(capsule.userId, {
        category: 'sia_proactive',
        title: 'A capsule you sealed is ready',
        body: `"${capsule.title}" is open now.`,
        entityType: 'time_capsule',
        entityId: capsule.capsuleId,
        deepLink: `blushy://studio/capsules?capsuleId=${capsule.capsuleId}`,
        dedupeKey: `capsule:${capsule.capsuleId}`,
      });
    } catch (error) {
      logger.warn('Time capsule came due but could not be announced', {
        capsuleId: capsule.capsuleId,
        message: error?.message,
      });
    }

    // Marked regardless of whether the notice landed. The capsule is open in
    // the app either way, and retrying forever would announce it repeatedly.
    await markCapsuleNotified(capsule.capsuleId, { now });
    delivered += 1;
  }

  return { checked: due.length, delivered };
}

export function startCapsuleDeliveryScheduler() {
  let running = false;

  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const result = await runCapsuleDeliveryOnce();
      if (result.delivered > 0) {
        logger.info(`Time capsules delivered: ${result.delivered}`);
      }
    } catch (error) {
      logger.error('Time capsule delivery failed', { message: error?.message });
    } finally {
      running = false;
    }
  };

  const timer = setInterval(tick, TICK_MS);
  if (typeof timer.unref === 'function') timer.unref();

  logger.info('Time capsule delivery scheduler started.');
  return () => clearInterval(timer);
}
