import {
  getStage,
  listJourneys,
  transitionStage,
  endPregnancy,
  setBranchContext,
  getTransitionHistory,
  setTtcOptIn,
} from '../services/lifeStageService.js';
import { getBranchInitialContext, LIFE_STAGE_CONFIG_VERSION } from '../domain/lifeStages.js';
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
 * Life stage / onboarding branch API (spec §3, §4, §23).
 */

const ERROR_STATUS = {
  UNKNOWN_TARGET_STAGE: 400,
  ALREADY_IN_STAGE: 409,
  TRANSITION_NOT_ALLOWED: 409,
  CONFIRMATION_REQUIRED: 409,
  MISSING_BRANCH_CONTEXT: 422,
  NOT_IN_PREGNANCY_STAGE: 409,
  VALIDATION_FAILED: 400,
};

export const getCurrentStage = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const stage = await getStage(userId);

  return sendData(res, stage, {
    state: stage.lifeStage ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: LIFE_STAGE_CONFIG_VERSION,
    source: SOURCES.RULE,
    lastUpdated: stage.updatedAt ?? undefined,
    errorCode: stage.lifeStage ? null : 'ONBOARDING_REQUIRED',
  });
});

/**
 * The life journey list plus, for each, only the questions that branch needs
 * (spec §3: "Only ask questions needed for the selected journey").
 */
export const getJourneys = contractHandler(async (_req, res) => {
  return sendData(res, listJourneys(), {
    state: RESPONSE_STATES.READY,
    version: LIFE_STAGE_CONFIG_VERSION,
    source: SOURCES.RULE,
  });
});

export const getBranchQuestions = contractHandler(async (req, res) => {
  const questions = getBranchInitialContext(req.params.stage);
  return sendData(res, { stage: req.params.stage, questions }, {
    state: questions.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: LIFE_STAGE_CONFIG_VERSION,
    source: SOURCES.RULE,
  });
});

export const changeStage = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { toStage, confirmed = false, context = {}, reason = null } = req.body ?? {};
  if (!toStage) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'toStage is required.');
  }

  const result = await transitionStage(userId, { toStage, confirmed: Boolean(confirmed), context, reason });

  if (!result.ok) {
    const status = ERROR_STATUS[result.errorCode] ?? 400;
    return res.status(status).json({
      data: {
        fromStage: result.fromStage ?? null,
        toStage: result.toStage ?? null,
        requiresConfirmation: result.requiresConfirmation ?? false,
        missingContext: result.missingContext ?? null,
        requiredContext: result.requiredContext ?? null,
        reason: result.reason ?? null,
      },
      state: RESPONSE_STATES.ERROR,
      lastUpdated: new Date().toISOString(),
      source: SOURCES.RULE,
      version: LIFE_STAGE_CONFIG_VERSION,
      permissions: null,
      errorCode: result.errorCode,
    });
  }

  await recordAnalyticsEvent({
    userId,
    pseudonymousId: null,
    eventName: 'branch_selected',
    properties: { branch: result.state.lifeStage },
  });

  const stage = await getStage(userId);
  return sendData(res, { stage, transition: result.transition }, {
    state: RESPONSE_STATES.READY,
    version: LIFE_STAGE_CONFIG_VERSION,
    source: SOURCES.RULE,
  });
});

export const saveBranchContext = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const context = req.body?.context;
  if (!context || typeof context !== 'object' || Array.isArray(context)) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'context must be an object.');
  }

  // A self-reported pregnancy week only means anything alongside the date it
  // was reported, so that is stamped here rather than trusted from the client.
  if (context.pregnancy_week !== undefined && !context.pregnancy_week_recorded_on) {
    context.pregnancy_week_recorded_on = new Date().toISOString().slice(0, 10);
  }

  const state = await setBranchContext(userId, context);
  return sendData(res, state, { state: RESPONSE_STATES.READY, version: LIFE_STAGE_CONFIG_VERSION, source: SOURCES.MANUAL });
});

/**
 * Pregnancy exit / loss (spec §15). Always requires explicit confirmation.
 */
export const exitPregnancy = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { outcome, endDate = null, confirmed = false } = req.body ?? {};
  const result = await endPregnancy(userId, { outcome, endDate, confirmed: Boolean(confirmed) });

  if (!result.ok) {
    const status = ERROR_STATUS[result.errorCode] ?? 400;
    return res.status(status).json({
      data: { requiresConfirmation: result.requiresConfirmation ?? false },
      state: RESPONSE_STATES.ERROR,
      lastUpdated: new Date().toISOString(),
      source: SOURCES.RULE,
      version: LIFE_STAGE_CONFIG_VERSION,
      permissions: null,
      errorCode: result.errorCode,
    });
  }

  return sendData(res, {
    nextStage: result.nextStage,
    supportFlow: result.supportFlow,
    state: result.state,
    partnerPregnancySharingMustStop: result.partnerPregnancySharingMustStop,
  }, {
    state: RESPONSE_STATES.READY,
    version: LIFE_STAGE_CONFIG_VERSION,
    source: SOURCES.RULE,
  });
});

export const getHistory = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const history = await getTransitionHistory(userId, Math.min(Number(req.query.limit) || 50, 200));
  return sendData(res, history, {
    state: history.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: LIFE_STAGE_CONFIG_VERSION,
    source: SOURCES.RULE,
  });
});

/**
 * Fertility tracking stays separate from ordinary cycle tracking unless the
 * user opts in (spec §5).
 */
export const updateTtcOptIn = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  if (typeof req.body?.optedIn !== 'boolean') {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'optedIn must be a boolean.');
  }

  const state = await setTtcOptIn(userId, req.body.optedIn);
  return sendData(res, state, { state: RESPONSE_STATES.READY, version: LIFE_STAGE_CONFIG_VERSION, source: SOURCES.MANUAL });
});
