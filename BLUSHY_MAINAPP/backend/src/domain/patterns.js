/**
 * Deterministic pattern detection (spec §7 "Patterns & Insights",
 * §8 "PATTERNS & INSIGHTS -- FUNCTIONAL, NOT STATIC").
 *
 * Patterns are aggregate trends and correlations computed from stored events.
 * They are NOT causal claims and NOT diagnoses. Every emitted insight carries
 * its source event IDs, time window, strength, generation time and version so
 * it can be invalidated when its source data is deleted.
 *
 * The AI never computes these numbers; it may only phrase what is here.
 */

export const PATTERN_ENGINE_VERSION = 'patterns-v1.0.0';

export const INSIGHT_STATUS = Object.freeze({
  ACTIVE: 'active',
  DISMISSED: 'dismissed',
  EXPIRED: 'expired',
  INVALIDATED: 'invalidated',
});

/**
 * Minimum evidence before anything is shown. Below this the API must return
 * `insufficient_data`, never a softened claim.
 */
export const MIN_PAIRED_OBSERVATIONS = 6;
export const MIN_OCCURRENCES_FOR_FREQUENCY = 4;
export const DEFAULT_WINDOW_DAYS = 60;
export const INSIGHT_TTL_DAYS = 14;

function dayKey(timestamp) {
  const d = new Date(timestamp);
  return Number.isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10);
}

