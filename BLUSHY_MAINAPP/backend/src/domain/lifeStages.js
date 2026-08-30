/**
 * Life stage / branch engine (spec §3 "Onboarding", §4 "Life Stage/Home Engine",
 * §14 "Branch Requirements", §23 "Life Stage Transitions").
 *
 * Pure, deterministic and dependency-free so it can be unit tested without a
 * database. Everything the Home engine, onboarding and transition engine need
 * to know about a branch lives in one place, so the backend can reorder or
 * re-prioritise modules later without a frontend rewrite.
 */

export const LIFE_STAGE_CONFIG_VERSION = 'lifestage-v1.0.0';

/**
 * Canonical branch keys. Legacy keys used by the existing Flutter app are
 * mapped onto these by `normalizeLifeStage`.
 */
export const LIFE_STAGES = Object.freeze({
  FIRST_PERIOD: 'first_period',
  CYCLE_TRACKING: 'cycle_tracking',
  HORMONAL_HEALTH: 'hormonal_health',
  TTC: 'ttc',
  PREGNANCY: 'pregnancy',
  POSTPARTUM: 'postpartum',
  PERIMENOPAUSE: 'perimenopause',
  MENOPAUSE: 'menopause',
  EVERYDAY_WELLNESS: 'everyday_wellness',
  EXPLORING: 'exploring',
});

/**
 * Life journey labels exactly as the spec lists them for onboarding step 6.
 */
export const LIFE_JOURNEYS = Object.freeze([
  { id: LIFE_STAGES.FIRST_PERIOD, label: 'Learning about my body' },
  { id: LIFE_STAGES.CYCLE_TRACKING, label: 'Living with my cycle' },
  { id: LIFE_STAGES.HORMONAL_HEALTH, label: 'Hormonal health' },
  { id: LIFE_STAGES.TTC, label: 'Fertility journey' },
  { id: LIFE_STAGES.PREGNANCY, label: 'Pregnancy' },
  { id: LIFE_STAGES.POSTPARTUM, label: 'New motherhood' },
  { id: LIFE_STAGES.PERIMENOPAUSE, label: 'Midlife changes' },
  { id: LIFE_STAGES.MENOPAUSE, label: 'Menopause' },
  { id: LIFE_STAGES.EVERYDAY_WELLNESS, label: 'Everyday wellness' },
  { id: LIFE_STAGES.EXPLORING, label: 'Just exploring' },
]);

const LEGACY_STAGE_ALIASES = Object.freeze({
  firstperiodnotstarted: LIFE_STAGES.FIRST_PERIOD,
  firstperiodstarted: LIFE_STAGES.FIRST_PERIOD,
  first_period_not_started: LIFE_STAGES.FIRST_PERIOD,
  first_period_started: LIFE_STAGES.FIRST_PERIOD,
  firstperiod: LIFE_STAGES.FIRST_PERIOD,
  livingwithmycycle: LIFE_STAGES.CYCLE_TRACKING,
  living_with_my_cycle: LIFE_STAGES.CYCLE_TRACKING,
  cycle: LIFE_STAGES.CYCLE_TRACKING,
  cycletracking: LIFE_STAGES.CYCLE_TRACKING,
  reproductive: LIFE_STAGES.CYCLE_TRACKING,
  // The Flutter onboarding wizard sends its own enum names verbatim.
  reproductiveyears: LIFE_STAGES.CYCLE_TRACKING,
  reproductive_years: LIFE_STAGES.CYCLE_TRACKING,
  hormonalhealth: LIFE_STAGES.HORMONAL_HEALTH,
  hormonal_health: LIFE_STAGES.HORMONAL_HEALTH,
  pcos: LIFE_STAGES.HORMONAL_HEALTH,
  tryingtoconceive: LIFE_STAGES.TTC,
  trying_to_conceive: LIFE_STAGES.TTC,
  fertility: LIFE_STAGES.TTC,
  pregnant: LIFE_STAGES.PREGNANCY,
  postnatal: LIFE_STAGES.POSTPARTUM,
  newmotherhood: LIFE_STAGES.POSTPARTUM,
  perimenopausal: LIFE_STAGES.PERIMENOPAUSE,
  midlife: LIFE_STAGES.PERIMENOPAUSE,
  menopausal: LIFE_STAGES.MENOPAUSE,
  postmenopause: LIFE_STAGES.MENOPAUSE,
  everydaywellness: LIFE_STAGES.EVERYDAY_WELLNESS,
  wellness: LIFE_STAGES.EVERYDAY_WELLNESS,
  justexploring: LIFE_STAGES.EXPLORING,
  explore: LIFE_STAGES.EXPLORING,
});

