import { computePatterns, INSIGHT_STATUS, PATTERN_ENGINE_VERSION } from '../domain/patterns.js';
import { getBranchCapabilities, normalizeLifeStage } from '../domain/lifeStages.js';
import { listEvents } from '../repositories/healthEventRepository.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import {
  upsertInsight,
  listInsights,
  setInsightStatus,
  invalidateInsightsForEvents,
  expireStaleInsights,
  recordFeedback,
  getInsight,
} from '../repositories/insightRepository.js';
import { buildCycleDayResolver } from './cycleService.js';
import { recordAnalyticsEvent } from '../repositories/auditRepository.js';
import { RESPONSE_STATES, SOURCES } from '../utils/apiResponse.js';

/**
 * Insight / pattern engine (spec §7, §8).
 *
 * Numbers come from the deterministic pattern engine. Each stored insight keeps
 * its evidence, window, strength, version and status so it can be traced,
 * expired and invalidated.
 */

const EVENT_TYPES_FOR_PATTERNS = [
  'sleep_logged', 'mood_logged', 'energy_logged', 'symptom_logged',
  'pain_logged', 'hydration_logged', 'stress_logged', 'hot_flash_logged',
];

/**
 * Recomputes patterns and persists the result.
 */
export async function refreshInsights(userId, { windowDays = 60, referenceDate = new Date() } = {}) {
  const stageState = await getLifeStageState(userId);
  const lifeStage = normalizeLifeStage(stageState.lifeStage, null);
  const capabilities = getBranchCapabilities(lifeStage);

  await expireStaleInsights(userId, referenceDate);

  const from = new Date(referenceDate.getTime() - windowDays * 86400000).toISOString();
  const events = await listEvents(userId, {
    eventTypes: EVENT_TYPES_FOR_PATTERNS,
    from,
    limit: 500,
  });

  const cycleDayResolver = capabilities.cycleLanguage ? await buildCycleDayResolver(userId) : null;

  const result = computePatterns({
    events,
    windowDays,
    referenceDate,
    cycleDayResolver,
    allowCycleInsights: capabilities.cycleLanguage && Boolean(cycleDayResolver),
  });

  if (result.state !== 'ready') {
    return { state: result.state, insights: [], reason: result.reason, engineVersion: result.engineVersion };
  }

  const persisted = [];
  for (const candidate of result.insights) {
    const saved = await upsertInsight(userId, {
      ...candidate,
      dedupeKey: `${candidate.type}:${candidate.metadata?.symptom ?? 'default'}`,
      audience: 'self',
    });
    if (saved.status === INSIGHT_STATUS.ACTIVE) persisted.push(saved);
  }

  return {
    state: persisted.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    insights: persisted,
    reason: null,
    engineVersion: result.engineVersion,
    windowStart: result.windowStart,
    windowEnd: result.windowEnd,
  };
}

/**
 * Read model for the Patterns card. Recomputes when nothing active is stored so
 * a first-time viewer is not shown an empty card that would populate on the
 * next request.
 */
export async function getPatterns(userId, { refresh = false, limit = 10 } = {}) {
  if (refresh) {
    const refreshed = await refreshInsights(userId);
    if (refreshed.state === 'insufficient_data' || refreshed.state === 'empty') {
      return {
        state: refreshed.state === 'empty' ? RESPONSE_STATES.EMPTY : RESPONSE_STATES.INSUFFICIENT_DATA,
        data: [],
        version: refreshed.engineVersion,
        source: SOURCES.RULE,
        reason: refreshed.reason,
      };
    }
  }

  const stored = await listInsights(userId, { status: INSIGHT_STATUS.ACTIVE, audience: 'self', limit });

  if (stored.length === 0 && !refresh) {
    const refreshed = await refreshInsights(userId);
    return {
      state: refreshed.state === 'ready' ? RESPONSE_STATES.READY
        : refreshed.state === 'insufficient_data' ? RESPONSE_STATES.INSUFFICIENT_DATA
          : RESPONSE_STATES.EMPTY,
      data: refreshed.insights,
      version: refreshed.engineVersion ?? PATTERN_ENGINE_VERSION,
      source: SOURCES.RULE,
      reason: refreshed.reason ?? null,
    };
  }

  return {
    state: stored.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    data: stored,
    version: PATTERN_ENGINE_VERSION,
    source: SOURCES.RULE,
    reason: stored.length === 0 ? 'no_active_insights' : null,
  };
}

export async function dismissInsight(userId, insightId) {
  const insight = await getInsight(userId, insightId);
  if (!insight) return null;

  const updated = await setInsightStatus(userId, insightId, INSIGHT_STATUS.DISMISSED, 'user_dismissed');
  await recordAnalyticsEvent({
    userId,
    pseudonymousId: null,
    eventName: 'insight_dismissed',
    properties: { insightType: insight.type },
  });
  return updated;
}

export async function submitInsightFeedback(userId, insightId, { helpful, note = null }) {
  const insight = await getInsight(userId, insightId);
  if (!insight) return null;
  return recordFeedback(userId, insightId, { helpful, note });
}

export async function markInsightViewed(userId, insightId) {
  const insight = await getInsight(userId, insightId);
  if (!insight) return null;
  await recordAnalyticsEvent({
    userId,
    pseudonymousId: null,
    eventName: 'insight_viewed',
    properties: { insightType: insight.type },
  });
  return insight;
}

/**
 * Called whenever health events are deleted so nothing keeps citing evidence
 * the user removed (spec §7, §25 "Source log deleted -> dependent insight
 * invalidated").
 */
export async function handleEventsDeleted(userId, deletedEventIds = []) {
  if (!Array.isArray(deletedEventIds) || deletedEventIds.length === 0) {
    return { invalidated: 0, recomputed: false };
  }

  const invalidated = await invalidateInsightsForEvents(userId, deletedEventIds);
  const recomputed = await refreshInsights(userId);

  return {
    invalidated,
    recomputed: recomputed.state === RESPONSE_STATES.READY,
    activeInsights: recomputed.insights?.length ?? 0,
  };
}
