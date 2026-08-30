import {
  LIFE_STAGES,
  LIFE_JOURNEYS,
  LIFE_STAGE_CONFIG_VERSION,
  normalizeLifeStage,
  evaluateTransition,
  getAllowedTransitions,
  getBranchInitialContext,
  getBranchCapabilities,
  getHomeModules,
  TRANSITION_CONTEXT_REQUIREMENTS,
} from '../domain/lifeStages.js';
import { resolvePregnancyEnd } from '../domain/pregnancy.js';
import {
  getLifeStageState,
  upsertLifeStageState,
  mergeBranchContext,
  recordTransition,
  listTransitions,
  syncLegacyProfileStage,
} from '../repositories/lifeStageRepository.js';
import { createEvent } from '../repositories/healthEventRepository.js';
import { cancelByCategory } from '../repositories/notificationRepository.js';
import { recordAnalyticsEvent } from '../repositories/auditRepository.js';

/**
 * Life stage engine (spec §4, §23).
 *
 * Owns the current branch, the branch context needed to render it, and the
 * guarded transitions between branches. Historical data is never deleted on
 * transition; only the active stage and the context change.
 */

export async function getStage(userId) {
  const state = await getLifeStageState(userId);
  const stage = normalizeLifeStage(state.lifeStage, null);

  return {
    ...state,
    lifeStage: stage,
    capabilities: stage ? getBranchCapabilities(stage) : null,
    modules: stage ? getHomeModules(stage) : [],
    allowedTransitions: getAllowedTransitions(stage),
    requiredContext: getBranchInitialContext(stage),
    configVersion: LIFE_STAGE_CONFIG_VERSION,
  };
}

export function listJourneys() {
  return LIFE_JOURNEYS.map((journey) => ({
    ...journey,
    requiredContext: getBranchInitialContext(journey.id),
  }));
}

/**
 * Which context keys the target stage still needs before it can render.
 */
export function missingContextFor(targetStage, branchContext = {}) {
  const required = TRANSITION_CONTEXT_REQUIREMENTS[targetStage];
  if (!required) return [];

  // Any one of the listed keys satisfies the requirement, since a stage can
  // usually be anchored several ways (a due date OR a week, for example).
  const hasAny = required.some((key) => {
    const value = branchContext?.[key];
    return value !== undefined && value !== null && value !== '';
  });

  return hasAny ? [] : required;
}

/**
 * Performs a guarded transition.
 *
 * @returns {{ ok: boolean, errorCode?: string, requiresConfirmation?: boolean,
 *             missingContext?: string[], state?: object, transition?: object }}
 */
export async function transitionStage(userId, {
  toStage,
  confirmed = false,
  context = {},
  reason = null,
  triggeredBy = 'user',
}) {
  const current = await getLifeStageState(userId);
  const fromStage = normalizeLifeStage(current.lifeStage, null);
  const target = normalizeLifeStage(toStage, null);

  const evaluation = evaluateTransition(fromStage, target, { confirmed });
  if (!evaluation.allowed) {
    return {
      ok: false,
      errorCode: evaluation.errorCode,
      requiresConfirmation: evaluation.requiresConfirmation,
      fromStage,
      toStage: target,
      reason: evaluation.reason,
    };
  }

  // Pregnancy content stays blocked once a pregnancy has ended, so week-by-week
  // content cannot resume by re-entering the stage (spec §15).
  if (target === LIFE_STAGES.PREGNANCY && current.pregnancyContentBlocked && !confirmed) {
    return {
      ok: false,
      errorCode: 'CONFIRMATION_REQUIRED',
      requiresConfirmation: true,
      fromStage,
      toStage: target,
      reason: 'previous_pregnancy_ended',
    };
  }

  const mergedContext = { ...(current.branchContext ?? {}), ...(context ?? {}) };
  const missing = missingContextFor(target, mergedContext);
  if (missing.length > 0) {
    return {
      ok: false,
      errorCode: 'MISSING_BRANCH_CONTEXT',
      missingContext: missing,
      fromStage,
      toStage: target,
      requiredContext: getBranchInitialContext(target),
    };
  }

  const patch = {
    lifeStage: target,
    branchContext: mergedContext,
  };

  if (target === LIFE_STAGES.TTC) patch.ttcOptedIn = true;
  if (target === LIFE_STAGES.PREGNANCY) patch.pregnancyContentBlocked = false;

  const state = await upsertLifeStageState(userId, patch);

  const transition = await recordTransition(userId, {
    fromStage,
    toStage: target,
    reason: reason ?? evaluation.reason,
    confirmed,
    triggeredBy,
    metadata: missing.length === 0 ? null : { missing },
  });

  // Keep the legacy profile field in step so services that still read
  // `user.life_stage` do not disagree with the engine.
  await syncLegacyProfileStage(userId, target);

  await recordAnalyticsEvent({
    userId,
    pseudonymousId: null,
    eventName: 'life_stage_transitioned',
    properties: { fromStage: fromStage ?? 'none', toStage: target },
  });

  return { ok: true, state, transition };
}

