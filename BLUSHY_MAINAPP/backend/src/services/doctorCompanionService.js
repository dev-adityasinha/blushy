import { randomUUID } from 'node:crypto';
import { listEvents } from '../repositories/healthEventRepository.js';
import { listInsights } from '../repositories/insightRepository.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { listScreenings } from '../repositories/screeningRepository.js';
import { normalizeLifeStage } from '../domain/lifeStages.js';
import { db } from '../utils/db.js';
import { RESPONSE_STATES, SOURCES } from '../utils/apiResponse.js';

/**
 * Doctor / appointment companion (spec §18).
 *
 * Builds an appointment-ready summary from user-approved logs over a chosen
 * date range. Every line is labelled as user-reported or app-generated, entries
 * can be removed before export, and nothing is ever labelled a diagnosis.
 */

const COLLECTION = 'doctor_summaries';
const SUMMARY_VERSION = 'doctor-summary-v1.0.0';

const SUMMARY_EVENT_TYPES = [
  'symptom_logged', 'pain_logged', 'mood_logged', 'sleep_logged',
  'energy_logged', 'period_logged', 'hot_flash_logged', 'recovery_metric_logged',
  'appointment_logged', 'condition_reported',
];

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

function groupSymptoms(events) {
  const grouped = new Map();
  for (const event of events) {
    if (event.eventType !== 'symptom_logged' && event.eventType !== 'pain_logged') continue;
    const name = event.eventType === 'pain_logged'
      ? `Pain${event.payload?.location ? ` (${event.payload.location})` : ''}`
      : event.payload?.symptom;
    if (!name) continue;

    const bucket = grouped.get(name) ?? { name, occurrences: 0, severities: [], firstSeen: event.timestamp, lastSeen: event.timestamp, eventIds: [] };
    bucket.occurrences += 1;
    const severity = Number(event.payload?.severity);
    if (Number.isFinite(severity)) bucket.severities.push(severity);
    if (event.timestamp < bucket.firstSeen) bucket.firstSeen = event.timestamp;
    if (event.timestamp > bucket.lastSeen) bucket.lastSeen = event.timestamp;
    bucket.eventIds.push(event.eventId);
    grouped.set(name, bucket);
  }

  return [...grouped.values()]
    .map((bucket) => ({
      ...bucket,
      averageSeverity: bucket.severities.length > 0
        ? Math.round((bucket.severities.reduce((s, v) => s + v, 0) / bucket.severities.length) * 10) / 10
        : null,
      maxSeverity: bucket.severities.length > 0 ? Math.max(...bucket.severities) : null,
      // Every symptom line is what the user typed, not a clinical finding.
      provenance: 'user_reported',
    }))
    .sort((a, b) => b.occurrences - a.occurrences);
}

/**
 * Generates a draft summary. Nothing is persisted until the user saves it, so a
 * preview never becomes a record by accident.
 */