const VALID_STAGES = new Set(Object.values(LIFE_STAGES));

export function normalizeLifeStage(value, fallback = null) {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  if (!trimmed) return fallback;

  const lower = trimmed.toLowerCase();
  if (VALID_STAGES.has(lower)) return lower;

  const collapsed = lower.replace(/[\s-]+/g, '_');
  if (VALID_STAGES.has(collapsed)) return collapsed;

  const squashed = lower.replace(/[\s_-]+/g, '');
  return LEGACY_STAGE_ALIASES[collapsed] ?? LEGACY_STAGE_ALIASES[squashed] ?? fallback;
}

export function isValidLifeStage(value) {
  return VALID_STAGES.has(value);
}

/**
 * Branch initialization questions (spec §3 "Branch initialization / Required
 * initial context"). Only these are asked for the selected journey.
 */
export const BRANCH_INITIAL_CONTEXT = Object.freeze({
  [LIFE_STAGES.FIRST_PERIOD]: [
    { key: 'period_started', label: 'Has your first period started?', type: 'boolean', required: true },
    { key: 'desired_help', label: 'What would you like help with?', type: 'multi_select', required: false },
  ],
  [LIFE_STAGES.CYCLE_TRACKING]: [
    { key: 'cycle_pattern', label: 'How would you describe your cycle?', type: 'single_select', required: true,
      options: ['Regular', 'Somewhat regular', 'Irregular', 'Highly unpredictable', 'Not sure'] },
    { key: 'last_period_start', label: 'When did your last period start?', type: 'date', required: false },
  ],
  [LIFE_STAGES.HORMONAL_HEALTH]: [
    { key: 'diagnosed_conditions', label: 'Which conditions have you been diagnosed with?', type: 'multi_select', required: false,
      options: ['PCOS', 'Endometriosis', 'PMDD', 'Thyroid condition', 'Fibroids', 'Adenomyosis', 'Other', 'Not diagnosed'] },
  ],
  [LIFE_STAGES.TTC]: [
    { key: 'ttc_duration_months', label: 'How long have you been trying to conceive?', type: 'number', required: false },
  ],
  [LIFE_STAGES.PREGNANCY]: [
    { key: 'due_date', label: 'What is your due date?', type: 'date', required: false },
    { key: 'pregnancy_week', label: 'Which week are you in?', type: 'number', required: false },
    { key: 'pregnancy_date_unsure', label: 'I am not sure', type: 'boolean', required: false },
  ],
  [LIFE_STAGES.POSTPARTUM]: [
    { key: 'baby_birth_date', label: 'What is the birth date?', type: 'date', required: true },
  ],
  [LIFE_STAGES.PERIMENOPAUSE]: [
    { key: 'recent_period_changes', label: 'What changes have you noticed in your periods?', type: 'multi_select', required: false,
      options: ['Shorter cycles', 'Longer cycles', 'Skipped periods', 'Heavier flow', 'Lighter flow', 'No change', 'Not sure'] },
  ],
  [LIFE_STAGES.MENOPAUSE]: [
    { key: 'months_since_last_period', label: 'How long since your last period?', type: 'number', required: false },
  ],
  [LIFE_STAGES.EVERYDAY_WELLNESS]: [
    { key: 'reason_for_blushy', label: 'What brings you to Blushy?', type: 'multi_select', required: false },
  ],
  [LIFE_STAGES.EXPLORING]: [],
});

/**
 * Home module composition per branch (spec §5 "HOME SCREEN FUNCTIONAL
 * CONTRACT"). `order` lets the backend re-prioritise without a frontend
 * rewrite; the frontend renders whatever order it is given.
 */
const BASE_MODULES = ['greeting', 'today_context', 'quick_actions'];

