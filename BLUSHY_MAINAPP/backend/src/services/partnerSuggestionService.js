import { periodDurationBounds } from '../config/periodPredictionConfig.js';
import { resolvePeriodDuration } from '../domain/periodDuration.js';

function toList(value) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return [];
  }

  return value
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter((item) => item.length > 0);
}

function unique(values) {
  return [...new Set(values.filter((value) => typeof value === 'string' && value.trim().length > 0))];
}

export function buildCycleInfo(
  cycleStartDate,
  onboardingAnswers = {},
  referenceDate = new Date(),
  periodEntries = [],
) {
  const dates = [];

  function addDate(val) {
    if (!val) return;
    const d = new Date(val);
    if (!Number.isNaN(d.getTime())) {
      dates.push(d);
    }
  }

  addDate(cycleStartDate);
  addDate(onboardingAnswers?.period_last_start_date);
  addDate(onboardingAnswers?.cycle_last_period_start);
  addDate(onboardingAnswers?.period_last_month_1_start);
  addDate(onboardingAnswers?.period_last_month_2_start);
  addDate(onboardingAnswers?.period_last_month_3_start);

  if (dates.length === 0) {
    return null;
  }

  dates.sort((a, b) => b.getTime() - a.getTime());
  const start = dates[0];

  let cycleLength = Number(onboardingAnswers?.cycle_length || onboardingAnswers?.period_cycle_length) || 28;
  if (dates.length >= 2) {
    const diffDays = Math.round((dates[0].getTime() - dates[1].getTime()) / 86400000);
    if (diffDays >= 18 && diffDays <= 60) {
      cycleLength = diffDays;
    }
  }
  // Logged end dates outrank the stated answer, which is never populated by
  // onboarding today, so this used to be a flat 5 for everyone.
  const { periodDurationDays: periodLength, periodDurationSource } =
    resolvePeriodDuration(periodEntries, onboardingAnswers, periodDurationBounds);

  let ref = new Date();
  if (referenceDate && !(referenceDate instanceof Date) && typeof referenceDate !== 'string') {
    ref = new Date();
  } else if (referenceDate) {
    const parsedRef = new Date(referenceDate);
    if (!Number.isNaN(parsedRef.getTime())) {
      ref = parsedRef;
    }
  }

  const todayNormalized = new Date(Date.UTC(ref.getUTCFullYear(), ref.getUTCMonth(), ref.getUTCDate()));
  const startNormalized = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), start.getUTCDate()));

  let currentCycleStart = new Date(startNormalized);
  if (startNormalized <= todayNormalized) {
    const diffMs = todayNormalized.getTime() - startNormalized.getTime();
    const diffDays = Math.floor(diffMs / 86400000);
    const cyclesElapsed = Math.floor(diffDays / cycleLength);
    currentCycleStart = new Date(startNormalized.getTime() + cyclesElapsed * cycleLength * 86400000);
  }

  const currentCycleDay = Math.floor((todayNormalized.getTime() - currentCycleStart.getTime()) / 86400000) + 1;
  const nextPeriodStart = new Date(currentCycleStart.getTime() + cycleLength * 86400000);

  let phase = 'Safe phase';
  if (currentCycleDay <= periodLength) {
    phase = 'Period phase';
  } else if (currentCycleDay <= Math.max(periodLength + 1, cycleLength - 14)) {
    phase = 'Follicular phase';
  } else if (currentCycleDay <= cycleLength - 11) {
    phase = 'Ovulation phase';
  } else if (currentCycleDay <= cycleLength) {
    phase = 'Luteal phase';
  } else {
    phase = 'Late period';
  }

  return {
    cycleStartDate: startNormalized.toISOString(),
    currentCycleStartDate: currentCycleStart.toISOString(),
    currentCycleDay,
    cycleFrequencyDays: cycleLength,
    periodLengthDays: periodLength,
    periodLengthSource: periodDurationSource,
    nextPeriodStart: nextPeriodStart.toISOString(),
    phase,
  };
}

