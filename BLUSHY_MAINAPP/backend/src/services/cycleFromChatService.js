import { userRepository } from '../repositories/userRepository.js';

function addDays(date, days) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

function todayIsoIst(now = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

function parseExplicitDate(message) {
  const normalized = String(message || '').trim();

  const isoMatch = /(\d{4})-(\d{2})-(\d{2})/.exec(normalized);
  if (isoMatch) {
    const parsed = new Date(`${isoMatch[1]}-${isoMatch[2]}-${isoMatch[3]}T00:00:00Z`);
    if (!Number.isNaN(parsed.getTime())) {
      return isoDate(parsed);
    }
  }

  const dmYMatch = /\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b/.exec(normalized);
  if (dmYMatch) {
    const day = Number(dmYMatch[1]);
    const month = Number(dmYMatch[2]);
    const year = Number(dmYMatch[3]);
    const parsed = new Date(Date.UTC(year, month - 1, day));
    if (!Number.isNaN(parsed.getTime())) {
      return isoDate(parsed);
    }
  }

  return null;
}

function resolveCycleStartDate(message, now = new Date()) {
  const normalized = String(message || '').toLowerCase();

  const explicit = parseExplicitDate(normalized);
  if (explicit) {
    return explicit;
  }

  if (/\bday before yesterday\b/.test(normalized)) {
    return todayIsoIst(addDays(now, -2));
  }

  if (/\byesterday\b|\byesterda+y\b|\byday before yesterday\b/.test(normalized)) {
    return todayIsoIst(addDays(now, -1));
  }

  if (/\btoday\b/.test(normalized)) {
    return todayIsoIst(now);
  }

  return null;
}

function looksLikePeriodStart(message) {
  const normalized = String(message || '').toLowerCase();

  if (!/\bperiod\b/.test(normalized)) {
    return false;
  }

  return /\b(got|have|having|started|start|began|begin|came|come|arrived|arrive)\b/.test(normalized)
    || /\bmy period\b/.test(normalized)
    || /\bperiod started\b/.test(normalized)
    || /\bperiod began\b/.test(normalized);
}

async function upsertCycleStartFromChatMessage({ userId, role, message, now = new Date() }) {
  if (!userId || role !== 'woman' || typeof message !== 'string' || message.trim().length === 0) {
    return { updated: false, reason: 'invalid-input' };
  }

  if (!looksLikePeriodStart(message)) {
    return { updated: false, reason: 'no-period-start' };
  }

  const cycleStartDate = resolveCycleStartDate(message, now);
  if (!cycleStartDate) {
    return { updated: false, reason: 'no-date-detected' };
  }

  const updatedUser = await userRepository.updateUser(userId, {
    cycleStartDate: `${cycleStartDate}T00:00:00.000Z`,
  });

  return {
    updated: Boolean(updatedUser),
    reason: updatedUser ? 'updated' : 'update-failed',
    cycleStartDate: updatedUser?.cycleStartDate ?? `${cycleStartDate}T00:00:00.000Z`,
  };
}

export const cycleFromChatService = {
  upsertCycleStartFromChatMessage,
};
