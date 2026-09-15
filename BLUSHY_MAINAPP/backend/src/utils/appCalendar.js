/**
 * One definition of "what day is it" for the whole backend.
 *
 * There were four, and they disagreed. `dailyMoodRepository.todayIso` used
 * Asia/Kolkata, `sleepRepository.todayIso` used UTC, `moodFromChatService`
 * used UTC while writing through the Kolkata-based mood repository, and
 * `cycleFromChatService` had its own Kolkata copy. A row written under one
 * calendar and read under another simply is not found, so between 00:00 and
 * 05:30 IST a logged mood vanished from the dashboard and from the partner
 * decoder.
 *
 * India does not observe daylight saving, so the offset is a constant and the
 * literal below is exact rather than an approximation.
 *
 * If the app ever serves users outside a single timezone, this is the file to
 * change: the day a health log belongs to should follow the person who logged
 * it, not the server that stored it.
 */
const APP_TIME_ZONE = 'Asia/Kolkata';
const APP_UTC_OFFSET = '+05:30';

const dayFormatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: APP_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

/** Today's date as `YYYY-MM-DD`, on the app's calendar. */
export function todayIso(now = new Date()) {
  return dayFormatter.format(now);
}

/**
 * The instant a given day starts, which is how dated rows are keyed.
 *
 * Storing UTC midnight for an Indian calendar day puts the key 5.5 hours into
 * the day it names, so the same logical day could be written under two
 * different instants depending on which helper the caller reached for.
 */
export function dayStart(dateIso) {
  const day = String(dateIso ?? '').slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) {
    throw new Error(`Expected a YYYY-MM-DD date, received: ${dateIso}`);
  }
  return new Date(`${day}T00:00:00.000${APP_UTC_OFFSET}`);
}

/**
 * Reads a stored value back as `YYYY-MM-DD` on the app's calendar.
 *
 * The repositories previously used `getFullYear`/`getMonth`/`getDate`, which
 * are server-local. That happened to be right on a machine set to IST and
 * wrong by a day on Render, which runs in UTC -- so the same row read back as
 * a different date depending on where the code ran.
 */
export function dayIsoFromStored(value) {
  if (!value) return '';
  if (value instanceof Date) return dayFormatter.format(value);
  if (typeof value === 'string') {
    if (/^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? '' : dayFormatter.format(parsed);
  }
  return '';
}

export const appCalendar = { todayIso, dayStart, dayIsoFromStored, APP_TIME_ZONE };