function extractCycleAnswers(onboardingAnswers) {
  if (!onboardingAnswers) return {};
  const keys = [
    'period_last_month_1_start',
    'period_last_month_2_start',
    'period_last_month_3_start',
    'period_last_start_date',
    'cycle_last_period_start',
    'period_cycle_length',
    'cycle_usual_length_days',
    'period_duration_days',
    'cycle_last_period_duration_days',
    'medication_currently_taking',
    'taking_any_medication',
    'medication_type',
    'taking_any_medication_type',
    'medication_recent_changes',
    'recent_medication_changes',
  ];
  const result = {};
  for (const k of keys) {
    if (onboardingAnswers[k]) result[k] = String(onboardingAnswers[k]);
  }
  return result;
}

const MOOD_SCORE_MAP = {
  'great': 5,
  'okay': 3,
  'low': 2,
  'irritated': 1,
  'anxious': 1,
};

export function buildPartnerCareSuggestions({
  latestMood,
  latestSleep,
  cycleInfo,
  viewerOnboardingAnswers = {}
}) {
  const sleepDurationMinutes = latestSleep?.sleepDurationMinutes ?? latestSleep?.sleep_duration_minutes ?? latestSleep?.durationMinutes ?? latestSleep?.duration_minutes ?? null;
  const sleepQuality = latestSleep?.sleepQuality ?? latestSleep?.sleep_quality ?? null;
  const cyclePhase = cycleInfo?.phase ?? cycleInfo?.phaseName ?? cycleInfo?.cyclePhase ?? null;
  const mood = latestMood?.primaryMood ?? latestMood?.primary_mood ?? latestMood?.mood ?? null;
  const stressLevel = latestMood?.stressLevel ?? latestMood?.stress_level ?? null;
  const energyLevel = latestMood?.energyLevel ?? latestMood?.energy_level ?? latestSleep?.energyLevel ?? latestSleep?.energy_level ?? null;

  const actions = [];
  const actionIds = new Set();

  function addAction(action) {
    if (action && action.id && !actionIds.has(action.id)) {
      actionIds.add(action.id);
      actions.push(action);
    }
  }

  // 1. Period / Cycle phase actions
  if (cyclePhase === 'Period phase' || cyclePhase === 'Menstrual phase') {
    addAction({
      id: 'period_heat_pad',
      title: 'Bring a heating pad or warm tea',
      description: 'She is on her period. Gentle warmth and comfort food soothe cramps effectively.',
      category: 'Comfort',
    });
    addAction({
      id: 'period_low_pressure',
      title: 'Keep evening plans flexible & cozy',
      description: 'Avoid stressful outings and create a calm space for her to unwind.',
      category: 'Rest',
    });
  } else if (cyclePhase === 'Luteal phase') {
    addAction({
      id: 'luteal_patience',
      title: 'Offer extra reassurance & listening',
      description: 'She is in her luteal phase. Mood sensitivity is natural; lead with patience.',
      category: 'Emotional Support',
    });
    addAction({
      id: 'luteal_snack',
      title: 'Surprise her with a favorite comfort snack',
      description: 'A thoughtful treat or warm comforting meal goes a long way today.',
      category: 'Nutrition',
    });
  } else if (cyclePhase === 'Ovulation phase' || cyclePhase === 'Follicular phase') {
    addAction({
      id: 'active_date',
      title: 'Plan a walk or fun dinner together',
      description: 'Her natural energy is blooming. Great time for active dates or quality time.',
      category: 'Quality Time',
    });
    addAction({
      id: 'follicular_appreciation',
      title: 'Share a sweet note of appreciation',
      description: 'Celebrate the good energy with a spontaneous compliment or thoughtful text.',
      category: 'Affection',
    });
  }

  // 2. Sleep logic
  if (sleepDurationMinutes !== null && sleepDurationMinutes < 360) {
    addAction({
      id: 'sleep_take_chores',
      title: 'Take over chores so she can rest early',
      description: 'She had under 6 hours of sleep. Handle cooking or cleaning proactively.',
      category: 'Practical Help',
    });
  } else if (sleepQuality === 'poor') {
    addAction({
      id: 'sleep_calm_evening',
      title: 'Set up a calm bedtime environment',
      description: 'Dim the lights and encourage relaxing downtime to help restore sleep.',
      category: 'Rest',
    });
  }

  // 3. Mood logic
  if (mood === 'low' || mood === 'sad' || mood === 'anxious') {
    addAction({
      id: 'mood_gentle_checkin',
      title: 'Check in with zero pressure',
      description: 'Ask gently: “Would you prefer comfort, quiet space, or a little help today?”',
      category: 'Emotional Support',
    });
  } else if (mood === 'irritated' || stressLevel === 'high') {
    addAction({
      id: 'mood_give_space',
      title: 'Give her peaceful space to decompress',
      description: 'Create a quiet environment without asking her to explain or fix everything.',
      category: 'Space',
    });
    addAction({
      id: 'stress_practical_help',
      title: 'Take something off her plate',
      description: 'Proactively handle a household chore to reduce her mental load.',
      category: 'Practical Help',
    });
  } else if (mood === 'great' || mood === 'okay') {
    addAction({
      id: 'great_mood_connection',
      title: 'Share a laugh or quality moment together',
      description: 'Enjoy her good mood with a relaxed conversation, joke, or movie tonight.',
      category: 'Quality Time',
    });
  }

  // Fallback defaults if fewer than 3 actions
  if (actions.length < 3) {
    addAction({
      id: 'default_checkin',
      title: 'Check in with her',
      description: 'Send a gentle message or ask how her day is going.',
      category: 'Emotional Support',
    });
  }
  if (actions.length < 3) {
    addAction({
      id: 'default_take_plate',
      title: 'Take something off her plate',
      description: 'Handle chores like cleaning, dishes, or meal prep.',
      category: 'Practical Help',
    });
  }
  if (actions.length < 3) {
    addAction({
      id: 'default_space',
      title: 'Give her some space',
      description: 'Support her by creating a peaceful, quiet environment.',
      category: 'Space',
    });
  }

  return actions.slice(0, 4);
}