function mean(values) {
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

/**
 * Pearson correlation. Returns null when the sample is too small or either
 * series has no variance (a flat series cannot correlate with anything).
 */
export function correlation(xs, ys) {
  if (!Array.isArray(xs) || !Array.isArray(ys)) return null;
  if (xs.length !== ys.length || xs.length < MIN_PAIRED_OBSERVATIONS) return null;

  const mx = mean(xs);
  const my = mean(ys);
  let num = 0;
  let dx = 0;
  let dy = 0;

  for (let i = 0; i < xs.length; i += 1) {
    const a = xs[i] - mx;
    const b = ys[i] - my;
    num += a * b;
    dx += a * a;
    dy += b * b;
  }

  if (dx === 0 || dy === 0) return null;
  return num / Math.sqrt(dx * dy);
}

/**
 * Maps |r| onto a descriptive strength label. Deliberately conservative: this
 * is pattern strength, never medical certainty (spec §8 table).
 */
export function strengthLabel(r) {
  const abs = Math.abs(r);
  if (abs >= 0.7) return 'strong';
  if (abs >= 0.5) return 'moderate';
  if (abs >= 0.3) return 'weak';
  return 'negligible';
}

const MIN_REPORTABLE_CORRELATION = 0.4;

/**
 * Groups numeric daily values out of an event list.
 * `extract` returns a number or null for a given event.
 */
function dailyValues(events, eventType, extract) {
  const byDay = new Map();
  for (const event of events) {
    if (event.eventType !== eventType) continue;
    const key = dayKey(event.timestamp);
    if (!key) continue;
    const value = extract(event);
    if (value === null || value === undefined || !Number.isFinite(value)) continue;
    const bucket = byDay.get(key) ?? { values: [], eventIds: [] };
    bucket.values.push(value);
    bucket.eventIds.push(event.eventId ?? event.id);
    byDay.set(key, bucket);
  }
  const out = new Map();
  for (const [key, bucket] of byDay.entries()) {
    out.set(key, { value: mean(bucket.values), eventIds: bucket.eventIds });
  }
  return out;
}

const MOOD_SCORES = { awful: 1, low: 2, sad: 2, anxious: 2, irritable: 2, okay: 3, calm: 4, good: 4, great: 5, energised: 5 };

function moodToScore(event) {
  const mood = String(event?.payload?.mood ?? '').toLowerCase();
  const base = MOOD_SCORES[mood];
  if (base === undefined) return null;
  return base;
}

/**
 * Correlation pairs the engine looks for. `lagDays: 1` means yesterday's X is
 * compared with today's Y (sleep last night vs mood today).
 */
const CORRELATION_PAIRS = [
  {
    type: 'sleep_mood',
    xType: 'sleep_logged',
    yType: 'mood_logged',
    xExtract: (e) => Number(e?.payload?.durationHours),
    yExtract: moodToScore,
    lagDays: 1,
    title: 'Sleep and mood',
    describe: (r) => (r > 0
      ? 'Based on your recent logs, days after longer sleep tend to be logged with a brighter mood.'
      : 'Based on your recent logs, days after longer sleep tend to be logged with a lower mood.'),
  },
  {
    type: 'sleep_energy',
    xType: 'sleep_logged',
    yType: 'energy_logged',
    xExtract: (e) => Number(e?.payload?.durationHours),
    yExtract: (e) => Number(e?.payload?.level),
    lagDays: 1,
    title: 'Sleep and energy',
    describe: (r) => (r > 0
      ? 'Based on your recent logs, longer sleep tends to be followed by higher logged energy.'
      : 'Based on your recent logs, longer sleep tends to be followed by lower logged energy.'),
  },
  {
    type: 'stress_sleep',
    xType: 'stress_logged',
    yType: 'sleep_logged',
    xExtract: (e) => Number(e?.payload?.level),
    yExtract: (e) => Number(e?.payload?.durationHours),
    lagDays: 0,
    title: 'Stress and sleep',
    describe: (r) => (r < 0
      ? 'Based on your recent logs, higher logged stress tends to appear alongside shorter sleep.'
      : 'Based on your recent logs, higher logged stress tends to appear alongside longer sleep.'),
  },
  {
    type: 'pain_energy',
    xType: 'pain_logged',
    yType: 'energy_logged',
    xExtract: (e) => Number(e?.payload?.severity),
    yExtract: (e) => Number(e?.payload?.level),
    lagDays: 0,
    title: 'Pain and energy',
    describe: (r) => (r < 0
      ? 'Based on your recent logs, days with higher logged pain tend to be days with lower logged energy.'
      : 'Based on your recent logs, days with higher logged pain tend to be days with higher logged energy.'),
  },
  {
    type: 'hydration_energy',
    xType: 'hydration_logged',
    yType: 'energy_logged',
    xExtract: (e) => Number(e?.payload?.glasses),
    yExtract: (e) => Number(e?.payload?.level),
    lagDays: 0,
    title: 'Hydration and energy',
    describe: (r) => (r > 0
      ? 'Based on your recent logs, days with more water logged tend to show higher logged energy.'
      : 'Based on your recent logs, days with more water logged tend to show lower logged energy.'),
  },
];

function shiftDay(dayString, days) {
  const d = new Date(`${dayString}T00:00:00.000Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/**
 * Computes correlation-based insights.
 * Returns an array of structured insight candidates (never persisted here).
 */
function computeCorrelationInsights(events, windowStart, windowEnd) {
  const insights = [];

  for (const pair of CORRELATION_PAIRS) {
    const xs = dailyValues(events, pair.xType, pair.xExtract);
    const ys = dailyValues(events, pair.yType, pair.yExtract);
    if (xs.size === 0 || ys.size === 0) continue;

    const xSeries = [];
    const ySeries = [];
    const sourceEventIds = [];

    for (const [day, xEntry] of xs.entries()) {
      const targetDay = pair.lagDays ? shiftDay(day, pair.lagDays) : day;
      const yEntry = ys.get(targetDay);
      if (!yEntry) continue;
      xSeries.push(xEntry.value);
      ySeries.push(yEntry.value);
      sourceEventIds.push(...xEntry.eventIds, ...yEntry.eventIds);
    }

    const r = correlation(xSeries, ySeries);
    if (r === null) continue;
    if (Math.abs(r) < MIN_REPORTABLE_CORRELATION) continue;

    insights.push({
      type: pair.type,
      title: pair.title,
      description: pair.describe(r),
      sourceEventIds: [...new Set(sourceEventIds)],
      periodStart: windowStart,
      periodEnd: windowEnd,
      confidence: Math.round(Math.abs(r) * 100) / 100,
      strength: strengthLabel(r),
      direction: r > 0 ? 'positive' : 'negative',
      observationCount: xSeries.length,
      // Explicitly stated so no downstream surface can promote it.
      causalClaim: false,
      status: INSIGHT_STATUS.ACTIVE,
      engineVersion: PATTERN_ENGINE_VERSION,
      source: 'rule',
    });
  }

  return insights;
}

/**
 * Frequency insights: which symptoms recur, and how often. Purely descriptive.
 */
function computeSymptomFrequencyInsights(events, windowStart, windowEnd) {
  const bySymptom = new Map();

  for (const event of events) {
    if (event.eventType !== 'symptom_logged') continue;
    const symptom = String(event?.payload?.symptom ?? '').toLowerCase().trim();
    if (!symptom) continue;
    const bucket = bySymptom.get(symptom) ?? { days: new Set(), eventIds: [], severities: [] };
    const key = dayKey(event.timestamp);
    if (key) bucket.days.add(key);
    bucket.eventIds.push(event.eventId ?? event.id);
    const severity = Number(event?.payload?.severity);
    if (Number.isFinite(severity)) bucket.severities.push(severity);
    bySymptom.set(symptom, bucket);
  }

  const insights = [];
  for (const [symptom, bucket] of bySymptom.entries()) {
    if (bucket.days.size < MIN_OCCURRENCES_FOR_FREQUENCY) continue;
    const avgSeverity = bucket.severities.length > 0
      ? Math.round(mean(bucket.severities) * 10) / 10
      : null;

    insights.push({
      type: 'symptom_pattern',
      title: `${symptom.charAt(0).toUpperCase()}${symptom.slice(1)} is recurring`,
      description: `Based on your recent logs, you recorded ${symptom} on ${bucket.days.size} days${avgSeverity !== null ? `, with an average logged severity of ${avgSeverity}/10` : ''}.`,
      sourceEventIds: [...new Set(bucket.eventIds)],
      periodStart: windowStart,
      periodEnd: windowEnd,
      // Frequency confidence scales with how much evidence there is, capped so
      // it never reads as certainty.
      confidence: Math.min(0.9, Math.round((bucket.days.size / 20) * 100) / 100),
      strength: bucket.days.size >= 10 ? 'strong' : 'moderate',
      direction: null,
      observationCount: bucket.days.size,
      causalClaim: false,
      status: INSIGHT_STATUS.ACTIVE,
      engineVersion: PATTERN_ENGINE_VERSION,
      source: 'rule',
      metadata: { symptom, averageSeverity: avgSeverity },
    });
  }

  return insights;
}

/**
 * Cycle-phase timing insight: do symptoms cluster in a particular part of the
 * cycle? Only runs when cycle day is supplied per event by the caller, and only
 * for branches where cycle language is appropriate.
 */
function computeCyclePhaseInsights(events, windowStart, windowEnd, cycleDayResolver) {
  if (typeof cycleDayResolver !== 'function') return [];

  const bySymptom = new Map();
  for (const event of events) {
    if (event.eventType !== 'symptom_logged') continue;
    const cycleDay = cycleDayResolver(event.timestamp);
    if (!Number.isFinite(cycleDay)) continue;
    const symptom = String(event?.payload?.symptom ?? '').toLowerCase().trim();
    if (!symptom) continue;
    const bucket = bySymptom.get(symptom) ?? { days: [], eventIds: [] };
    bucket.days.push(cycleDay);
    bucket.eventIds.push(event.eventId ?? event.id);
    bySymptom.set(symptom, bucket);
  }

  const insights = [];
  for (const [symptom, bucket] of bySymptom.entries()) {
    if (bucket.days.length < MIN_OCCURRENCES_FOR_FREQUENCY) continue;
    const avgDay = mean(bucket.days);
    const spread = Math.sqrt(mean(bucket.days.map((d) => (d - avgDay) ** 2)));
    // Only report when the occurrences actually cluster.
    if (spread > 5) continue;

    insights.push({
      type: 'cycle_pattern',
      title: `${symptom.charAt(0).toUpperCase()}${symptom.slice(1)} around cycle day ${Math.round(avgDay)}`,
      description: `Based on your recent logs, ${symptom} was most often recorded around day ${Math.round(avgDay)} of your cycle.`,
      sourceEventIds: [...new Set(bucket.eventIds)],
      periodStart: windowStart,
      periodEnd: windowEnd,
      confidence: Math.min(0.85, Math.round((1 - spread / 10) * 100) / 100),
      strength: spread <= 2 ? 'strong' : 'moderate',
      direction: null,
      observationCount: bucket.days.length,
      causalClaim: false,
      status: INSIGHT_STATUS.ACTIVE,
      engineVersion: PATTERN_ENGINE_VERSION,
      source: 'rule',
      metadata: { symptom, averageCycleDay: Math.round(avgDay * 10) / 10, spreadDays: Math.round(spread * 10) / 10 },
    });
  }

  return insights;
}

/**
 * Main entry point.
 *
 * @param {object} params
 * @param {Array}  params.events            health events, newest or oldest first
 * @param {number} params.windowDays        analysis window
 * @param {Date}   params.referenceDate
 * @param {Function} params.cycleDayResolver optional (timestamp) => cycleDay
 * @param {boolean} params.allowCycleInsights false for menopause/pregnancy branches
 * @returns {{ state: string, insights: Array, windowStart: string, windowEnd: string, engineVersion: string, reason: string|null }}
 */
export function computePatterns({
  events = [],
  windowDays = DEFAULT_WINDOW_DAYS,
  referenceDate = new Date(),
  cycleDayResolver = null,
  allowCycleInsights = true,
} = {}) {
  const end = referenceDate instanceof Date ? referenceDate : new Date(referenceDate);
  const start = new Date(end.getTime() - windowDays * 86400000);
  const windowStart = start.toISOString();
  const windowEnd = end.toISOString();

  const inWindow = events.filter((event) => {
    if (event?.deletedAt) return false;
    // AI-derived events are never evidence for a pattern (spec §6).
    if (event?.source === 'ai_derived') return false;
    const ts = new Date(event?.timestamp).getTime();
    return Number.isFinite(ts) && ts >= start.getTime() && ts <= end.getTime();
  });

  if (inWindow.length === 0) {
    return {
      state: 'empty',
      insights: [],
      windowStart,
      windowEnd,
      engineVersion: PATTERN_ENGINE_VERSION,
      reason: 'no_events',
    };
  }

  const insights = [
    ...computeCorrelationInsights(inWindow, windowStart, windowEnd),
    ...computeSymptomFrequencyInsights(inWindow, windowStart, windowEnd),
    ...(allowCycleInsights ? computeCyclePhaseInsights(inWindow, windowStart, windowEnd, cycleDayResolver) : []),
  ];

  if (insights.length === 0) {
    return {
      state: 'insufficient_data',
      insights: [],
      windowStart,
      windowEnd,
      engineVersion: PATTERN_ENGINE_VERSION,
      reason: 'not_enough_paired_observations',
    };
  }

  insights.sort((a, b) => b.confidence - a.confidence);

  return {
    state: 'ready',
    insights,
    windowStart,
    windowEnd,
    engineVersion: PATTERN_ENGINE_VERSION,
    reason: null,
  };
}

/**
 * Given a set of deleted event IDs, returns the insights that must be
 * invalidated (spec §7: "Deleted source logs must invalidate or recalculate
 * dependent insights").
 */
export function findInsightsInvalidatedBy(insights = [], deletedEventIds = []) {
  const deleted = new Set(deletedEventIds.map(String));
  if (deleted.size === 0) return [];
  return insights.filter((insight) =>
    Array.isArray(insight?.sourceEventIds) &&
    insight.sourceEventIds.some((id) => deleted.has(String(id))),
  );
}

export function isInsightExpired(insight, referenceDate = new Date()) {
  if (!insight?.generatedAt) return false;
  const generated = new Date(insight.generatedAt).getTime();
  if (!Number.isFinite(generated)) return false;
  const ageDays = (referenceDate.getTime() - generated) / 86400000;
  return ageDays > INSIGHT_TTL_DAYS;
}
