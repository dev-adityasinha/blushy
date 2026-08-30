/**
 * Period duration (spec §22: cycle arithmetic is deterministic, never inferred
 * by the model).
 *
 * Resolves how many days a user's period lasts, preferring evidence over
 * assumption: what they logged, then what they stated at onboarding, then the
 * caller's default. The source travels with the value so a caller can tell an
 * observation from a fallback.
 *
 * Dependency-free like the rest of `domain/`: bounds are passed in rather than
 * read from config, so this stays unit-testable in isolation.
 */

/** Accepts 'YYYY-MM-DD' (what the period repository stores) or a Date. */
function parseCalendarDate(value) {
  if (!value) return null;
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) return null;
    return new Date(Date.UTC(value.getFullYear(), value.getMonth(), value.getDate()));
  }
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(value).trim());
  if (!match) return null;
  const parsed = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

/**
 * Period lengths actually observed from logged start/end pairs.
 *
 * Inclusive: a period logged as starting and ending on the same day is one
 * day. Values outside the bounds are discarded rather than clamped, so a
 * mistyped end date is dropped instead of dragging the result toward it.
 */
export function observedPeriodDurations(entries, { minDays, maxDays }) {
  const durations = [];
  for (const entry of entries ?? []) {
    const start = parseCalendarDate(entry?.periodStartDate ?? entry?.startDate);
    const end = parseCalendarDate(entry?.periodEndDate ?? entry?.endDate);
    if (!start || !end) continue;
    const days = Math.round((end.getTime() - start.getTime()) / 86400000) + 1;
    if (days >= minDays && days <= maxDays) durations.push(days);
  }
  return durations;
}

/** Median, so one unusually long period does not move the estimate much. */
export function medianOf(numbers) {
  const sorted = [...numbers].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

/**
 * @param entries          period rows carrying periodStartDate / periodEndDate
 * @param onboardingAnswers may hold a stated period_duration_days
 * @param bounds           { minDays, maxDays, defaultDays, minObservations }
 * @returns { periodDurationDays, periodDurationSource, periodDurationObservations }
 */
export function resolvePeriodDuration(entries, onboardingAnswers, bounds) {
  const { minDays, maxDays, defaultDays, minObservations } = bounds;
  const logged = observedPeriodDurations(entries, { minDays, maxDays });

  if (logged.length >= minObservations) {
    return {
      periodDurationDays: Math.round(medianOf(logged)),
      periodDurationSource: 'logged',
      periodDurationObservations: logged.length,
    };
  }

  const stated = Number(
    onboardingAnswers?.period_duration_days ?? onboardingAnswers?.cycle_last_period_duration_days,
  );
  if (Number.isFinite(stated) && stated >= minDays && stated <= maxDays) {
    return {
      periodDurationDays: Math.round(stated),
      periodDurationSource: 'stated',
      periodDurationObservations: logged.length,
    };
  }

  return {
    periodDurationDays: defaultDays,
    periodDurationSource: 'default',
    periodDurationObservations: logged.length,
  };
}
