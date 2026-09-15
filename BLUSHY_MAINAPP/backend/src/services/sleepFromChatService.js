import { sleepRepository } from '../repositories/sleepRepository.js';

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

function addDays(date, days) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function clamp(min, value, max) {
  return Math.max(min, Math.min(max, value));
}

function minutesToTime(totalMinutes) {
  const safeMinutes = ((Math.round(totalMinutes) % 1440) + 1440) % 1440;
  const hours = Math.floor(safeMinutes / 60);
  const minutes = safeMinutes % 60;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

function resolveEntryDate(message, now = new Date()) {
  const normalized = String(message || '').toLowerCase();
  if (/(yesterday|yesterda+y|yessterday)/.test(normalized)) {
    return isoDate(addDays(now, -1));
  }

  return isoDate(now);
}

function extractDurationMinutes(message) {
  const normalized = String(message || '').toLowerCase();

  // Only parse messages that are clearly about sleep/rest.
  if (!/(sleep|slept|rest)/.test(normalized)) {
    return null;
  }

  const patterns = [
    /(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)\b/,
    /(\d+)\s*(?:m|min|mins|minute|minutes)\b/,
  ];

  let minutes = null;

  const hourMatch = patterns[0].exec(normalized);
  if (hourMatch) {
    const value = Number(hourMatch[1]);
    if (Number.isFinite(value) && value > 0) {
      minutes = Math.round(value * 60);
    }
  }

  const minuteMatch = patterns[1].exec(normalized);
  if (minuteMatch) {
    const value = Number(minuteMatch[1]);
    if (Number.isFinite(value) && value > 0) {
      minutes = (minutes ?? 0) + Math.round(value);
    }
  }

  if (minutes == null) {
    return null;
  }

  // Keep same bounds as existing sleep validation semantics.
  return clamp(30, minutes, 16 * 60);
}

async function upsertSleepFromChatMessage({ userId, message, now = new Date() }) {
  if (!userId || typeof message !== 'string' || message.trim().length === 0) {
    return { updated: false, reason: 'invalid-input' };
  }

  const durationMinutes = extractDurationMinutes(message);
  if (durationMinutes == null) {
    return { updated: false, reason: 'no-sleep-duration' };
  }

  const entryDate = resolveEntryDate(message, now);
  const existing = await sleepRepository.getSleepByDate(userId, entryDate);
  if (existing) {
    return { updated: false, reason: 'already-exists', entryDate };
  }

  // We only get duration from chat text, so we anchor wake time and back-calculate sleep time.
  const wakeMinutes = 7 * 60;
  const sleepMinutes = wakeMinutes - durationMinutes;
  const sleepTime = minutesToTime(sleepMinutes);
  const wakeTime = minutesToTime(wakeMinutes);

  await sleepRepository.upsertSleepByDate({
    userId,
    entryDate,
    sleepTime,
    wakeTime,
    durationMinutes,
  });

  return {
    updated: true,
    entryDate,
    durationMinutes,
    source: 'ai-chat',
  };
}

export const sleepFromChatService = {
  upsertSleepFromChatMessage,
};
