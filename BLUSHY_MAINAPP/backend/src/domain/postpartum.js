/**
 * Deterministic postpartum arithmetic and recovery milestones
 * (spec §16 "Postpartum Mental Health", §14 branch requirements).
 *
 * Recovery milestones derive from the postpartum start date. Recovery
 * descriptions are explicitly self-reported unless backed by clinical data.
 */

export const POSTPARTUM_CALC_VERSION = 'postpartum-v1.0.0';

const MS_PER_DAY = 86400000;

function parseDate(value) {
  if (!value) return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime())
      ? null
      : new Date(Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()));
  }
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(value).trim());
  if (!match) return null;
  const d = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  return Number.isNaN(d.getTime()) ? null : d;
}

function isoDate(d) {
  if (!d) return null;
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
}

/**
 * Recovery milestones. Content bodies come from the medical content service via
 * `contentId`; the schedule only decides when each becomes relevant.
 */
export const POSTPARTUM_MILESTONES = Object.freeze([
  { id: 'pp_d01', day: 1, title: 'First days at home', category: 'recovery', contentId: 'mc_postpartum_day_01' },
  { id: 'pp_d07', day: 7, title: 'First week recovery check', category: 'recovery', contentId: 'mc_postpartum_day_07' },
  { id: 'pp_d14', day: 14, title: 'Two week wellbeing check-in', category: 'mental_health', contentId: 'mc_postpartum_day_14', screening: 'EPDS' },
  { id: 'pp_d42', day: 42, title: 'Six week postnatal review', category: 'appointment', contentId: 'mc_postpartum_day_42', screening: 'EPDS' },
  { id: 'pp_d90', day: 90, title: 'Three month check-in', category: 'mental_health', contentId: 'mc_postpartum_day_90', screening: 'EPDS' },
  { id: 'pp_d180', day: 180, title: 'Six month check-in', category: 'mental_health', contentId: 'mc_postpartum_day_180', screening: 'EPDS' },
  { id: 'pp_d365', day: 365, title: 'One year', category: 'milestone', contentId: 'mc_postpartum_day_365' },
]);

/**
 * Postpartum phases used for copy selection. These are descriptive windows, not
 * clinical staging.
 */
export function postpartumPhase(daysSinceBirth) {
  if (daysSinceBirth === null || daysSinceBirth === undefined) return null;
  if (daysSinceBirth <= 7) return 'immediate';
  if (daysSinceBirth <= 42) return 'early';
  if (daysSinceBirth <= 180) return 'extended';
  return 'late';
}

export function calculatePostpartumState({ birthDate, referenceDate } = {}) {
  const today = parseDate(referenceDate) ?? parseDate(new Date());
  const birth = parseDate(birthDate);

  if (!birth) {
    return {
      state: 'insufficient_data',
      calculationVersion: POSTPARTUM_CALC_VERSION,
      reason: 'no_birth_date',
      message: 'Add the birth date to see your recovery timeline.',
      birthDate: null,
      daysSinceBirth: null,
      weeksSinceBirth: null,
      phase: null,
      referenceDate: isoDate(today),
    };
  }

  const daysSinceBirth = Math.round((today.getTime() - birth.getTime()) / MS_PER_DAY);

  if (daysSinceBirth < 0) {
    return {
      state: 'insufficient_data',
      calculationVersion: POSTPARTUM_CALC_VERSION,
      reason: 'birth_date_in_future',
      message: 'That birth date is in the future. Please check the date.',
      birthDate: isoDate(birth),
      daysSinceBirth: null,
      weeksSinceBirth: null,
      phase: null,
      referenceDate: isoDate(today),
    };
  }

  return {
    state: 'ready',
    calculationVersion: POSTPARTUM_CALC_VERSION,
    reason: null,
    message: null,
    birthDate: isoDate(birth),
    daysSinceBirth,
    weeksSinceBirth: Math.floor(daysSinceBirth / 7),
    monthsSinceBirth: Math.floor(daysSinceBirth / 30.44),
    phase: postpartumPhase(daysSinceBirth),
    referenceDate: isoDate(today),
  };
}

export function getRecoveryMilestones(daysSinceBirth) {
  if (daysSinceBirth === null || daysSinceBirth === undefined) {
    return { passed: [], current: null, upcoming: [], state: 'insufficient_data' };
  }

  const passed = [];
  const upcoming = [];
  let current = null;

  for (const milestone of POSTPARTUM_MILESTONES) {
    if (milestone.day < daysSinceBirth) passed.push(milestone);
    else if (milestone.day === daysSinceBirth) current = milestone;
    else upcoming.push(milestone);
  }

  if (!current && passed.length > 0) current = passed[passed.length - 1];

  return { passed, current, upcoming: upcoming.slice(0, 3), state: 'ready' };
}

/**
 * Self-reported recovery metrics the app supports. `scale` is stored with each
 * value so a number is never displayed without its source and meaning.
 */
export const RECOVERY_METRICS = Object.freeze([
  { key: 'pelvic_floor_comfort', label: 'Pelvic floor comfort', scale: 'self_reported_0_10', min: 0, max: 10 },
  { key: 'incision_or_tear_comfort', label: 'Incision or tear comfort', scale: 'self_reported_0_10', min: 0, max: 10 },
  { key: 'bleeding_level', label: 'Bleeding level', scale: 'self_reported_0_10', min: 0, max: 10 },
  { key: 'fatigue', label: 'Fatigue', scale: 'self_reported_0_10', min: 0, max: 10 },
  { key: 'feeding_comfort', label: 'Feeding comfort', scale: 'self_reported_0_10', min: 0, max: 10 },
  { key: 'emotional_wellbeing', label: 'Emotional wellbeing', scale: 'self_reported_0_10', min: 0, max: 10 },
]);

export function isKnownRecoveryMetric(key) {
  return RECOVERY_METRICS.some((metric) => metric.key === key);
}
