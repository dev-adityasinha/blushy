import { getPeriodEntries } from '../repositories/periodRepository.js';
import { getBranchCapabilities, normalizeLifeStage } from '../domain/lifeStages.js';
import { getUserById } from '../repositories/userRepository.js';
import { periodPredictionConfig, periodDurationBounds } from '../config/periodPredictionConfig.js';
import { resolvePeriodDuration } from '../domain/periodDuration.js';

function isoDate(d) {
  if (!d || !(d instanceof Date) || Number.isNaN(d.getTime())) return null;
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function parseDateOnly(str) {
  if (!str) return null;
  if (str instanceof Date) {
    return new Date(Date.UTC(str.getFullYear(), str.getMonth(), str.getDate()));
  }
  const clean = String(str).trim();
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(clean);
  if (match) {
    return new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  }
  const parsed = new Date(clean);
  if (!Number.isNaN(parsed.getTime())) {
    return new Date(Date.UTC(parsed.getUTCFullYear(), parsed.getUTCMonth(), parsed.getUTCDate()));
  }
  return null;
}

function addDays(d, days) {
  return new Date(d.getTime() + days * 86400000);
}

function daysBetween(d1, d2) {
  return Math.round((d2.getTime() - d1.getTime()) / 86400000);
}

function getTodayInTimezone(tz) {
  try {
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: tz,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    return parseDateOnly(formatter.format(new Date()));
  } catch (_) {
    return parseDateOnly(new Date());
  }
}

function parseCycleLengthFromAnswers(onboardingAnswers) {
  if (!onboardingAnswers || typeof onboardingAnswers !== 'object') {
    return periodPredictionConfig.defaultCycleLengthDays;
  }
  const candidates = [
    onboardingAnswers.cycle_length,
    onboardingAnswers.cycleLength,
    onboardingAnswers.period_cycle_length,
    onboardingAnswers.cycle_usual_length_days,
  ];
  for (const c of candidates) {
    const n = Number(c);
    if (Number.isFinite(n) && n >= periodPredictionConfig.minCycleLengthDays && n <= periodPredictionConfig.maxCycleLengthDays) {
      return Math.round(n);
    }
  }
  return periodPredictionConfig.defaultCycleLengthDays;
}

export async function calculatePeriodPredictions(userId, options = {}) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const user = await getUserById(cleanUserId);
  const entries = await getPeriodEntries(cleanUserId, 20);

  const onboardingAnswers = user?.onboardingAnswers || user?.onboarding_answers || {};
  const lifeStage = user?.lifeStage || user?.life_stage || onboardingAnswers.life_stage || onboardingAnswers.lifeStage;

  // Determine user IANA timezone
  const explicitTz = options.timezone || user?.timezone || onboardingAnswers.timezone;
  let userTimezone = explicitTz;
  let timezoneSource = 'user_profile';

  if (!userTimezone || typeof userTimezone !== 'string') {
    userTimezone = periodPredictionConfig.defaultFallbackTimezone;
    timezoneSource = 'emergency_fallback';
  } else {
    try {
      Intl.DateTimeFormat(undefined, { timeZone: userTimezone });
    } catch (_) {
      userTimezone = periodPredictionConfig.defaultFallbackTimezone;
      timezoneSource = 'emergency_fallback';
    }
  }

  const today = options.referenceDate ? parseDateOnly(options.referenceDate) : getTodayInTimezone(userTimezone);

  // Cycle tracking is suppressed where the branch does not do it.
  //
  // This was a hardcoded list compared against the raw stage string, and it
  // disagreed with `BRANCH_CAPABILITIES` in two directions. `everyday_wellness`
  // and `exploring` both declare `cycleTracking: false`, and both were given a
  // full countdown -- someone who opted out of cycle tracking was told "Day 29,
  // Late / Overdue Cycle". And because the comparison was on the raw string,
  // an account stored as `firstPeriodNotStarted` was suppressed while the same
  // stage stored canonically as `first_period` was not.
  //
  // The capability table is the declaration, and it normalises both spellings.
  //
  // "Periods not started" is kept as a separate check: the aliases fold it and
  // `firstPeriodStarted` into one stage, so the capability alone cannot tell
  // them apart, and a countdown for someone who has not had a period yet would
  // be meaningless.
  // Only a *recognised* stage can suppress. `getBranchCapabilities` falls back
  // to everyday_wellness for anything it does not know, and everyday_wellness
  // declares `cycleTracking: false` -- so deriving straight from it would
  // silently suppress every account with no stage set, or a stage spelled in a
  // way the aliases miss. Absent is not the same as opted out.
  const normalizedStage = normalizeLifeStage(lifeStage, null);
  const suppressedByBranch = normalizedStage !== null &&
    !getBranchCapabilities(normalizedStage).cycleTracking;

  const rawStage = typeof lifeStage === 'string'
    ? lifeStage.toLowerCase().replace(/[\s_-]+/g, '')
    : '';
  const periodsNotStarted = rawStage === 'firstperiodnotstarted';

  if (suppressedByBranch || periodsNotStarted) {
    return {
      hasData: false,
      trackingState: 'suppressed',
      trackingSuppressed: true,
      lifeStage,
      message: `Cycle tracking adapted for ${lifeStage}. Standard period countdown is paused.`,
      todayDate: isoDate(today),
      userTimezone,
      timezoneSource,
      algorithmVersion: periodPredictionConfig.algorithmVersion,
      calculatedAt: new Date().toISOString(),
      currentCycle: {
        currentCycleDay: null,
        phase: `${lifeStage.charAt(0).toUpperCase() + lifeStage.slice(1)} Focus`,
        isEstimate: false,
        cycleStartDate: null,
        latestConfirmedPeriodStartDate: null,
        periodDurationDays: null,
        periodDurationSource: null,
        periodDurationObservations: 0,
        isCurrentPeriod: false,
        periodDay: null,
        isOverdue: false,
        daysOverdue: 0,
      },
      prediction: {
        nextPeriodStartDate: null,
        daysUntilNextPeriod: null,
        estimatedOvulationDate: null,
        fertileWindowStart: null,
        fertileWindowEnd: null,
        isOvulationSupported: false,
        disclaimer: periodPredictionConfig.disclaimerText,
      },
      dataSufficiency: {
        completedCyclesCount: 0,
        validStartDatesCount: 0,
        confidenceLevel: 'suppressed',
        displayLabel: 'Tracking Paused',
        message: `Standard predictions paused for ${lifeStage}.`,
      },
      historicalRecordsUsed: [],
    };
  }

  // Collect confirmed period start dates in chronological order (oldest to newest)
  const chronDates = entries
    .map((e) => parseDateOnly(e.periodStartDate))
    .filter((d) => d !== null)
    .sort((a, b) => a.getTime() - b.getTime());

  // Fallback to user scalar date if entries collection is empty
  if (chronDates.length === 0) {
    const rawFallback = onboardingAnswers.last_period ||
      onboardingAnswers.last_period_date ||
      onboardingAnswers.period_last_start_date ||
      user?.cycleStartDate;
    const parsedFallback = parseDateOnly(rawFallback);
    if (parsedFallback) {
      chronDates.push(parsedFallback);
    }
  }

  // Zero-data state (0 confirmed period start dates)
  if (chronDates.length === 0) {
    return {
      hasData: false,
      trackingState: 'no_data',
      trackingSuppressed: false,
      lifeStage,
      todayDate: isoDate(today),
      userTimezone,
      timezoneSource,
      algorithmVersion: periodPredictionConfig.algorithmVersion,
      calculatedAt: new Date().toISOString(),
      currentCycle: {
        currentCycleDay: null,
        phase: 'Not Logged',
        isEstimate: true,
        cycleStartDate: null,
        latestConfirmedPeriodStartDate: null,
        periodDurationDays: periodPredictionConfig.defaultPeriodDurationDays,
        periodDurationSource: 'default',
        periodDurationObservations: 0,
        isCurrentPeriod: false,
        periodDay: null,
        isOverdue: false,
        daysOverdue: 0,
      },
      prediction: {
        nextPeriodStartDate: null,
        daysUntilNextPeriod: null,
        estimatedOvulationDate: null,
        fertileWindowStart: null,
        fertileWindowEnd: null,
        isOvulationSupported: false,
        disclaimer: periodPredictionConfig.disclaimerText,
      },
      dataSufficiency: {
        completedCyclesCount: 0,
        validStartDatesCount: 0,
        confidenceLevel: 'none',
        displayLabel: 'No Data Logged',
        message: 'Log your period to receive an estimate.',
      },
      historicalRecordsUsed: [],
    };
  }

  // Calculate historical completed cycles (intervals between consecutive start dates)
  const completedCycleIntervals = [];
  const historicalRecordsUsed = [];

  for (let i = 0; i < chronDates.length; i++) {
    let intervalDays = null;
    if (i < chronDates.length - 1) {
      const diff = daysBetween(chronDates[i], chronDates[i + 1]);
      if (diff >= periodPredictionConfig.minCycleLengthDays && diff <= periodPredictionConfig.maxCycleLengthDays) {
        intervalDays = diff;
        completedCycleIntervals.push(diff);
      }
    }
    historicalRecordsUsed.push({
      startDate: isoDate(chronDates[i]),
      intervalDays,
    });
  }

  const statedCycleLength = parseCycleLengthFromAnswers(onboardingAnswers);
  const { periodDurationDays, periodDurationSource, periodDurationObservations } =
    resolvePeriodDuration(entries, onboardingAnswers, periodDurationBounds);

  let calculatedCycleLength = statedCycleLength;
  let confidenceLevel = 'low';
  let trackingState = 'learning_initial';
  let displayLabel = 'Learning baseline (1 period logged)';
  let sufficiencyMessage = 'Estimated ovulation based on 28-day baseline. Not medically certain.';
  let varianceDays = 1.0;

  if (completedCycleIntervals.length === 1) {
    calculatedCycleLength = completedCycleIntervals[0];
    confidenceLevel = 'medium_low';
    trackingState = 'learning_partial';
    displayLabel = 'Learning (1 completed cycle)';
    sufficiencyMessage = 'Estimated ovulation based on 1 logged cycle. Accuracy increases with more logs.';
  } else if (completedCycleIntervals.length === 2) {
    const [wRecent, wOlder] = periodPredictionConfig.intervalWeights2;
    calculatedCycleLength = Math.round(completedCycleIntervals[1] * wRecent + completedCycleIntervals[0] * wOlder);
    confidenceLevel = 'medium_high';
    trackingState = 'learning_advanced';
    displayLabel = 'Learning (2 completed cycles)';
    sufficiencyMessage = 'Estimated ovulation based on 2 logged cycles.';
  } else if (completedCycleIntervals.length >= 3) {
    const recent = completedCycleIntervals.slice(-3);
    const [w1, w2, w3] = periodPredictionConfig.intervalWeights3Plus;
    calculatedCycleLength = Math.round(recent[2] * w1 + recent[1] * w2 + recent[0] * w3);
    confidenceLevel = 'higher_confidence';
    trackingState = 'sufficient_data';
    displayLabel = 'Higher confidence from 3 completed cycles';
    sufficiencyMessage = 'Estimated ovulation based on your recent cycle history.';

    const mean = recent.reduce((sum, val) => sum + val, 0) / recent.length;
    const variance = recent.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / recent.length;
    varianceDays = Math.max(1.0, Math.round(Math.sqrt(variance) * 10) / 10);
  }

  const isIrregular = onboardingAnswers.reproductive_cycle_type === 'Highly unpredictable' ||
    varianceDays >= periodPredictionConfig.irregularVarianceThresholdDays;

  if (isIrregular && trackingState !== 'no_data') {
    confidenceLevel = 'low_irregular';
    trackingState = 'irregular_pattern';
    displayLabel = 'Irregular Cycle Pattern';
    sufficiencyMessage = 'Estimated fertile window range. Irregular patterns make exact timing variable.';
  }

  // Hormonal contraception suppresses ovulation, so there is no fertile window
  // to estimate and the bleed is a withdrawal bleed rather than a period the
  // cycle model describes.
  //
  // The question was asked at onboarding -- "Are you using hormonal
  // contraception?" -- with the subtitle "Contraception influences cycle
  // symptoms and bleeding patterns", and the answer was then read by nothing
  // at all. Someone on an implant was shown an ovulation date and a fertile
  // window calculated as though she were cycling, which is the one place this
  // app must not guess.
  //
  // The dates themselves still come from what she logs; only the ovulation
  // half is withheld, and it is said plainly rather than silently blanked.
  // Two screens write this one key with different vocabularies, so both are
  // listed. The signup wizard asks "Are you currently using hormonal
  // contraception?" and stores Yes/No; the stage questionnaire asks which
  // method and stores its name. Handling only one set would have left the
  // answer ignored for everyone who came through the other screen -- and the
  // wizard is the one every new account goes through.
  const HORMONAL_CONTRACEPTION = new Set([
    'Yes',                    // signup wizard
    'Birth control pill',     // stage questionnaire
    'Hormonal IUD / Implant',
  ]);
  const onHormonalContraception =
    HORMONAL_CONTRACEPTION.has(onboardingAnswers.contraception_choice);

  if (onHormonalContraception && trackingState !== 'no_data') {
    confidenceLevel = 'low_hormonal_contraception';
    displayLabel = 'On hormonal contraception';
    sufficiencyMessage =
      'Hormonal contraception usually stops ovulation, so no fertile window is '
      + 'estimated. Bleeding on it is a withdrawal bleed, and its timing comes '
      + 'from the method rather than from a cycle.';
  }

  // The latest known confirmed period start date
  const latestConfirmedPeriodStartDate = chronDates[chronDates.length - 1];

  // Option A (Day 1 standard convention)
  // currentCycleDay is calculated strictly as daysBetween(latestConfirmedPeriodStartDate, today) + 1
  const daysSinceLatestStart = daysBetween(latestConfirmedPeriodStartDate, today);
  const currentCycleDay = daysSinceLatestStart + 1; // Day 1 if start is today

  const isOverdue = currentCycleDay > calculatedCycleLength;
  const daysOverdue = isOverdue ? currentCycleDay - calculatedCycleLength : 0;

  const isCurrentPeriod = currentCycleDay >= 1 && currentCycleDay <= periodDurationDays;
  const periodDay = isCurrentPeriod ? currentCycleDay : null;

  // Next period date calculation
  const nextPeriodStart = addDays(latestConfirmedPeriodStartDate, calculatedCycleLength);
  const daysUntilNextPeriod = isOverdue ? null : daysBetween(today, nextPeriodStart);

  // Ovulation and fertile window calculation
  const ovulationDate = addDays(nextPeriodStart, -periodPredictionConfig.lutealPhaseDays);
  const fertileWindowStart = addDays(ovulationDate, -periodPredictionConfig.fertileWindowDaysBeforeOvulation);
  const fertileWindowEnd = addDays(ovulationDate, periodPredictionConfig.fertileWindowDaysAfterOvulation);

  // Phase mapping
  let currentPhase = 'Follicular Phase';
  if (isOverdue) {
    currentPhase = `Late / Overdue Cycle (+${daysOverdue} days)`;
  } else if (isCurrentPeriod) {
    currentPhase = `Menstrual Phase (Day ${currentCycleDay} of ${periodDurationDays})`;
  } else if (today >= fertileWindowStart && today <= fertileWindowEnd) {
    const isOvulationDay = isoDate(today) === isoDate(ovulationDate);
    currentPhase = isOvulationDay ? 'Estimated Ovulation Day' : 'Approximate Fertile Window';
  } else if (currentCycleDay > periodDurationDays && today < fertileWindowStart) {
    currentPhase = 'Follicular Phase';
  } else if (today > fertileWindowEnd && currentCycleDay <= calculatedCycleLength) {
    currentPhase = 'Luteal Phase';
  }

  const earliestPredictionWindow = addDays(nextPeriodStart, -Math.round(varianceDays));
  const latestPredictionWindow = addDays(nextPeriodStart, Math.round(varianceDays));

  return {
    hasData: true,
    trackingState,
    trackingSuppressed: false,
    lifeStage,
    todayDate: isoDate(today),
    userTimezone,
    timezoneSource,
    algorithmVersion: periodPredictionConfig.algorithmVersion,
    calculatedAt: new Date().toISOString(),
    currentCycle: {
      currentCycleDay,
      phase: currentPhase,
      isEstimate: true,
      cycleStartDate: isoDate(latestConfirmedPeriodStartDate),
      latestConfirmedPeriodStartDate: isoDate(latestConfirmedPeriodStartDate),
      periodDurationDays,
      periodDurationSource,
      periodDurationObservations,
      isCurrentPeriod,
      periodDay,
      isOverdue,
      daysOverdue,
    },
    prediction: {
      nextPeriodStartDate: isOverdue ? null : isoDate(nextPeriodStart),
      predictionRange: isOverdue ? null : {
        earliestDate: isoDate(earliestPredictionWindow),
        latestDate: isoDate(latestPredictionWindow),
        varianceDays,
      },
      daysUntilNextPeriod,
      // Withheld on hormonal contraception; see the note above.
      estimatedOvulationDate:
        isOverdue || onHormonalContraception ? null : isoDate(ovulationDate),
      fertileWindowStart:
        isOverdue || onHormonalContraception ? null : isoDate(fertileWindowStart),
      fertileWindowEnd:
        isOverdue || onHormonalContraception ? null : isoDate(fertileWindowEnd),
      isOvulationSupported: !isOverdue && !onHormonalContraception,
      disclaimer: periodPredictionConfig.disclaimerText,
    },
    dataSufficiency: {
      completedCyclesCount: completedCycleIntervals.length,
      validStartDatesCount: chronDates.length,
      confidenceLevel,
      displayLabel,
      message: sufficiencyMessage,
    },
    historicalRecordsUsed,
  };
}
