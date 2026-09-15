import { db } from '../utils/db.js';

/**
 * Today's mood and sleep, recovered from the events the app actually writes.
 *
 * The app records a check-in as **health events**. The partner view reads
 * `user_daily_moods` and the sleep table instead, and nothing in the app writes
 * either: `saveDailyMood` and `saveSleepLog` exist in the client service and are
 * called from no screen. So `latestMood` and `latestSleep` came back null for
 * every couple, however faithfully she checked in — the partner feature's whole
 * point, showing nothing.
 *
 * These are a fallback, not a replacement: the dedicated tables are still
 * preferred, since chat extraction and other paths do write them.
 */

async function latestEventPayload(userId, eventType, dayIso) {
  const row = await db.collection('health_events')
    .find({
      user_id: userId,
      event_type: eventType,
      deleted_at: null,
      timestamp: {
        $gte: new Date(`${dayIso}T00:00:00.000Z`),
        $lte: new Date(`${dayIso}T23:59:59.999Z`),
      },
    })
    .sort({ timestamp: -1 })
    .limit(1)
    .toArray();

  return row[0] ?? null;
}

/** Shaped like `dailyMoodRepository.getDailyMood`, or null. */
export async function moodFromEvents(userId, dayIso) {
  const [moodRow, energyRow, symptomRow] = await Promise.all([
    latestEventPayload(userId, 'mood_logged', dayIso),
    latestEventPayload(userId, 'energy_logged', dayIso),
    latestEventPayload(userId, 'symptom_logged', dayIso),
  ]);

  if (!moodRow && !energyRow) return null;

  return {
    userId,
    entryDate: dayIso,
    // `reportedAs` is the label she picked; the coded value is the fallback.
    mood: moodRow?.payload?.reportedAs ?? moodRow?.payload?.mood ?? null,
    energyLevel: energyRow?.payload?.reportedAs ?? energyRow?.payload?.level ?? null,
    stressLevel: null,
    symptoms: symptomRow?.payload?.symptom ? [symptomRow.payload.symptom] : [],
    notes: '',
    createdAt: (moodRow ?? energyRow)?.created_at?.toISOString?.() ?? null,
    updatedAt: (moodRow ?? energyRow)?.updated_at?.toISOString?.() ?? null,
    source: 'health_events',
  };
}

/** Shaped like `sleepRepository.getSleepByDate`, or null. */
export async function sleepFromEvents(userId, dayIso) {
  const row = await latestEventPayload(userId, 'sleep_logged', dayIso);
  if (!row) return null;

  const hours = Number(row.payload?.durationHours);
  if (!Number.isFinite(hours)) return null;

  return {
    userId,
    entryDate: dayIso,
    sleepTime: null,
    wakeTime: null,
    durationMinutes: Math.round(hours * 60),
    createdAt: row.created_at?.toISOString?.() ?? null,
    updatedAt: row.updated_at?.toISOString?.() ?? null,
    source: 'health_events',
  };
}
