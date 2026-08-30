import { listEvents, countEvents } from '../repositories/healthEventRepository.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { normalizeLifeStage, getBranchCapabilities } from '../domain/lifeStages.js';
import { RESPONSE_STATES } from '../utils/apiResponse.js';

/**
 * Timeline (spec §11 "TIMELINES").
 *
 * Timeline is raw chronological history. Patterns are interpretation, and the
 * two never duplicate each other: nothing here carries a confidence, a
 * correlation or an explanation.
 */

const TIMELINE_VERSION = 'timeline-v1.0.0';

/**
 * Menopause uses wellness and symptom history rather than menstrual cycle
 * history (spec §11).
 */
const MENOPAUSE_EXCLUDED_TYPES = ['period_logged'];

export async function buildTimeline(userId, { from = null, to = null, eventTypes = null, limit = 50, skip = 0 } = {}) {
  const stageState = await getLifeStageState(userId);
  const lifeStage = normalizeLifeStage(stageState.lifeStage, null);
  const capabilities = getBranchCapabilities(lifeStage);

  let types = Array.isArray(eventTypes) && eventTypes.length > 0 ? eventTypes : null;

  if (!capabilities.cycleLanguage) {
    if (types) types = types.filter((type) => !MENOPAUSE_EXCLUDED_TYPES.includes(type));
    // With no explicit filter the repository returns everything, so the
    // exclusion is applied after the read instead.
  }

  const events = await listEvents(userId, { eventTypes: types, from, to, limit, skip });

  const visible = capabilities.cycleLanguage
    ? events
    : events.filter((event) => !MENOPAUSE_EXCLUDED_TYPES.includes(event.eventType));

  const total = await countEvents(userId, { eventTypes: types, from, to });

  const entries = visible.map((event) => ({
    eventId: event.eventId,
    eventType: event.eventType,
    date: event.timestamp,
    displayText: event.displayText,
    source: event.source,
    userConfirmed: event.userConfirmed,
    detail: event.payload,
    editable: event.source !== 'ai_derived',
  }));

  return {
    state: entries.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: TIMELINE_VERSION,
    data: {
      entries,
      lifeStage,
      // Menopause and pregnancy surfaces are labelled so the frontend can pick
      // non-cycle copy without inferring it.
      historyType: capabilities.cycleLanguage ? 'cycle_and_wellness' : 'wellness_and_symptoms',
      pagination: {
        limit,
        skip,
        total,
        hasMore: skip + entries.length < total,
      },
    },
  };
}
