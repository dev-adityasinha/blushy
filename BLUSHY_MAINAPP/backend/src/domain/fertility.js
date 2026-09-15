/**
 * TTC / fertility indicators (spec §13 "TTC FUNCTIONAL REQUIREMENTS",
 * §7 "Fertility may describe fertile window indicators/confidence, not
 * pregnancy probability", §26 "AI MUST NOT BE RESPONSIBLE FOR ... Conception
 * probability").
 *
 * This module deliberately exposes NO probability of conception. It describes
 * indicators and a confidence in the *window*, nothing more.
 */

export const FERTILITY_CALC_VERSION = 'fertility-v1.0.0';

/**
 * Indicator confidence bands. These describe how well the observed signals
 * agree - not the chance of pregnancy.
 */
export const INDICATOR_CONFIDENCE = Object.freeze({
  NONE: 'none',
  LOW: 'low',
  MODERATE: 'moderate',
  HIGH: 'high',
});

const MS_PER_DAY = 86400000;

function dayKey(timestamp) {
  const d = new Date(timestamp);
  return Number.isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10);
}

function daysBetweenKeys(a, b) {
  return Math.round((new Date(`${b}T00:00:00Z`).getTime() - new Date(`${a}T00:00:00Z`).getTime()) / MS_PER_DAY);
}

/**
 * Detects a sustained basal body temperature rise: three consecutive readings
 * above the previous six-day mean by at least `thresholdC`. This is the
 * standard three-over-six rule and is descriptive of a temperature shift only.
 */
export function detectBbtShift(bbtEvents = [], { thresholdC = 0.2 } = {}) {
  const readings = bbtEvents
    .filter((e) => e?.eventType === 'bbt_logged' && !e.deletedAt)
    .map((e) => ({ day: dayKey(e.timestamp), celsius: Number(e?.payload?.celsius), eventId: e.eventId ?? e.id }))
    .filter((r) => r.day && Number.isFinite(r.celsius))
    .sort((a, b) => (a.day < b.day ? -1 : 1));

  if (readings.length < 9) {
    return { detected: false, reason: 'insufficient_readings', requiredReadings: 9, availableReadings: readings.length };
  }

  for (let i = readings.length - 1; i >= 8; i -= 1) {
    const high = readings.slice(i - 2, i + 1);
    const baseline = readings.slice(i - 8, i - 2);
    const baselineMax = Math.max(...baseline.map((r) => r.celsius));
    if (high.every((r) => r.celsius >= baselineMax + thresholdC)) {
      return {
        detected: true,
        shiftStartDay: high[0].day,
        thresholdC,
        baselineMaxC: Math.round(baselineMax * 100) / 100,
        sourceEventIds: [...high, ...baseline].map((r) => r.eventId).filter(Boolean),
        reason: null,
      };
    }
  }

  return { detected: false, reason: 'no_sustained_shift', requiredReadings: 9, availableReadings: readings.length };
}

export function detectLhPeak(lhEvents = []) {
  const peaks = lhEvents
    .filter((e) => e?.eventType === 'lh_test_logged' && !e.deletedAt)
    .filter((e) => ['peak', 'high'].includes(String(e?.payload?.result ?? '').toLowerCase()))
    .map((e) => ({ day: dayKey(e.timestamp), result: e.payload.result, eventId: e.eventId ?? e.id }))
    .filter((r) => r.day)
    .sort((a, b) => (a.day < b.day ? 1 : -1));

  if (peaks.length === 0) return { detected: false, reason: 'no_positive_test' };
  return { detected: true, day: peaks[0].day, result: peaks[0].result, sourceEventIds: [peaks[0].eventId].filter(Boolean), reason: null };
}

export function detectFertileMucus(mucusEvents = []) {
  const fertile = mucusEvents
    .filter((e) => e?.eventType === 'cervical_mucus_logged' && !e.deletedAt)
    .filter((e) => ['egg_white', 'watery'].includes(String(e?.payload?.observation ?? '').toLowerCase()))
    .map((e) => ({ day: dayKey(e.timestamp), observation: e.payload.observation, eventId: e.eventId ?? e.id }))
    .filter((r) => r.day)
    .sort((a, b) => (a.day < b.day ? 1 : -1));

  if (fertile.length === 0) return { detected: false, reason: 'no_fertile_observation' };
  return { detected: true, day: fertile[0].day, observation: fertile[0].observation, sourceEventIds: [fertile[0].eventId].filter(Boolean), reason: null };
}

/**
 * Builds the fertility indicator summary.
 *
 * @param {object} params
 * @param {Array}  params.events            fertility-related health events
 * @param {object} params.cyclePrediction   output of the cycle service (may be null)
 * @param {string} params.referenceDate     YYYY-MM-DD
 * @param {boolean} params.ttcOptedIn       fertility stays separate unless opted in (spec §5)
 */