export const BRANCH_HOME_MODULES = Object.freeze({
  [LIFE_STAGES.FIRST_PERIOD]: [...BASE_MODULES, 'education_checklist', 'sia_note', 'timeline', 'care_plan'],
  [LIFE_STAGES.CYCLE_TRACKING]: [...BASE_MODULES, 'hero_tracker', 'sia_note', 'patterns', 'care_plan', 'timeline', 'reflection'],
  [LIFE_STAGES.HORMONAL_HEALTH]: [...BASE_MODULES, 'hero_tracker', 'condition_profile', 'sia_note', 'patterns', 'care_plan', 'doctor_companion', 'timeline'],
  [LIFE_STAGES.TTC]: [...BASE_MODULES, 'hero_tracker', 'fertility_indicators', 'sia_note', 'patterns', 'care_plan', 'reflection', 'timeline'],
  [LIFE_STAGES.PREGNANCY]: [...BASE_MODULES, 'pregnancy_tracker', 'milestones', 'safety_banner', 'sia_note', 'care_plan', 'timeline'],
  [LIFE_STAGES.POSTPARTUM]: [...BASE_MODULES, 'postpartum_tracker', 'recovery_milestones', 'screening_checkpoint', 'sia_note', 'care_plan', 'timeline'],
  [LIFE_STAGES.PERIMENOPAUSE]: [...BASE_MODULES, 'symptom_tracker', 'sia_note', 'patterns', 'guided_experiments', 'care_plan', 'timeline'],
  [LIFE_STAGES.MENOPAUSE]: [...BASE_MODULES, 'wellness_tracker', 'sia_note', 'patterns', 'preventive_care', 'care_plan', 'timeline'],
  [LIFE_STAGES.EVERYDAY_WELLNESS]: [...BASE_MODULES, 'wellness_tracker', 'sia_note', 'patterns', 'care_plan', 'timeline'],
  [LIFE_STAGES.EXPLORING]: [...BASE_MODULES, 'education_checklist', 'sia_note'],
});

/**
 * Capability flags consumed by services so no other module has to hardcode
 * per-branch behaviour. `cycleLanguage: false` is what keeps cycle-centric
 * copy away from menopause and pregnancy users (spec §5, §18).
 */
export const BRANCH_CAPABILITIES = Object.freeze({
  [LIFE_STAGES.FIRST_PERIOD]: { cycleTracking: true, cyclePredictions: false, fertility: false, pregnancy: false, postpartum: false, cycleLanguage: true },
  [LIFE_STAGES.CYCLE_TRACKING]: { cycleTracking: true, cyclePredictions: true, fertility: false, pregnancy: false, postpartum: false, cycleLanguage: true },
  [LIFE_STAGES.HORMONAL_HEALTH]: { cycleTracking: true, cyclePredictions: true, fertility: false, pregnancy: false, postpartum: false, cycleLanguage: true },
  [LIFE_STAGES.TTC]: { cycleTracking: true, cyclePredictions: true, fertility: true, pregnancy: false, postpartum: false, cycleLanguage: true },
  [LIFE_STAGES.PREGNANCY]: { cycleTracking: false, cyclePredictions: false, fertility: false, pregnancy: true, postpartum: false, cycleLanguage: false },
  [LIFE_STAGES.POSTPARTUM]: { cycleTracking: false, cyclePredictions: false, fertility: false, pregnancy: false, postpartum: true, cycleLanguage: false },
  [LIFE_STAGES.PERIMENOPAUSE]: { cycleTracking: true, cyclePredictions: false, fertility: false, pregnancy: false, postpartum: false, cycleLanguage: true },
  [LIFE_STAGES.MENOPAUSE]: { cycleTracking: false, cyclePredictions: false, fertility: false, pregnancy: false, postpartum: false, cycleLanguage: false },
  [LIFE_STAGES.EVERYDAY_WELLNESS]: { cycleTracking: false, cyclePredictions: false, fertility: false, pregnancy: false, postpartum: false, cycleLanguage: false },
  [LIFE_STAGES.EXPLORING]: { cycleTracking: false, cyclePredictions: false, fertility: false, pregnancy: false, postpartum: false, cycleLanguage: false },
});

export function getBranchCapabilities(stage) {
  const normalized = normalizeLifeStage(stage, LIFE_STAGES.EVERYDAY_WELLNESS);
  return BRANCH_CAPABILITIES[normalized] ?? BRANCH_CAPABILITIES[LIFE_STAGES.EVERYDAY_WELLNESS];
}

export function getHomeModules(stage) {
  const normalized = normalizeLifeStage(stage, LIFE_STAGES.EVERYDAY_WELLNESS);
  const modules = BRANCH_HOME_MODULES[normalized] ?? BRANCH_HOME_MODULES[LIFE_STAGES.EVERYDAY_WELLNESS];
  return modules.map((moduleId, index) => ({ moduleId, order: index }));
}

export function getBranchInitialContext(stage) {
  const normalized = normalizeLifeStage(stage, null);
  if (!normalized) return [];
  return BRANCH_INITIAL_CONTEXT[normalized] ?? [];
}

/**
 * Life stage state machine (spec §23). `requiresConfirmation` marks the
 * sensitive transitions the spec says must never be inferred silently.
 */