export async function buildSummary(userId, { from, to, includeInsights = true, includeScreenings = false } = {}) {
  const stageState = await getLifeStageState(userId);
  const lifeStage = normalizeLifeStage(stageState.lifeStage, null);

  const events = await listEvents(userId, {
    eventTypes: SUMMARY_EVENT_TYPES,
    from,
    to,
    limit: 500,
  });

  if (events.length === 0) {
    return {
      state: RESPONSE_STATES.EMPTY,
      version: SUMMARY_VERSION,
      data: { from, to, lifeStage, sections: [], message: 'No logs in this date range.' },
    };
  }

  const symptomSummary = groupSymptoms(events);

  const periods = events
    .filter((event) => event.eventType === 'period_logged')
    .map((event) => ({ startDate: event.payload?.startDate, flow: event.payload?.flow ?? null, eventId: event.eventId }));

  const sleep = events.filter((event) => event.eventType === 'sleep_logged');
  const sleepHours = sleep.map((event) => Number(event.payload?.durationHours)).filter(Number.isFinite);

  const moods = events.filter((event) => event.eventType === 'mood_logged');
  const moodCounts = {};
  for (const event of moods) {
    const mood = String(event.payload?.mood ?? 'unknown');
    moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
  }

  const conditions = events
    .filter((event) => event.eventType === 'condition_reported')
    .flatMap((event) => event.payload?.conditions ?? []);

  const sections = [
    {
      key: 'conditions',
      title: 'Conditions I have told the app about',
      provenance: 'user_reported',
      items: [...new Set(conditions)].map((condition) => ({ text: condition })),
    },
    {
      key: 'symptoms',
      title: 'Symptoms logged in this period',
      provenance: 'user_reported',
      items: symptomSummary.map((entry) => ({
        text: `${entry.name}: logged ${entry.occurrences} time(s)${entry.averageSeverity !== null ? `, average severity ${entry.averageSeverity}/10 (peak ${entry.maxSeverity}/10)` : ''}`,
        eventIds: entry.eventIds,
        firstSeen: entry.firstSeen,
        lastSeen: entry.lastSeen,
      })),
    },
    {
      key: 'cycle',
      title: 'Period starts logged',
      provenance: 'user_reported',
      items: periods.map((period) => ({
        text: `${period.startDate}${period.flow ? ` (${period.flow} flow)` : ''}`,
        eventIds: [period.eventId],
      })),
    },
    {
      key: 'sleep',
      title: 'Sleep',
      provenance: 'user_reported',
      items: sleepHours.length > 0
        ? [{
          text: `Average logged sleep ${Math.round((sleepHours.reduce((s, v) => s + v, 0) / sleepHours.length) * 10) / 10} hours across ${sleepHours.length} night(s)`,
          eventIds: sleep.map((event) => event.eventId),
        }]
        : [],
    },
    {
      key: 'mood',
      title: 'Mood',
      provenance: 'user_reported',
      items: Object.entries(moodCounts).map(([mood, count]) => ({
        text: `${mood}: ${count} day(s)`,
      })),
    },
  ];

  if (includeInsights) {
    const insights = await listInsights(userId, { limit: 5 });
    sections.push({
      key: 'app_observations',
      title: 'Patterns the app noticed',
      // Clearly separated from what the user reported (spec §18).
      provenance: 'app_generated',
      items: insights.map((insight) => ({
        text: insight.description,
        confidence: insight.confidence,
        eventIds: insight.sourceEventIds,
      })),
    });
  }

  if (includeScreenings) {
    const screenings = await listScreenings(userId, { limit: 5 });
    sections.push({
      key: 'screenings',
      title: 'Screening questionnaires completed',
      provenance: 'app_generated',
      items: screenings.map((screening) => ({
        text: `${screening.instrumentName} (${screening.instrumentVersion}): score ${screening.totalScore}/${screening.maxScore} on ${String(screening.completedAt).slice(0, 10)}`,
        instrumentId: screening.instrumentId,
      })),
    });
  }

  return {
    state: RESPONSE_STATES.READY,
    version: SUMMARY_VERSION,
    source: SOURCES.MANUAL,
    data: {
      from,
      to,
      lifeStage,
      sections: sections.filter((section) => section.items.length > 0),
      questions: [],
      // Stated on the object itself so no client can render this as clinical
      // fact (spec §18: "Never label as a diagnosis").
      isDiagnosis: false,
      disclaimer: 'Prepared from what you logged in Blushy. This is a record of self-reported information and app-generated observations, not a diagnosis.',
    },
  };
}

/**
 * Saves a summary after the user has removed anything they do not want to
 * share and added their own questions.
 */
export async function saveSummary(userId, { from, to, sections, questions = [], title = null }) {
  const uid = cleanUserId(userId);
  const doc = {
    summary_id: randomUUID(),
    user_id: uid,
    title: title ? String(title).slice(0, 200) : `Appointment summary ${new Date().toISOString().slice(0, 10)}`,
    range_from: from,
    range_to: to,
    sections,
    questions: (Array.isArray(questions) ? questions : []).slice(0, 30).map((q) => String(q).slice(0, 500)),
    version: SUMMARY_VERSION,
    is_diagnosis: false,
    created_at: new Date(),
    updated_at: new Date(),
  };

  await db.collection(COLLECTION).insertOne(doc);
  return mapSummary(doc);
}

function mapSummary(row) {
  if (!row) return null;
  return {
    summaryId: row.summary_id,
    title: row.title,
    from: row.range_from,
    to: row.range_to,
    sections: row.sections ?? [],
    questions: row.questions ?? [],
    version: row.version,
    isDiagnosis: false,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

export async function listSummaries(userId, { limit = 20 } = {}) {
  const rows = await db.collection(COLLECTION)
    .find({ user_id: cleanUserId(userId) })
    .sort({ created_at: -1 })
    .limit(Math.min(limit, 50))
    .toArray();
  return rows.map(mapSummary);
}

export async function getSummary(userId, summaryId) {
  const row = await db.collection(COLLECTION).findOne({ user_id: cleanUserId(userId), summary_id: summaryId });
  return mapSummary(row);
}

export async function deleteSummary(userId, summaryId) {
  const result = await db.collection(COLLECTION).deleteOne({ user_id: cleanUserId(userId), summary_id: summaryId });
  return result.deletedCount > 0;
}
