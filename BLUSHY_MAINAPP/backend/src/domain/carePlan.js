/**
 * Care Plan / recommended action objects (spec §10 "CARE PLAN / RECOMMENDED
 * ACTIONS", §20 "Adaptive / Innovative Features").
 *
 * Care Plan cards are action objects, not static paragraphs. Rules here are
 * deterministic; AI may only personalise wording within the approved shape,
 * never invent a new recommendation or override a safety suppression.
 */

export const CARE_PLAN_RULESET_VERSION = 'careplan-v1.0.0';

export const COMPLETION_STATES = Object.freeze({
  NOT_STARTED: 'not_started',
  COMPLETED: 'completed',
  DISMISSED: 'dismissed',
});

export const ACTION_PRIORITY = Object.freeze({ NORMAL: 'normal', HIGH: 'high' });

/**
 * Adaptive modes (spec §20). These reshape Home rather than adding content.
 */
export const ADAPTIVE_MODES = Object.freeze({
  CARE_MODE: 'care_mode',
  LOW_COGNITIVE_LOAD: 'low_cognitive_load',
  COMFORT_MODE: 'comfort_mode',
  STANDARD: 'standard',
});

/**
 * Rule catalogue. Each rule declares:
 *  - `when(context)` deterministic trigger over derived signals
 *  - the action object fields the spec §10 table requires
 *  - `cooldownDays` so the same recommendation is not resurfaced without reason
 */
export const CARE_PLAN_RULES = Object.freeze([
  {
    id: 'care_sleep_001',
    title: 'Protect your sleep tonight',
    description: 'Aim to start winding down 30 minutes earlier than usual.',
    category: 'sleep',
    priority: ACTION_PRIORITY.NORMAL,
    source: 'rule',
    cta: 'Start',
    validForDays: 2,
    cooldownDays: 3,
    when: (ctx) => Number.isFinite(ctx.averageSleepHours) && ctx.averageSleepHours < 6.5,
    reason: (ctx) => `Your logged sleep has averaged ${ctx.averageSleepHours.toFixed(1)} hours recently.`,
    lifeStages: null,
  },
  {
    id: 'care_energy_001',
    title: 'Plan a lighter day',
    description: 'Move one non-essential task and keep a short rest window.',
    category: 'energy',
    priority: ACTION_PRIORITY.NORMAL,
    source: 'rule',
    cta: 'Plan it',
    validForDays: 1,
    cooldownDays: 2,
    when: (ctx) => Number.isFinite(ctx.latestEnergyLevel) && ctx.latestEnergyLevel <= 2,
    reason: () => 'You logged low energy today.',
    lifeStages: null,
  },
  {
    id: 'care_hydration_001',
    title: 'Top up your water',
    description: 'Keep a glass within reach for the rest of the day.',
    category: 'hydration',
    priority: ACTION_PRIORITY.NORMAL,
    source: 'rule',
    cta: 'Log water',
    validForDays: 1,
    cooldownDays: 2,
    when: (ctx) => Number.isFinite(ctx.averageHydrationGlasses) && ctx.averageHydrationGlasses < 4,
    reason: () => 'Your logged water intake has been on the lower side recently.',
    lifeStages: null,
  },
  {
    id: 'care_pain_001',
    title: 'Comfort options for pain days',
    description: 'Heat, gentle movement and rest are the tools most people reach for first.',
    category: 'comfort',
    priority: ACTION_PRIORITY.HIGH,
    source: 'clinical_content',
    contentId: 'mc_comfort_period_pain',
    cta: 'Open',
    validForDays: 2,
    cooldownDays: 2,
    when: (ctx) => Number.isFinite(ctx.latestPainSeverity) && ctx.latestPainSeverity >= 6,
    reason: (ctx) => `You logged pain at ${ctx.latestPainSeverity}/10.`,
    lifeStages: null,
  },
  {
    id: 'care_mood_001',
    title: 'A short check-in with yourself',
    description: 'Two minutes of reflection, or a message to someone you trust.',
    category: 'emotional',
    priority: ACTION_PRIORITY.NORMAL,
    source: 'rule',
    cta: 'Open journal',
    validForDays: 2,
    cooldownDays: 3,
    when: (ctx) => ctx.consecutiveLowMoodDays >= 3,
    reason: (ctx) => `You have logged a low mood on ${ctx.consecutiveLowMoodDays} recent days.`,
    lifeStages: null,
  },
  {
    id: 'care_cycle_001',
    title: 'Your period may be approaching',
    description: 'A good moment to restock supplies and plan a gentler couple of days.',
    category: 'cycle',
    priority: ACTION_PRIORITY.NORMAL,
    source: 'rule',
    cta: 'View cycle',
    validForDays: 3,
    cooldownDays: 20,
    when: (ctx) => ctx.cycleLanguageAllowed && Number.isFinite(ctx.daysUntilNextPeriod) && ctx.daysUntilNextPeriod >= 0 && ctx.daysUntilNextPeriod <= 3,
    reason: (ctx) => `Based on your logged cycles, your next period is estimated in about ${ctx.daysUntilNextPeriod} day(s).`,
    lifeStages: ['cycle_tracking', 'hormonal_health', 'ttc', 'perimenopause'],
  },
  {
    id: 'care_pregnancy_001',
    title: 'Prepare for your next appointment',
    description: 'Note anything you want to raise so it is not forgotten on the day.',
    category: 'appointment',
    priority: ACTION_PRIORITY.NORMAL,
    source: 'rule',
    cta: 'Build summary',
    validForDays: 7,
    cooldownDays: 14,
    when: (ctx) => ctx.lifeStage === 'pregnancy' && Number.isFinite(ctx.gestationalWeek),
    reason: (ctx) => `You are at week ${ctx.gestationalWeek}.`,
    lifeStages: ['pregnancy'],
  },
  {
    id: 'care_postpartum_001',
    title: 'A wellbeing check-in is available',
    description: 'A short, validated questionnaire you can complete privately.',
    category: 'mental_health',
    priority: ACTION_PRIORITY.HIGH,
    source: 'clinical_content',
    contentId: 'mc_postpartum_screening_intro',
    cta: 'Start check-in',
    validForDays: 14,
    cooldownDays: 14,
    when: (ctx) => ctx.lifeStage === 'postpartum' && Boolean(ctx.screeningCheckpointDue),
    reason: () => 'You have reached a recommended check-in point.',
    lifeStages: ['postpartum'],
  },
  {
    id: 'care_menopause_001',
    title: 'Bone and heart health basics',
    description: 'Reviewed guidance on movement, nutrition and preventive checks.',
    category: 'preventive',
    priority: ACTION_PRIORITY.NORMAL,
    source: 'clinical_content',
    contentId: 'mc_menopause_bone_heart',
    cta: 'Read',
    validForDays: 30,
    cooldownDays: 30,
    when: (ctx) => ctx.lifeStage === 'menopause',
    reason: () => 'Relevant to your current stage.',
    lifeStages: ['menopause'],
  },
  {
    id: 'care_perimenopause_001',
    title: 'Try a small guided experiment',
    description: 'Pick one change to try for two weeks and log how it goes.',
    category: 'experiment',
    priority: ACTION_PRIORITY.NORMAL,
    source: 'rule',
    cta: 'Choose one',
    validForDays: 14,
    cooldownDays: 21,
    when: (ctx) => ctx.lifeStage === 'perimenopause' && ctx.hasPatterns,
    reason: () => 'You have enough logged data to test a small change.',
    lifeStages: ['perimenopause'],
  },
]);