export const ALLOWED_TRANSITIONS = Object.freeze([
  { from: LIFE_STAGES.FIRST_PERIOD, to: LIFE_STAGES.CYCLE_TRACKING, requiresConfirmation: false, reason: 'periods_established' },
  { from: LIFE_STAGES.CYCLE_TRACKING, to: LIFE_STAGES.TTC, requiresConfirmation: false, reason: 'user_started_ttc' },
  { from: LIFE_STAGES.CYCLE_TRACKING, to: LIFE_STAGES.PREGNANCY, requiresConfirmation: true, reason: 'pregnancy_confirmed' },
  { from: LIFE_STAGES.CYCLE_TRACKING, to: LIFE_STAGES.HORMONAL_HEALTH, requiresConfirmation: false, reason: 'condition_reported' },
  { from: LIFE_STAGES.CYCLE_TRACKING, to: LIFE_STAGES.PERIMENOPAUSE, requiresConfirmation: true, reason: 'user_reported_midlife_changes' },
  { from: LIFE_STAGES.CYCLE_TRACKING, to: LIFE_STAGES.MENOPAUSE, requiresConfirmation: true, reason: 'user_reported_menopause' },
  { from: LIFE_STAGES.CYCLE_TRACKING, to: LIFE_STAGES.EVERYDAY_WELLNESS, requiresConfirmation: false, reason: 'user_choice' },
  { from: LIFE_STAGES.HORMONAL_HEALTH, to: LIFE_STAGES.TTC, requiresConfirmation: false, reason: 'user_started_ttc' },
  { from: LIFE_STAGES.HORMONAL_HEALTH, to: LIFE_STAGES.PREGNANCY, requiresConfirmation: true, reason: 'pregnancy_confirmed' },
  { from: LIFE_STAGES.HORMONAL_HEALTH, to: LIFE_STAGES.CYCLE_TRACKING, requiresConfirmation: false, reason: 'user_choice' },
  { from: LIFE_STAGES.HORMONAL_HEALTH, to: LIFE_STAGES.PERIMENOPAUSE, requiresConfirmation: true, reason: 'user_reported_midlife_changes' },
  { from: LIFE_STAGES.HORMONAL_HEALTH, to: LIFE_STAGES.MENOPAUSE, requiresConfirmation: true, reason: 'user_reported_menopause' },
  { from: LIFE_STAGES.TTC, to: LIFE_STAGES.PREGNANCY, requiresConfirmation: true, reason: 'pregnancy_confirmed' },
  { from: LIFE_STAGES.TTC, to: LIFE_STAGES.CYCLE_TRACKING, requiresConfirmation: false, reason: 'user_paused_ttc' },
  { from: LIFE_STAGES.TTC, to: LIFE_STAGES.HORMONAL_HEALTH, requiresConfirmation: false, reason: 'condition_reported' },
  { from: LIFE_STAGES.PREGNANCY, to: LIFE_STAGES.POSTPARTUM, requiresConfirmation: true, reason: 'birth_recorded' },
  { from: LIFE_STAGES.PREGNANCY, to: LIFE_STAGES.CYCLE_TRACKING, requiresConfirmation: true, reason: 'pregnancy_ended' },
  { from: LIFE_STAGES.PREGNANCY, to: LIFE_STAGES.TTC, requiresConfirmation: true, reason: 'pregnancy_ended' },
  { from: LIFE_STAGES.PREGNANCY, to: LIFE_STAGES.EVERYDAY_WELLNESS, requiresConfirmation: true, reason: 'pregnancy_ended' },
  { from: LIFE_STAGES.POSTPARTUM, to: LIFE_STAGES.EVERYDAY_WELLNESS, requiresConfirmation: false, reason: 'postpartum_complete' },
  { from: LIFE_STAGES.POSTPARTUM, to: LIFE_STAGES.CYCLE_TRACKING, requiresConfirmation: false, reason: 'cycle_returned' },
  { from: LIFE_STAGES.POSTPARTUM, to: LIFE_STAGES.TTC, requiresConfirmation: false, reason: 'user_started_ttc' },
  { from: LIFE_STAGES.POSTPARTUM, to: LIFE_STAGES.PREGNANCY, requiresConfirmation: true, reason: 'pregnancy_confirmed' },
  { from: LIFE_STAGES.PERIMENOPAUSE, to: LIFE_STAGES.MENOPAUSE, requiresConfirmation: true, reason: 'twelve_months_no_period' },
  { from: LIFE_STAGES.PERIMENOPAUSE, to: LIFE_STAGES.EVERYDAY_WELLNESS, requiresConfirmation: false, reason: 'user_choice' },
  { from: LIFE_STAGES.MENOPAUSE, to: LIFE_STAGES.EVERYDAY_WELLNESS, requiresConfirmation: false, reason: 'user_choice' },
  { from: LIFE_STAGES.EVERYDAY_WELLNESS, to: LIFE_STAGES.CYCLE_TRACKING, requiresConfirmation: false, reason: 'user_choice' },
  { from: LIFE_STAGES.EVERYDAY_WELLNESS, to: LIFE_STAGES.TTC, requiresConfirmation: false, reason: 'user_started_ttc' },
  { from: LIFE_STAGES.EVERYDAY_WELLNESS, to: LIFE_STAGES.PREGNANCY, requiresConfirmation: true, reason: 'pregnancy_confirmed' },
  { from: LIFE_STAGES.EVERYDAY_WELLNESS, to: LIFE_STAGES.HORMONAL_HEALTH, requiresConfirmation: false, reason: 'condition_reported' },
  { from: LIFE_STAGES.EVERYDAY_WELLNESS, to: LIFE_STAGES.PERIMENOPAUSE, requiresConfirmation: true, reason: 'user_reported_midlife_changes' },
  { from: LIFE_STAGES.EVERYDAY_WELLNESS, to: LIFE_STAGES.MENOPAUSE, requiresConfirmation: true, reason: 'user_reported_menopause' },
]);

