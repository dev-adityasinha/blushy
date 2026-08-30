import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { db } from '../utils/db.js';
import { env } from '../utils/env.js';
import { logger } from '../utils/logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const communityUploadDir = path.resolve(__dirname, '../../uploads/community');

function daysInUtcMonth(year, monthZeroBased) {
  return new Date(Date.UTC(year, monthZeroBased + 1, 0)).getUTCDate();
}

// Calculates retention window for "same day index in previous month" cleanup policy.
// For shorter months, it clamps to the last day (e.g. Mar 31 => Feb 28/29).
export function getPreviousMonthMatchingDayWindow(now = new Date()) {
  const reference = new Date(now);
  const year = reference.getUTCFullYear();
  const month = reference.getUTCMonth();
  const day = reference.getUTCDate();

  const prevMonthDate = new Date(Date.UTC(year, month - 1, 1, 0, 0, 0, 0));
  const prevYear = prevMonthDate.getUTCFullYear();
  const prevMonth = prevMonthDate.getUTCMonth();
  const maxDayInPrevMonth = daysInUtcMonth(prevYear, prevMonth);
  const targetDay = Math.min(day, maxDayInPrevMonth);

  const startInclusiveUtc = new Date(Date.UTC(prevYear, prevMonth, targetDay, 0, 0, 0, 0));
  const endExclusiveUtc = new Date(Date.UTC(prevYear, prevMonth, targetDay + 1, 0, 0, 0, 0));

  return {
    startInclusiveUtc,
    endExclusiveUtc,
  };
}

async function removeLocalImageIfPresent(imageUrl) {
  if (typeof imageUrl !== 'string' || imageUrl.trim().length === 0) {
    return;
  }

  let pathname;
  try {
    const parsed = new URL(imageUrl);
    pathname = parsed.pathname;
  } catch {
    // Ignore non-URL values.
    return;
  }

  if (!pathname.startsWith('/uploads/community/')) {
    return;
  }

  const fileName = path.basename(pathname);
  const fullPath = path.join(communityUploadDir, fileName);

  try {
    await fs.unlink(fullPath);
  } catch {
    // File may already be missing; keep cleanup idempotent.
  }
}

export async function runMonthlyMirrorCleanupOnce(now = new Date()) {
  const { startInclusiveUtc, endExclusiveUtc } = getPreviousMonthMatchingDayWindow(now);

  const query = {
    created_at: {
      $gte: startInclusiveUtc,
      $lt: endExclusiveUtc
    }
  };

  const messages = await db.collection('community_messages').find(query).toArray();
  const imageUrls = messages
    .map((msg) => msg.image_url)
    .filter((value) => typeof value === 'string' && value.length > 0);

  const deleteResult = await db.collection('community_messages').deleteMany(query);

  for (const imageUrl of imageUrls) {
    await removeLocalImageIfPresent(imageUrl);
  }

  return {
    deletedMessages: deleteResult.deletedCount ?? 0,
    cleanedImages: imageUrls.length,
    startInclusiveUtc,
    endExclusiveUtc,
  };
}

export function startCommunityCleanupScheduler() {
  if (!env.communityCleanupEnabled) {
    logger.info('Community monthly cleanup scheduler disabled by COMMUNITY_CLEANUP_ENABLED=false.');
    return () => {};
  }

  let lastRunDateKey = '';

  const tick = async () => {
    const now = new Date();
    const dateKey = now.toISOString().slice(0, 10);
    if (lastRunDateKey === dateKey) {
      return;
    }

    if (now.getUTCHours() < env.communityCleanupHourUtc) {
      return;
    }

    try {
      const summary = await runMonthlyMirrorCleanupOnce(now);
      lastRunDateKey = dateKey;

      logger.info(
        `Community cleanup completed. Window=${summary.startInclusiveUtc.toISOString()}..${summary.endExclusiveUtc.toISOString()} deletedMessages=${summary.deletedMessages} cleanedImages=${summary.cleanedImages}`,
      );
    } catch (error) {
      logger.error(`Community cleanup failed: ${error?.message ?? error}`);
    }
  };

  const timer = setInterval(() => {
    tick();
  }, 5 * 60 * 1000);

  tick();

  logger.info(`Community monthly cleanup scheduler started (runs daily after ${env.communityCleanupHourUtc}:00 UTC).`);

  return () => {
    clearInterval(timer);
  };
}
