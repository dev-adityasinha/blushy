/**
 * Validated screening instrument scoring (spec §16 "Postpartum Mental Health",
 * §26 "AI MUST NOT BE RESPONSIBLE FOR ... Validated screening scoring").
 *
 * Scoring is deterministic and versioned. The instrument's validated item
 * wording is NOT hardcoded here: it is licensed clinical content and must be
 * served from the medical content service, which carries source, reviewer,
 * version and review date. This module owns the structure, the scoring maths,
 * the reverse-scored items and the escalation thresholds.
 *
 * A result is never a diagnosis (spec §16: "Do not diagnose from app logs").
 */

export const SCREENING_ENGINE_VERSION = 'screening-v1.0.0';

export const SCREENING_OUTCOMES = Object.freeze({
  BELOW_THRESHOLD: 'below_threshold',
  POSSIBLE_CONCERN: 'possible_concern',
  CONCERNING: 'concerning',
  CRISIS: 'crisis',
});

/**
 * Instrument definitions.
 *
 * itemCount / optionScores / reverseScoredItems / thresholds are the validated
 * structural facts of each instrument. `contentId` resolves the licensed item
 * wording through the medical content service so the app always displays the
 * validated text rather than a paraphrase.
 */
export const INSTRUMENTS = Object.freeze({
  EPDS: {
    id: 'EPDS',
    name: 'Edinburgh Postnatal Depression Scale',
    version: '1987.1',
    itemCount: 10,
    optionScores: [0, 1, 2, 3],
    // Items 1, 2 and 4 are scored in the printed order; the remainder are
    // reverse scored (3,2,1,0). Zero-indexed here.
    reverseScoredItemIndexes: [2, 4, 5, 6, 7, 8, 9],
    maxScore: 30,
    // Item 10 is the self-harm item: any non-zero answer escalates regardless
    // of total score.
    crisisItemIndex: 9,
    thresholds: [
      { min: 0, max: 9, outcome: SCREENING_OUTCOMES.BELOW_THRESHOLD },
      { min: 10, max: 12, outcome: SCREENING_OUTCOMES.POSSIBLE_CONCERN },
      { min: 13, max: 30, outcome: SCREENING_OUTCOMES.CONCERNING },
    ],
    contentId: 'mc_instrument_epds_items',
    source: 'Cox JL, Holden JM, Sagovsky R. Br J Psychiatry 1987;150:782-786',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    appliesToLifeStages: ['postpartum', 'pregnancy'],
    // Checkpoints in days from the postpartum start date (spec: "Use clinically
    // approved checkpoints").
    checkpointDays: [14, 42, 90, 180],
    licensedWordingRequired: true,
  },

  PHQ9: {
    id: 'PHQ9',
    name: 'Patient Health Questionnaire-9',
    version: '1999.1',
    itemCount: 9,
    optionScores: [0, 1, 2, 3],
    reverseScoredItemIndexes: [],
    maxScore: 27,
    crisisItemIndex: 8,
    thresholds: [
      { min: 0, max: 4, outcome: SCREENING_OUTCOMES.BELOW_THRESHOLD },
      { min: 5, max: 9, outcome: SCREENING_OUTCOMES.POSSIBLE_CONCERN },
      { min: 10, max: 27, outcome: SCREENING_OUTCOMES.CONCERNING },
    ],
    contentId: 'mc_instrument_phq9_items',
    source: 'Kroenke K, Spitzer RL, Williams JB. J Gen Intern Med 2001;16:606-613',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    appliesToLifeStages: ['postpartum', 'pregnancy', 'perimenopause', 'menopause', 'everyday_wellness', 'hormonal_health'],
    checkpointDays: [],
    licensedWordingRequired: true,
  },

  GAD7: {
    id: 'GAD7',
    name: 'Generalised Anxiety Disorder-7',
    version: '2006.1',
    itemCount: 7,
    optionScores: [0, 1, 2, 3],
    reverseScoredItemIndexes: [],
    maxScore: 21,
    crisisItemIndex: null,
    thresholds: [
      { min: 0, max: 4, outcome: SCREENING_OUTCOMES.BELOW_THRESHOLD },
      { min: 5, max: 9, outcome: SCREENING_OUTCOMES.POSSIBLE_CONCERN },
      { min: 10, max: 21, outcome: SCREENING_OUTCOMES.CONCERNING },
    ],
    contentId: 'mc_instrument_gad7_items',
    source: 'Spitzer RL, Kroenke K, Williams JB, Löwe B. Arch Intern Med 2006;166:1092-1097',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    appliesToLifeStages: ['postpartum', 'pregnancy', 'perimenopause', 'menopause', 'everyday_wellness', 'hormonal_health'],
    checkpointDays: [],
    licensedWordingRequired: true,
  },
});

export function getInstrument(instrumentId) {
  if (typeof instrumentId !== 'string') return null;
  return INSTRUMENTS[instrumentId.trim().toUpperCase()] ?? null;
}

/**
 * Scores a completed screening.
 *
 * @param {string} instrumentId
 * @param {number[]} responses raw option indexes as presented to the user
 * @returns {{ ok: boolean, error?: string, result?: object }}
 */
