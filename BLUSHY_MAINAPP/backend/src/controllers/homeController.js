import { getHome } from '../services/homeService.js';
import { getCycleState, logPeriod, removePeriod, listPeriods } from '../services/cycleService.js';
import { getPatterns, dismissInsight, submitInsightFeedback, markInsightViewed, refreshInsights, handleEventsDeleted } from '../services/insightService.js';
import { getCarePlan, completeAction, dismissAction } from '../services/carePlanService.js';
import { getPregnancyModule, getPostpartumModule, getFertilityModule } from '../services/stageModuleService.js';
import { getConditionProfile, recordConditions } from '../services/conditionService.js';
import { upsertReflection, getReflection, listReflections, REFLECTION_STATE_VALUES } from '../repositories/reflectionRepository.js';
import { TTC_REFLECTION_PROMPTS, TTC_REFLECTION_STATES } from '../domain/fertility.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { normalizeLifeStage, LIFE_STAGES } from '../domain/lifeStages.js';
import { recordAnalyticsEvent } from '../repositories/auditRepository.js';
import {
  sendData,
  sendError,
  resolveUserId,
  contractHandler,
  RESPONSE_STATES,
  ERROR_CODES,
  SOURCES,
} from '../utils/apiResponse.js';

/**
 * Home, cycle, patterns, care plan and reflection endpoints
 * (spec §5, §6, §8, §10, §12, §28).
 */

export const getHomeScreen = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const home = await getHome(userId, {
    timezone: req.query.timezone ?? req.get('x-timezone') ?? null,
    userSelectedMode: req.query.mode ?? null,
  });

  return sendData(res, home.data, {
    state: home.state,
    version: home.version,
    source: SOURCES.RULE,
  });
});

/* ------------------------------------------------------------------ *
 * Cycle
 * ------------------------------------------------------------------ */

export const getCycle = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const cycle = await getCycleState(userId, {
    timezone: req.query.timezone ?? req.get('x-timezone') ?? null,
    referenceDate: req.query.referenceDate ?? null,
  });

  return sendData(res, cycle.data, {
    state: cycle.state,
    version: cycle.version,
    source: cycle.source,
    lastUpdated: cycle.lastUpdated,
  });
});

export const createPeriodLog = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { startDate, endDate = null, flow = null, source = 'manual', clientEventId = null } = req.body ?? {};
  if (!startDate) return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'startDate is required.');

  const result = await logPeriod(userId, {
    startDate,
    endDate,
    flow,
    source,
    clientEventId: clientEventId ?? req.get('idempotency-key') ?? null,
  });

  if (!result.ok) return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.error, { field: result.field });

  // The canonical, recalculated cycle state comes back in the same response so
  // the Hero and every dependent card update together (spec §28 steps 16-18).
  const cycle = await getCycleState(userId);

  await recordAnalyticsEvent({ userId, pseudonymousId: null, eventName: 'period_logged', properties: { source } });

  return sendData(res, { event: result.event, entry: result.entry, cycle: cycle.data }, {
    httpStatus: result.deduplicated ? 200 : 201,
    state: cycle.state,
    version: cycle.version,
    source: SOURCES.MANUAL,
  });
});

export const deletePeriodLog = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await removePeriod(userId, {
    entryId: req.params.entryId ?? null,
    eventId: req.query.eventId ?? null,
    startDate: req.query.startDate ?? null,
  });

  if (!result.ok) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Period entry not found.');

  const recalculation = await handleEventsDeleted(userId, result.affectedEventIds);
  const cycle = await getCycleState(userId);

  return sendData(res, { deleted: true, recalculation, cycle: cycle.data }, {
    state: cycle.state,
    version: cycle.version,
    source: SOURCES.MANUAL,
  });
});

export const getPeriodHistory = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const entries = await listPeriods(userId, Math.min(Number(req.query.limit) || 50, 100));
  return sendData(res, entries, {
    state: entries.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.MANUAL,
  });
});

/* ------------------------------------------------------------------ *
 * Patterns / insights
 * ------------------------------------------------------------------ */

export const getPatternsCard = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const patterns = await getPatterns(userId, {
    refresh: req.query.refresh === 'true',
    limit: Math.min(Number(req.query.limit) || 10, 30),
  });

  return sendData(res, patterns.data, {
    state: patterns.state,
    version: patterns.version,
    source: patterns.source,
    errorCode: patterns.state === RESPONSE_STATES.INSUFFICIENT_DATA ? ERROR_CODES.INSUFFICIENT_DATA : null,
    meta: patterns.reason ? { reason: patterns.reason } : null,
  });
});

export const refreshPatterns = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await refreshInsights(userId);
  return sendData(res, result.insights ?? [], {
    state: result.state === 'insufficient_data' ? RESPONSE_STATES.INSUFFICIENT_DATA : result.state,
    version: result.engineVersion,
    source: SOURCES.RULE,
    meta: result.reason ? { reason: result.reason } : null,
  });
});

export const dismissPatternInsight = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const updated = await dismissInsight(userId, req.params.insightId);
  if (!updated) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Insight not found.');

  return sendData(res, updated, { state: RESPONSE_STATES.READY, source: SOURCES.RULE });
});

