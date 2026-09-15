import { evaluateUserSafety, buildSafetyFlow, getEmergencyResources, resolveRegion, listRedFlagRules } from '../services/safetyService.js';
import { scoreScreening, getInstrument, INSTRUMENTS, shouldTriggerMoodCheckIn } from '../domain/screening.js';
import { saveScreening, listScreenings, recordHandoff, getLatestScreening } from '../repositories/screeningRepository.js';
import { getContent } from '../repositories/medicalContentRepository.js';
import { listEvents } from '../repositories/healthEventRepository.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { recordAnalyticsEvent } from '../repositories/auditRepository.js';
import { buildSummary, saveSummary, listSummaries, getSummary, deleteSummary } from '../services/doctorCompanionService.js';
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
 * Safety, screening and doctor companion endpoints
 * (spec §15, §16, §18, §26).
 */

/* ------------------------------------------------------------------ *
 * Safety state
 * ------------------------------------------------------------------ */

export const getSafetyState = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const evaluation = await evaluateUserSafety(userId, { surface: 'safety_check' });
  const flow = await buildSafetyFlow(evaluation);

  return sendData(res, {
    triggered: evaluation.triggered,
    level: evaluation.level,
    suppressWellnessContent: evaluation.suppressWellnessContent,
    suppressionSources: evaluation.suppressionSources,
    flow: flow.data,
    region: evaluation.region,
  }, {
    state: evaluation.triggered ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: evaluation.rulesetVersion,
    source: SOURCES.MEDICAL_REFERENCE,
  });
});

/**
 * Checks free text (a message being typed, a journal draft) against the red
 * flag rules before it is acted on.
 */
export const checkText = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const text = typeof req.body?.text === 'string' ? req.body.text.slice(0, 5000) : '';
  const evaluation = await evaluateUserSafety(userId, { freeText: text, surface: req.body?.surface ?? 'text_check' });
  const flow = await buildSafetyFlow(evaluation);

  return sendData(res, {
    triggered: evaluation.triggered,
    level: evaluation.level,
    suppressWellnessContent: evaluation.suppressWellnessContent,
    flow: flow.data,
  }, {
    state: evaluation.triggered ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: evaluation.rulesetVersion,
    source: SOURCES.MEDICAL_REFERENCE,
  });
});

/**
 * Location-aware emergency resources (spec §15: "do not hardcode one
 * country's number").
 */
export const getEmergencyContacts = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);

  let region = req.query.region ?? null;
  if (!region && userId) {
    const stageState = await getLifeStageState(userId);
    region = resolveRegion({ region: stageState.region, locale: stageState.locale, timezone: stageState.timezone });
  }

  const resources = getEmergencyResources(region);
  return sendData(res, resources, {
    state: RESPONSE_STATES.READY,
    source: SOURCES.MEDICAL_REFERENCE,
    version: 'emergency-resources-v1.0.0',
    // A null emergency number is a real, honest state: Blushy will not guess.
    errorCode: resources.emergencyNumber ? null : 'REGION_UNKNOWN',
  });
});

/* ------------------------------------------------------------------ *
 * Screening
 * ------------------------------------------------------------------ */

export const listInstruments = contractHandler(async (_req, res) => {
  const instruments = Object.values(INSTRUMENTS).map((instrument) => ({
    id: instrument.id,
    name: instrument.name,
    version: instrument.version,
    itemCount: instrument.itemCount,
    optionScores: instrument.optionScores,
    maxScore: instrument.maxScore,
    appliesToLifeStages: instrument.appliesToLifeStages,
    checkpointDays: instrument.checkpointDays,
    // Item wording is licensed clinical content served from the content
    // service, never inlined here (spec §16 "validated wording").
    itemsContentId: instrument.contentId,
    source: instrument.source,
    reviewer: instrument.reviewer,
    reviewDate: instrument.reviewDate,
  }));

  return sendData(res, instruments, { state: RESPONSE_STATES.READY, source: SOURCES.MEDICAL_REFERENCE });
});

export const getInstrumentItems = contractHandler(async (req, res) => {
  const instrument = getInstrument(req.params.instrumentId);
  if (!instrument) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Unknown screening instrument.');

  const content = await getContent(instrument.contentId, { approvedOnly: true });

  if (!content) {
    // The questionnaire cannot be presented with paraphrased wording, so the
    // honest answer is that it is unavailable.
    return sendData(res, {
      instrumentId: instrument.id,
      instrumentName: instrument.name,
      instrumentVersion: instrument.version,
      itemsAvailable: false,
      reason: 'validated_wording_not_loaded',
      message: 'The validated questionnaire wording has not been loaded into the content service for this deployment.',
    }, {
      state: RESPONSE_STATES.EMPTY,
      source: SOURCES.MEDICAL_REFERENCE,
      version: instrument.version,
      errorCode: 'CONTENT_UNAVAILABLE',
    });
  }

  return sendData(res, {
    instrumentId: instrument.id,
    instrumentName: instrument.name,
    instrumentVersion: instrument.version,
    itemCount: instrument.itemCount,
    optionScores: instrument.optionScores,
    itemsAvailable: true,
    content,
  }, {
    state: RESPONSE_STATES.READY,
    source: SOURCES.MEDICAL_REFERENCE,
    version: instrument.version,
  });
});