function addDays(date, days) {
  return new Date(date.getTime() + days * 86400000);
}

/**
 * Selects the applicable care plan actions.
 *
 * @param {object} params
 * @param {object} params.context       derived signals (see CARE_PLAN_RULES)
 * @param {Array}  params.history       previously surfaced actions [{ actionId, surfacedAt, completionState }]
 * @param {boolean} params.suppressWellness  true when a red flag or concerning screening is active
 * @param {string} params.adaptiveMode
 * @returns {{ state: string, actions: Array, rulesetVersion: string, adaptiveMode: string, suppressed: boolean }}
 */
export function buildCarePlan({
  context = {},
  history = [],
  suppressWellness = false,
  adaptiveMode = ADAPTIVE_MODES.STANDARD,
  referenceDate = new Date(),
} = {}) {
  // Safety wins: ordinary wellness recommendations are withheld entirely
  // (spec §15, §16, §22).
  if (suppressWellness) {
    return {
      state: 'restricted',
      actions: [],
      rulesetVersion: CARE_PLAN_RULESET_VERSION,
      adaptiveMode,
      suppressed: true,
      suppressionReason: 'safety_escalation_active',
    };
  }

  const now = referenceDate instanceof Date ? referenceDate : new Date(referenceDate);
  const lastSurfaced = new Map();
  for (const entry of history) {
    const ts = new Date(entry?.surfacedAt).getTime();
    if (!Number.isFinite(ts)) continue;
    const previous = lastSurfaced.get(entry.actionId) ?? 0;
    if (ts > previous) lastSurfaced.set(entry.actionId, ts);
  }

  const dismissed = new Set(
    history.filter((h) => h?.completionState === COMPLETION_STATES.DISMISSED).map((h) => h.actionId),
  );

  const actions = [];

  for (const rule of CARE_PLAN_RULES) {
    if (rule.lifeStages && !rule.lifeStages.includes(context.lifeStage)) continue;

    let triggered = false;
    try {
      triggered = Boolean(rule.when(context));
    } catch {
      triggered = false;
    }
    if (!triggered) continue;

    // Do not repeatedly surface the same recommendation without a reason
    // (spec §10).
    const last = lastSurfaced.get(rule.id);
    if (last) {
      const daysSince = (now.getTime() - last) / 86400000;
      if (daysSince < rule.cooldownDays) continue;
    }
    if (dismissed.has(rule.id)) {
      const lastDismiss = lastSurfaced.get(rule.id) ?? 0;
      const daysSince = (now.getTime() - lastDismiss) / 86400000;
      if (daysSince < rule.cooldownDays * 2) continue;
    }

    let reason;
    try {
      reason = rule.reason(context);
    } catch {
      reason = null;
    }

    actions.push({
      id: rule.id,
      title: rule.title,
      description: rule.description,
      reason,
      category: rule.category,
      priority: rule.priority,
      source: rule.source,
      contentId: rule.contentId ?? null,
      cta: rule.cta,
      completionState: COMPLETION_STATES.NOT_STARTED,
      validUntil: addDays(now, rule.validForDays).toISOString(),
      rulesetVersion: CARE_PLAN_RULESET_VERSION,
    });
  }

  // Low cognitive load mode trims to the single highest priority action
  // (spec §20 "reduce nonessential content when overwhelmed").
  let visible = actions;
  if (adaptiveMode === ADAPTIVE_MODES.LOW_COGNITIVE_LOAD || adaptiveMode === ADAPTIVE_MODES.CARE_MODE) {
    visible = actions
      .slice()
      .sort((a, b) => (a.priority === ACTION_PRIORITY.HIGH ? -1 : 1) - (b.priority === ACTION_PRIORITY.HIGH ? -1 : 1))
      .slice(0, adaptiveMode === ADAPTIVE_MODES.CARE_MODE ? 2 : 1);
  }

  return {
    state: visible.length > 0 ? 'ready' : 'empty',
    actions: visible,
    rulesetVersion: CARE_PLAN_RULESET_VERSION,
    adaptiveMode,
    suppressed: false,
    suppressionReason: null,
  };
}

