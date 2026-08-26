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

export function buildCycleInfo(cycleStartDate, onboardingAnswers = {}, referenceDate = new Date()) {
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

  const cycleLength = Number(onboardingAnswers?.cycle_length || onboardingAnswers?.period_cycle_length) || 28;
  const periodLength = Number(onboardingAnswers?.period_duration_days || onboardingAnswers?.cycle_last_period_duration_days) || 5;

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
  const supportAreas = new Set(toList(viewerOnboardingAnswers.partner_support_areas));
  const intimacyInterests = new Set(toList(viewerOnboardingAnswers.intimacy_interests));
  const cycleTopics = new Set(toList(viewerOnboardingAnswers.cycle_topics_interested));
  const sexualTopics = new Set(toList(viewerOnboardingAnswers.sexual_wellness_topics));
  const communicationLevel = String(
    viewerOnboardingAnswers.partner_communication_level ?? '',
  ).trim().toLowerCase();

  const sleepDurationMinutes = latestSleep?.sleepDurationMinutes ?? latestSleep?.sleep_duration_minutes ?? latestSleep?.durationMinutes ?? latestSleep?.duration_minutes ?? null;
  const sleepQuality = latestSleep?.sleepQuality ?? latestSleep?.sleep_quality ?? null;
  const cyclePhase = cycleInfo?.phaseName ?? cycleInfo?.cyclePhase ?? null;
  const mood = latestMood?.primaryMood ?? latestMood?.primary_mood ?? latestMood?.mood ?? null;
  const stressLevel = latestMood?.stressLevel ?? latestMood?.stress_level ?? null;
  const energyLevel = latestMood?.energyLevel ?? latestMood?.energy_level ?? latestSleep?.energyLevel ?? latestSleep?.energy_level ?? null;

  const suggestions = [];

  // Sleep logic
  if (sleepDurationMinutes !== null && sleepDurationMinutes < 360) { // less than 6 hours
    suggestions.push('They had less than 6 hours of sleep. Try to take over some chores so they can rest.');
    suggestions.push('A short nap or an early bedtime tonight could really help their energy levels.');
  } else if (sleepQuality === 'poor') {
    suggestions.push('They reported poor sleep quality. A relaxing evening routine could be beneficial today.');
  }

  // Cycle logic
  if (cyclePhase === 'Period phase') {
    suggestions.push('They are currently on their period. Offering a heating pad, comfort food, or a back rub can be very soothing.');
    suggestions.push('Keep plans low-pressure and flexible during the first few days of their cycle.');
  } else if (cyclePhase === 'Luteal phase') {
    suggestions.push('They are in their luteal phase. Mood shifts or lower energy are common, so extra patience and gentle support go a long way.');
  } else if (cyclePhase === 'Ovulation phase') {
    suggestions.push('They are around ovulation. Energy levels are often high, making this a great time for dates or active plans together.');
  }

  if (mood === 'anxious') {
    suggestions.push('Start with a gentle check-in and ask whether they want comfort, space, or practical help right now.');
    suggestions.push('Keep today low-pressure. Calm company, a short walk, or helping with one small task can feel better than pushing for a long talk.');
  } else if (mood === 'irritated') {
    suggestions.push('Give them a little breathing room first, then offer one simple helpful thing like food, water, or taking something off their plate.');
    suggestions.push('Avoid trying to solve everything immediately. A short validating message usually works better than a big conversation.');
  } else if (mood === 'low') {
    suggestions.push('Lead with warmth and reassurance. A soft check-in, comfort food, hydration, or a rest-friendly plan can help today.');
    suggestions.push('Offer support that feels easy to accept, like tea, a snack, or sitting together quietly for a while.');
  } else if (mood === 'okay') {
    suggestions.push('This is a good day for a small thoughtful gesture and a casual check-in without overdoing it.');
  } else if (mood === 'great') {
    suggestions.push('Lean into the good moment. Plan something light together or say something appreciative and affectionate.');
  }

  if (supportAreas.has('mood changes')) {
    suggestions.push('Because you want to support mood changes, ask directly what would feel most supportive today instead of guessing.');
  }

  if (supportAreas.has('physical discomfort') || cycleTopics.has('period basics')) {
    suggestions.push('If their body seems uncomfortable, offer a heating pad, water, rest, or to handle one chore so they can relax.');
  }

  if (supportAreas.has('overall health') || cycleTopics.has('energy levels')) {
    suggestions.push('Match the plan to their energy today. If they seem drained, keep things simple and recovery-focused.');
  }

  if (intimacyInterests.has('emotional connection')) {
    suggestions.push('Emotional safety first will likely land well today: listen, validate, and be present before shifting into advice.');
  }

  if (intimacyInterests.has('more time together')) {
    suggestions.push('A little quality time can help: sit together, go for a short walk, or share a calm meal without distractions.');
  }

  if (intimacyInterests.has('understanding each other’s needs')) {
    suggestions.push('Ask one clear question like “What would help most right now?” so support feels aligned with what they actually need.');
  }

  if (communicationLevel == 'need improvement') {
    suggestions.push('Keep your support simple and low-pressure. A kind short message may work better than a heavy conversation.');
  } else if (communicationLevel == 'very open' || communicationLevel == 'open') {
    suggestions.push('Since communication is one of your strengths, a direct but gentle check-in is likely the best move.');
  }

  if (sexualTopics.has('communication')) {
    suggestions.push('If closeness comes up today, follow their cues and keep communication clear, gentle, and respectful.');
  }

  if (stressLevel == 'high') {
    suggestions.push('Their stress looks high today, so protecting rest and reducing pressure should help more than adding plans.');
  }

  if (energyLevel == 'low') {
    suggestions.push('Low energy day: choose practical support over big plans and help make the day feel easier.');
  }

  return unique(suggestions).slice(0, 5);
}

export function buildPartnerSharedDataPayload({
  connectionId,
  partnerUserId,
  partnerUser,
  permissions,
  mood,
  sleep,
  cycleStartDate,
  suggestions,
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
    shareMood: Boolean(permissions?.shareMood),
    latestMood: mood,
    shareSleep: Boolean(permissions?.shareSleep),
    latestSleep,
    shareCycle: canShareCycle,
    cycleInfo: canShareCycle
      ? {
          ...buildCycleInfo(effectiveCycleStart, onboardingAnswers),
          answers: extractCycleAnswers(onboardingAnswers),
        }
      : null,
    shareInsights: Boolean(permissions?.shareInsights),
    latestInsights: null,
    suggestions,
    lastUpdated: new Date().toISOString(),
  };
}
