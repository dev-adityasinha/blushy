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
  lutealPhaseDays: 14,
  fertileWindowDaysBeforeOvulation: 5,
  fertileWindowDaysAfterOvulation: 1,
  irregularVarianceThresholdDays: 4.0,
  intervalWeights3Plus: [0.5, 0.3, 0.2],
  intervalWeights2: [0.6, 0.4],
  defaultFallbackTimezone: 'Asia/Kolkata',
  disclaimerText: 'Predictions are estimates and are not intended for contraception or medical diagnosis.',
};