/**
 * Resolves the adaptive mode from self-reported signals (spec §20).
 * Never inferred from anything clinical.
 */
export function resolveAdaptiveMode({ latestEnergyLevel, latestMood, userSelectedMode } = {}) {
  if (userSelectedMode && Object.values(ADAPTIVE_MODES).includes(userSelectedMode)) {
    return userSelectedMode;
  }
  const lowMoods = ['awful', 'low', 'sad'];
  if (Number.isFinite(latestEnergyLevel) && latestEnergyLevel <= 1) return ADAPTIVE_MODES.CARE_MODE;
  if (typeof latestMood === 'string' && lowMoods.includes(latestMood.toLowerCase())) return ADAPTIVE_MODES.COMFORT_MODE;
  return ADAPTIVE_MODES.STANDARD;
}

/**
 * Energy budget summary (spec §20). Explicitly a summary of self-reported
 * values - it never claims clinical measurement.
 */
export function buildEnergyBudget({ averageSleepHours, averageEnergyLevel, activityMinutes } = {}) {
  const parts = [];
  if (Number.isFinite(averageSleepHours)) parts.push({ key: 'sleep', value: Math.round(averageSleepHours * 10) / 10, unit: 'hours' });
  if (Number.isFinite(averageEnergyLevel)) parts.push({ key: 'energy', value: Math.round(averageEnergyLevel * 10) / 10, unit: 'level_1_5' });
  if (Number.isFinite(activityMinutes)) parts.push({ key: 'activity', value: Math.round(activityMinutes), unit: 'minutes' });

  if (parts.length === 0) {
    return { state: 'insufficient_data', components: [], source: 'manual', disclaimer: null };
  }

  return {
    state: 'ready',
    components: parts,
    source: 'manual',
    disclaimer: 'A summary of what you logged. Not a clinical measurement.',
  };
}