/**
 * Pregnancy exit / loss (spec §15, §23). Requires explicit confirmation,
 * records the event for history, blocks pregnancy content and cancels
 * pregnancy notifications.
 */
export async function endPregnancy(userId, { outcome, endDate = null, confirmed = false }) {
  if (!confirmed) {
    return { ok: false, errorCode: 'CONFIRMATION_REQUIRED', requiresConfirmation: true };
  }

  const resolution = resolvePregnancyEnd(outcome);
  if (!resolution) {
    return { ok: false, errorCode: 'VALIDATION_FAILED', error: 'Unknown pregnancy outcome.' };
  }

  const current = await getLifeStageState(userId);
  if (normalizeLifeStage(current.lifeStage, null) !== LIFE_STAGES.PREGNANCY) {
    return { ok: false, errorCode: 'NOT_IN_PREGNANCY_STAGE' };
  }

  // History first: the event is what preserves the record after the stage moves.
  await createEvent(userId, {
    eventType: 'pregnancy_ended',
    payload: { outcome, endDate },
    source: 'manual',
  });

  const nextStage = resolution.nextStage;
  const contextPatch = {};
  if (outcome === 'birth') {
    contextPatch.baby_birth_date = endDate ?? new Date().toISOString().slice(0, 10);
  }

  await upsertLifeStageState(userId, {
    lifeStage: nextStage,
    branchContext: { ...(current.branchContext ?? {}), ...contextPatch, pregnancy_ended_outcome: outcome, pregnancy_ended_on: endDate },
    pregnancyContentBlocked: resolution.blocksPregnancyContent,
  });

  await recordTransition(userId, {
    fromStage: LIFE_STAGES.PREGNANCY,
    toStage: nextStage,
    reason: 'pregnancy_ended',
    confirmed: true,
    triggeredBy: 'user',
    metadata: { outcome },
  });

  // Pregnancy milestone reminders must not keep firing afterwards.
  await cancelByCategory(userId, 'pregnancy_milestone', 'pregnancy_ended');

  await syncLegacyProfileStage(userId, nextStage);

  const state = await getLifeStageState(userId);

  return {
    ok: true,
    state,
    outcome,
    nextStage,
    supportFlow: resolution.supportFlow,
    // Partner-visible pregnancy data must stop; the caller revokes on the
    // connection side.
    partnerPregnancySharingMustStop: true,
  };
}

export async function setBranchContext(userId, contextPatch) {
  return mergeBranchContext(userId, contextPatch);
}

export async function getTransitionHistory(userId, limit = 50) {
  return listTransitions(userId, limit);
}

export async function setTtcOptIn(userId, optedIn) {
  return upsertLifeStageState(userId, { ttcOptedIn: Boolean(optedIn) });
}