export function buildFertilityIndicators({ events = [], cyclePrediction = null, referenceDate = null, ttcOptedIn = false } = {}) {
  if (!ttcOptedIn) {
    return {
      state: 'restricted',
      reason: 'ttc_not_opted_in',
      calculationVersion: FERTILITY_CALC_VERSION,
      indicators: [],
      fertileWindow: null,
      confidence: INDICATOR_CONFIDENCE.NONE,
      conceptionProbability: null,
      disclaimer: 'Fertility tracking is separate from cycle tracking. Turn it on to see indicators.',
    };
  }

  const today = referenceDate ?? new Date().toISOString().slice(0, 10);
  const indicators = [];
  const sourceEventIds = [];

  const bbt = detectBbtShift(events);
  if (bbt.detected) {
    indicators.push({
      key: 'bbt_shift',
      label: 'Sustained temperature rise',
      observedOn: bbt.shiftStartDay,
      description: 'Your logged temperatures show a sustained rise, which typically follows ovulation.',
      source: 'manual',
    });
    sourceEventIds.push(...(bbt.sourceEventIds ?? []));
  }

  const lh = detectLhPeak(events);
  if (lh.detected) {
    indicators.push({
      key: 'lh_surge',
      label: 'Positive LH test',
      observedOn: lh.day,
      description: 'You logged a positive LH test, which typically precedes ovulation by 12 to 36 hours.',
      source: 'manual',
    });
    sourceEventIds.push(...(lh.sourceEventIds ?? []));
  }

  const mucus = detectFertileMucus(events);
  if (mucus.detected) {
    indicators.push({
      key: 'cervical_mucus',
      label: 'Fertile-type cervical mucus',
      observedOn: mucus.day,
      description: 'You logged fertile-type cervical mucus, which commonly appears in the days before ovulation.',
      source: 'manual',
    });
    sourceEventIds.push(...(mucus.sourceEventIds ?? []));
  }

  // Calendar-based window from the cycle service, when it has enough history.
  let fertileWindow = null;
  if (cyclePrediction?.prediction?.fertileWindowStart && cyclePrediction?.prediction?.fertileWindowEnd) {
    fertileWindow = {
      start: cyclePrediction.prediction.fertileWindowStart,
      end: cyclePrediction.prediction.fertileWindowEnd,
      estimatedOvulationDate: cyclePrediction.prediction.estimatedOvulationDate ?? null,
      basis: 'logged_cycle_history',
      calculationVersion: cyclePrediction.algorithmVersion ?? null,
    };
    indicators.push({
      key: 'calendar_window',
      label: 'Estimated fertile window',
      observedOn: today,
      description: 'Estimated from your logged cycle history. Timing varies between cycles.',
      source: 'rule',
    });
  }

  // Confidence describes agreement between independent indicators.
  const observedSignals = indicators.filter((i) => i.key !== 'calendar_window').length;
  let confidence = INDICATOR_CONFIDENCE.NONE;
  if (observedSignals >= 3) confidence = INDICATOR_CONFIDENCE.HIGH;
  else if (observedSignals === 2) confidence = INDICATOR_CONFIDENCE.MODERATE;
  else if (observedSignals === 1) confidence = INDICATOR_CONFIDENCE.LOW;
  else if (fertileWindow) confidence = INDICATOR_CONFIDENCE.LOW;

  if (indicators.length === 0) {
    return {
      state: 'insufficient_data',
      reason: 'no_indicators_logged',
      calculationVersion: FERTILITY_CALC_VERSION,
      indicators: [],
      fertileWindow: null,
      confidence: INDICATOR_CONFIDENCE.NONE,
      conceptionProbability: null,
      sourceEventIds: [],
      disclaimer: 'Log BBT, LH tests or cervical mucus observations to see fertility indicators.',
    };
  }

  return {
    state: 'ready',
    reason: null,
    calculationVersion: FERTILITY_CALC_VERSION,
    indicators,
    fertileWindow,
    confidence,
    // Explicitly null and explicitly documented: consumer tracking cannot
    // produce this number, so Blushy does not display one.
    conceptionProbability: null,
    sourceEventIds: [...new Set(sourceEventIds)],
    disclaimer: 'These are observations of what you logged. Blushy does not estimate the chance of conception, and this is not a contraceptive method.',
  };
}

/**
 * Monthly TTC reflection states (spec §12 "REFLECTIONS", §13).
 * Emotionally neutral handling of a cycle that ended without pregnancy.
 */
export const TTC_REFLECTION_STATES = Object.freeze({
  PREGNANCY_CONFIRMED: 'pregnancy_confirmed',
  CYCLE_COMPLETED_NO_PREGNANCY: 'cycle_completed_without_pregnancy',
  INCOMPLETE: 'incomplete_or_unknown',
});

export const TTC_REFLECTION_PROMPTS = Object.freeze({
  [TTC_REFLECTION_STATES.PREGNANCY_CONFIRMED]: 'What would you like to remember about this month?',
  [TTC_REFLECTION_STATES.CYCLE_COMPLETED_NO_PREGNANCY]: 'This cycle has completed. How are you feeling, and is there anything you want to carry into next month?',
  [TTC_REFLECTION_STATES.INCOMPLETE]: 'How did this month feel for you?',
});

export function ttcDurationSummary({ ttcStartDate, referenceDate = null } = {}) {
  if (!ttcStartDate) {
    return { state: 'insufficient_data', months: null, days: null, reason: 'no_start_date' };
  }
  const start = new Date(`${String(ttcStartDate).slice(0, 10)}T00:00:00Z`).getTime();
  const end = referenceDate
    ? new Date(`${String(referenceDate).slice(0, 10)}T00:00:00Z`).getTime()
    : Date.now();

  if (!Number.isFinite(start) || end < start) {
    return { state: 'insufficient_data', months: null, days: null, reason: 'invalid_start_date' };
  }

  const days = Math.floor((end - start) / MS_PER_DAY);
  return { state: 'ready', days, months: Math.floor(days / 30.44), reason: null };
}