export const submitScreening = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { instrumentId, responses, checkpointDay = null } = req.body ?? {};
  const scored = scoreScreening(instrumentId, responses);

  if (!scored.ok) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, scored.error);
  }

  const saved = await saveScreening(userId, scored.result, { checkpointDay, rawResponses: responses });

  // A concerning result routes to professional support, not generic AI wellness
  // tips (spec §16).
  let supportFlow = null;
  if (scored.result.requiresProfessionalSupport) {
    const evaluation = await evaluateUserSafety(userId, { surface: 'screening' });
    const flow = await buildSafetyFlow(evaluation);
    supportFlow = {
      required: true,
      reason: scored.result.crisisItemPositive ? 'crisis_item_positive' : 'score_above_threshold',
      emergencyResources: evaluation.emergencyResources,
      safetySteps: flow.data?.steps ?? [],
      message: 'This result suggests it would help to speak with a health professional. Blushy is not able to assess or diagnose.',
    };
  }

  await recordAnalyticsEvent({
    userId,
    pseudonymousId: null,
    eventName: 'screening_completed',
    properties: { instrumentId: scored.result.instrumentId },
  });

  return sendData(res, {
    result: {
      ...saved,
      outcome: scored.result.outcome,
      disclaimer: scored.result.disclaimer,
    },
    supportFlow,
  }, {
    httpStatus: 201,
    state: RESPONSE_STATES.READY,
    version: scored.result.engineVersion,
    source: SOURCES.MEDICAL_REFERENCE,
  });
});

export const getScreeningHistory = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const rows = await listScreenings(userId, {
    instrumentId: req.query.instrumentId ?? null,
    limit: Math.min(Number(req.query.limit) || 20, 60),
  });

  return sendData(res, rows, {
    state: rows.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.MEDICAL_REFERENCE,
  });
});

export const shareScreeningHandoff = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const sharedWith = req.body?.sharedWith;
  if (!sharedWith) return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'sharedWith is required.');

  const updated = await recordHandoff(userId, req.params.screeningId, sharedWith);
  if (!updated) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Screening not found.');

  return sendData(res, updated, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

/**
 * Rule-based check-in prompt from repeated concerning mood logs (spec §16).
 */
export const getMoodCheckInStatus = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const moodEvents = await listEvents(userId, {
    eventTypes: ['mood_logged'],
    from: new Date(Date.now() - 21 * 86400000).toISOString(),
    limit: 100,
  });

  const latest = await getLatestScreening(userId, 'EPDS');
  const result = shouldTriggerMoodCheckIn(moodEvents, { lastTriggeredAt: latest?.completedAt ?? null });

  return sendData(res, result, {
    state: result.triggered ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.RULE,
    version: result.ruleId,
  });
});

/* ------------------------------------------------------------------ *
 * Doctor / appointment companion
 * ------------------------------------------------------------------ */

export const previewDoctorSummary = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const from = req.query.from ?? new Date(Date.now() - 90 * 86400000).toISOString();
  const to = req.query.to ?? new Date().toISOString();

  const summary = await buildSummary(userId, {
    from,
    to,
    includeInsights: req.query.includeInsights !== 'false',
    includeScreenings: req.query.includeScreenings === 'true',
  });

  return sendData(res, summary.data, { state: summary.state, version: summary.version, source: SOURCES.MANUAL });
});

export const createDoctorSummary = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { from, to, sections, questions = [], title = null } = req.body ?? {};
  if (!Array.isArray(sections)) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'sections must be an array. Remove any entries you do not want to share before saving.');
  }

  const saved = await saveSummary(userId, { from, to, sections, questions, title });
  return sendData(res, saved, { httpStatus: 201, state: RESPONSE_STATES.READY, version: saved.version, source: SOURCES.MANUAL });
});

export const getDoctorSummaries = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const rows = await listSummaries(userId);
  return sendData(res, rows, { state: rows.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY, source: SOURCES.MANUAL });
});

export const getDoctorSummary = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const summary = await getSummary(userId, req.params.summaryId);
  if (!summary) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Summary not found.');

  return sendData(res, summary, { state: RESPONSE_STATES.READY, version: summary.version, source: SOURCES.MANUAL });
});

export const removeDoctorSummary = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const deleted = await deleteSummary(userId, req.params.summaryId);
  if (!deleted) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Summary not found.');

  return sendData(res, { deleted: true }, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

/* ------------------------------------------------------------------ *
 * Admin: red flag rule visibility (spec §27)
 * ------------------------------------------------------------------ */

export const getRedFlagRules = contractHandler(async (_req, res) => {
  const rules = listRedFlagRules();
  return sendData(res, rules, { state: RESPONSE_STATES.READY, version: rules.rulesetVersion, source: SOURCES.MEDICAL_REFERENCE });
});