export function scoreScreening(instrumentId, responses) {
  const instrument = getInstrument(instrumentId);
  if (!instrument) {
    return { ok: false, error: `Unknown screening instrument: ${instrumentId}.` };
  }

  if (!Array.isArray(responses) || responses.length !== instrument.itemCount) {
    return { ok: false, error: `${instrument.id} requires exactly ${instrument.itemCount} responses.` };
  }

  const maxOptionIndex = instrument.optionScores.length - 1;
  const itemScores = [];

  for (let i = 0; i < responses.length; i += 1) {
    const raw = Number(responses[i]);
    if (!Number.isInteger(raw) || raw < 0 || raw > maxOptionIndex) {
      return { ok: false, error: `Response ${i + 1} must be an integer between 0 and ${maxOptionIndex}.` };
    }
    const reversed = instrument.reverseScoredItemIndexes.includes(i);
    const score = reversed ? instrument.optionScores[maxOptionIndex - raw] : instrument.optionScores[raw];
    itemScores.push(score);
  }

  const totalScore = itemScores.reduce((sum, value) => sum + value, 0);

  let outcome = SCREENING_OUTCOMES.BELOW_THRESHOLD;
  for (const band of instrument.thresholds) {
    if (totalScore >= band.min && totalScore <= band.max) {
      outcome = band.outcome;
      break;
    }
  }

  // Any positive answer on the self-harm item escalates to crisis regardless of
  // the total, and suppresses ordinary wellness content.
  let crisisItemPositive = false;
  if (instrument.crisisItemIndex !== null && instrument.crisisItemIndex !== undefined) {
    crisisItemPositive = itemScores[instrument.crisisItemIndex] > 0;
    if (crisisItemPositive) {
      outcome = SCREENING_OUTCOMES.CRISIS;
    }
  }

  const requiresProfessionalSupport =
    outcome === SCREENING_OUTCOMES.CONCERNING || outcome === SCREENING_OUTCOMES.CRISIS;

  return {
    ok: true,
    result: {
      instrumentId: instrument.id,
      instrumentName: instrument.name,
      instrumentVersion: instrument.version,
      engineVersion: SCREENING_ENGINE_VERSION,
      itemScores,
      totalScore,
      maxScore: instrument.maxScore,
      outcome,
      crisisItemPositive,
      requiresProfessionalSupport,
      // A concerning result routes to professional support resources, never to
      // generic AI wellness tips (spec §16).
      suppressesWellnessContent: requiresProfessionalSupport,
      isDiagnosis: false,
      disclaimer: 'This is a screening questionnaire, not a diagnosis. Only a clinician can diagnose.',
      source: instrument.source,
      reviewer: instrument.reviewer,
      reviewDate: instrument.reviewDate,
      scoredAt: new Date().toISOString(),
    },
  };
}

/**
 * Which checkpoint (if any) is due, given days since the postpartum start date.
 * `toleranceDays` keeps a checkpoint open for a window rather than a single day.
 */
export function getDueCheckpoint(instrumentId, daysSinceStart, completedCheckpointDays = [], toleranceDays = 14) {
  const instrument = getInstrument(instrumentId);
  if (!instrument || !Number.isFinite(daysSinceStart)) return null;

  const completed = new Set(completedCheckpointDays);
  for (const checkpointDay of instrument.checkpointDays) {
    if (completed.has(checkpointDay)) continue;
    if (daysSinceStart >= checkpointDay && daysSinceStart <= checkpointDay + toleranceDays) {
      return { instrumentId: instrument.id, checkpointDay, daysSinceStart };
    }
  }
  return null;
}

/**
 * Rule-based check-in trigger from repeated concerning mood logs
 * (spec §16: "Repeated concerning mood logs may trigger a check in based on
 * predefined rules"). This is a prompt to check in, never a diagnosis.
 */
export const MOOD_CHECKIN_RULE = Object.freeze({
  id: 'mood_checkin_v1',
  concerningMoods: ['low', 'awful', 'sad', 'anxious'],
  minConcerningDays: 5,
  windowDays: 14,
  cooldownDays: 14,
});

export function shouldTriggerMoodCheckIn(moodEvents = [], { referenceDate = new Date(), lastTriggeredAt = null } = {}) {
  const rule = MOOD_CHECKIN_RULE;
  const now = referenceDate instanceof Date ? referenceDate : new Date(referenceDate);

  if (lastTriggeredAt) {
    const last = new Date(lastTriggeredAt);
    if (!Number.isNaN(last.getTime())) {
      const daysSince = (now.getTime() - last.getTime()) / 86400000;
      if (daysSince < rule.cooldownDays) {
        return { triggered: false, reason: 'cooldown', ruleId: rule.id };
      }
    }
  }

  const windowStart = now.getTime() - rule.windowDays * 86400000;
  const concerningDays = new Set();

  for (const event of moodEvents) {
    const mood = String(event?.payload?.mood ?? '').toLowerCase();
    if (!rule.concerningMoods.includes(mood)) continue;
    const ts = new Date(event?.timestamp).getTime();
    if (Number.isNaN(ts) || ts < windowStart || ts > now.getTime()) continue;
    concerningDays.add(new Date(ts).toISOString().slice(0, 10));
  }

  const count = concerningDays.size;
  return {
    triggered: count >= rule.minConcerningDays,
    reason: count >= rule.minConcerningDays ? 'repeated_concerning_moods' : 'threshold_not_met',
    concerningDayCount: count,
    threshold: rule.minConcerningDays,
    windowDays: rule.windowDays,
    ruleId: rule.id,
  };
}
