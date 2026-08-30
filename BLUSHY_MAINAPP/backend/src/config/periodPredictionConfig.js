/**
 * Canonical Period & Cycle Prediction Configuration
 * Configurable algorithm constants
 */
export const periodPredictionConfig = {
  algorithmVersion: 'v2.0-canonical-ssot',
  defaultCycleLengthDays: 28,
  defaultPeriodDurationDays: 5,
  minCycleLengthDays: 18,
  maxCycleLengthDays: 60,
  minPeriodDurationDays: 2,
  maxPeriodDurationDays: 10,
  // Logged start/end pairs needed before observed duration outranks the
  // stated onboarding answer. Two matches the interval logic, which also
  // needs a second data point before it trusts what it sees.
  minLoggedPeriodsForDuration: 2,
  lutealPhaseDays: 14,
  fertileWindowDaysBeforeOvulation: 5,
  fertileWindowDaysAfterOvulation: 1,
  irregularVarianceThresholdDays: 4.0,
  intervalWeights3Plus: [0.5, 0.3, 0.2],
  intervalWeights2: [0.6, 0.4],
  defaultFallbackTimezone: 'Asia/Kolkata',
  disclaimerText: 'Predictions are estimates and are not intended for contraception or medical diagnosis.',
};

/** Bounds for `resolvePeriodDuration`, so every consumer agrees on them. */
export const periodDurationBounds = {
  minDays: periodPredictionConfig.minPeriodDurationDays,
  maxDays: periodPredictionConfig.maxPeriodDurationDays,
  defaultDays: periodPredictionConfig.defaultPeriodDurationDays,
  minObservations: periodPredictionConfig.minLoggedPeriodsForDuration,
};