export function buildPartnerSharedDataPayload({
  connectionId,
  partnerUserId,
  partnerUser,
  permissions,
  mood,
  sleep,
  cycleStartDate,
  periodEntries = [],
  suggestions,
  dynamicNeeds = null,
  connectedAt = null,
  completedActionIds = [],
}) {
  const onboardingAnswers = partnerUser?.onboardingAnswers ?? {};
  const preferredName = typeof onboardingAnswers.preferred_name === 'string'
    ? onboardingAnswers.preferred_name.trim()
    : '';
  const partnerName = preferredName || partnerUser?.email?.split('@')[0] || 'Partner';
  const partnerRole = partnerUser?.role || 'woman';
  const isPartnerWoman = partnerRole === 'woman';

  const latestSleep = sleep
    ? {
        hours: ((Number(sleep.durationMinutes) || 0) / 60),
        sleepDate: sleep.entryDate ?? null,
      }
    : null;

  const effectiveCycleStart = cycleStartDate ||
    onboardingAnswers?.last_period ||
    onboardingAnswers?.last_period_date ||
    onboardingAnswers?.cycle_start_date ||
    onboardingAnswers?.period_last_start_date ||
    onboardingAnswers?.cycle_last_period_start ||
    onboardingAnswers?.period_last_month_1_start ||
    null;

  const canShareCycle = isPartnerWoman && Boolean(permissions?.shareCycle) && Boolean(effectiveCycleStart);

  return {
    connectionId,
    partnerName,
    partnerId: partnerUserId,
    partnerRole,
    connectedAt,
    shareMood: Boolean(permissions?.shareMood),
    latestMood: mood,
    shareSleep: Boolean(permissions?.shareSleep),
    latestSleep,
    shareCycle: canShareCycle,
    cycleInfo: canShareCycle
      ? {
          ...buildCycleInfo(effectiveCycleStart, onboardingAnswers, new Date(), periodEntries),
          answers: extractCycleAnswers(onboardingAnswers),
        }
      : null,
    shareInsights: Boolean(permissions?.shareInsights),
    latestInsights: null,
    suggestions,
    completedActionIds: Array.isArray(completedActionIds) ? completedActionIds : [],
    dynamicNeeds: dynamicNeeds || null,
    lastUpdated: new Date().toISOString(),
  };
}