export const submitPatternFeedback = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  if (typeof req.body?.helpful !== 'boolean') {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'helpful must be a boolean.');
  }

  const feedback = await submitInsightFeedback(userId, req.params.insightId, {
    helpful: req.body.helpful,
    note: req.body?.note ?? null,
  });
  if (!feedback) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Insight not found.');

  return sendData(res, feedback, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export const viewPatternInsight = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const insight = await markInsightViewed(userId, req.params.insightId);
  if (!insight) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Insight not found.');

  return sendData(res, insight, { state: RESPONSE_STATES.READY, source: insight.source });
});

/* ------------------------------------------------------------------ *
 * Care plan
 * ------------------------------------------------------------------ */

export const getCarePlanCard = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const plan = await getCarePlan(userId, { userSelectedMode: req.query.mode ?? null });
  return sendData(res, plan.data, { state: plan.state, version: plan.version, source: plan.source });
});

export const completeCareAction = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const record = await completeAction(userId, req.params.actionId);
  return sendData(res, record, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export const dismissCareAction = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const record = await dismissAction(userId, req.params.actionId);
  return sendData(res, record, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

/* ------------------------------------------------------------------ *
 * Branch modules
 * ------------------------------------------------------------------ */

export const getPregnancy = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const module = await getPregnancyModule(userId);
  return sendData(res, module.data, { state: module.state, version: module.version, source: module.source, errorCode: module.errorCode ?? null });
});

export const getPostpartum = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const module = await getPostpartumModule(userId);
  return sendData(res, module.data, { state: module.state, version: module.version, source: module.source, errorCode: module.errorCode ?? null });
});

export const getFertility = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const module = await getFertilityModule(userId);
  return sendData(res, module.data, { state: module.state, version: module.version, source: module.source });
});

/* ------------------------------------------------------------------ *
 * Reflections
 * ------------------------------------------------------------------ */

function currentPeriodKey() {
  return new Date().toISOString().slice(0, 7);
}

/**
 * Prompts are data driven and stage aware. TTC gets emotionally neutral
 * handling of a cycle that ended without pregnancy (spec §12, §13).
 */
async function resolvePrompt(userId) {
  const stageState = await getLifeStageState(userId);
  const lifeStage = normalizeLifeStage(stageState.lifeStage, null);

  if (lifeStage === LIFE_STAGES.TTC) {
    return {
      promptId: 'ttc_monthly_v1',
      prompt: TTC_REFLECTION_PROMPTS[TTC_REFLECTION_STATES.INCOMPLETE],
      lifeStage,
      allowedStates: Object.values(TTC_REFLECTION_STATES),
      statePrompts: TTC_REFLECTION_PROMPTS,
    };
  }

  return {
    promptId: 'monthly_v1',
    prompt: 'How has this month felt for you?',
    lifeStage,
    allowedStates: ['positive', 'neutral', 'difficult'],
    statePrompts: null,
  };
}

export const getReflectionCard = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const periodKey = req.query.periodKey ?? currentPeriodKey();
  const [existing, promptConfig] = await Promise.all([getReflection(userId, periodKey), resolvePrompt(userId)]);

  return sendData(res, { periodKey, prompt: promptConfig, reflection: existing }, {
    state: existing ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: existing ? SOURCES.MANUAL : SOURCES.RULE,
  });
});

export const saveReflection = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { periodKey = currentPeriodKey(), state, response, sharedWithPartner = false } = req.body ?? {};

  if (state && !REFLECTION_STATE_VALUES.includes(state)) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, `state must be one of: ${REFLECTION_STATE_VALUES.join(', ')}.`);
  }

  const promptConfig = await resolvePrompt(userId);
  const saved = await upsertReflection(userId, {
    periodKey,
    lifeStage: promptConfig.lifeStage,
    promptId: promptConfig.promptId,
    prompt: promptConfig.prompt,
    state,
    response,
    // Private by default: sharing has to be asked for explicitly (spec §12).
    sharedWithPartner: Boolean(sharedWithPartner),
  });

  await recordAnalyticsEvent({ userId, pseudonymousId: null, eventName: 'reflection_completed', properties: { lifeStage: promptConfig.lifeStage ?? undefined } });

  return sendData(res, saved, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export const getReflectionHistory = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const rows = await listReflections(userId, { limit: Math.min(Number(req.query.limit) || 24, 60) });
  return sendData(res, rows, {
    state: rows.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.MANUAL,
  });
});

/* ------------------------------------------------------------------ *
 * Condition profile (spec §14)
 * ------------------------------------------------------------------ */

export const getConditions = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const profile = await getConditionProfile(userId);
  return sendData(res, profile.data, {
    state: profile.state,
    version: profile.version,
    source: profile.source,
  });
});

/**
 * Conditions are recorded only because the user selected them. Nothing infers
 * a diagnosis from logged data (spec §14).
 */
export const saveConditions = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { conditions, diagnosedBy } = req.body ?? {};
  if (!Array.isArray(conditions)) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'conditions must be an array.');
  }

  const result = await recordConditions(userId, { conditions, diagnosedBy });
  if (!result.ok) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.error, { field: result.field });
  }

  const profile = await getConditionProfile(userId);
  return sendData(res, profile.data, {
    httpStatus: 201,
    state: profile.state,
    version: profile.version,
    source: SOURCES.MANUAL,
  });
});