/**
 * `exploring` is a provisional state: the user may move anywhere from it, so it
 * is expanded rather than enumerated above.
 */
function transitionsFromExploring() {
  return Object.values(LIFE_STAGES)
    .filter((stage) => stage !== LIFE_STAGES.EXPLORING)
    .map((stage) => ({
      from: LIFE_STAGES.EXPLORING,
      to: stage,
      requiresConfirmation: stage === LIFE_STAGES.PREGNANCY || stage === LIFE_STAGES.MENOPAUSE,
      reason: 'user_choice',
    }));
}

const TRANSITION_INDEX = (() => {
  const index = new Map();
  for (const t of [...ALLOWED_TRANSITIONS, ...transitionsFromExploring()]) {
    index.set(`${t.from}->${t.to}`, t);
  }
  return index;
})();

export function getAllowedTransitions(fromStage) {
  const from = normalizeLifeStage(fromStage, null);
  if (!from) return [];
  const out = [];
  for (const [key, value] of TRANSITION_INDEX.entries()) {
    if (key.startsWith(`${from}->`)) out.push(value);
  }
  return out;
}

/**
 * Validates a requested transition.
 * Returns { allowed, requiresConfirmation, reason, errorCode }.
 */
export function evaluateTransition(fromStage, toStage, { confirmed = false } = {}) {
  const from = normalizeLifeStage(fromStage, null);
  const to = normalizeLifeStage(toStage, null);

  if (!to) {
    return { allowed: false, requiresConfirmation: false, errorCode: 'UNKNOWN_TARGET_STAGE', reason: null };
  }

  // First stage selection during onboarding: no source stage yet.
  if (!from) {
    return { allowed: true, requiresConfirmation: false, errorCode: null, reason: 'initial_selection' };
  }

  if (from === to) {
    return { allowed: false, requiresConfirmation: false, errorCode: 'ALREADY_IN_STAGE', reason: null };
  }

  const transition = TRANSITION_INDEX.get(`${from}->${to}`);
  if (!transition) {
    return { allowed: false, requiresConfirmation: false, errorCode: 'TRANSITION_NOT_ALLOWED', reason: null };
  }

  if (transition.requiresConfirmation && !confirmed) {
    return {
      allowed: false,
      requiresConfirmation: true,
      errorCode: 'CONFIRMATION_REQUIRED',
      reason: transition.reason,
    };
  }

  return { allowed: true, requiresConfirmation: transition.requiresConfirmation, errorCode: null, reason: transition.reason };
}

/**
 * Which branch context keys the new stage needs in order to render immediately.
 * Historical data is never deleted on transition (spec §23 "Preserve historical
 * data") - this only decides what must be collected.
 */
export const TRANSITION_CONTEXT_REQUIREMENTS = Object.freeze({
  // Only the branches whose initial context is marked `required: true` block a
  // transition. TTC and hormonal health ask optional questions, so they are
  // entered first and answered afterwards.
  [LIFE_STAGES.PREGNANCY]: ['due_date', 'pregnancy_week', 'pregnancy_date_unsure'],
  [LIFE_STAGES.POSTPARTUM]: ['baby_birth_date'],
});
