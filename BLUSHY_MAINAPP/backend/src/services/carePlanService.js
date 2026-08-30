import {
  buildCarePlan,
  resolveAdaptiveMode,
  buildEnergyBudget,
  COMPLETION_STATES,
  ADAPTIVE_MODES,
} from '../domain/carePlan.js';
import { normalizeLifeStage, getBranchCapabilities } from '../domain/lifeStages.js';
import { calculatePregnancyState } from '../domain/pregnancy.js';
import { calculatePostpartumState } from '../domain/postpartum.js';
import { getDueCheckpoint } from '../domain/screening.js';
import { listEvents } from '../repositories/healthEventRepository.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { getHistory, recordSurfaced, setCompletionState } from '../repositories/carePlanRepository.js';
import { getCompletedCheckpointDays } from '../repositories/screeningRepository.js';
import { listInsights } from '../repositories/insightRepository.js';
import { recordAnalyticsEvent } from '../repositories/auditRepository.js';
import { evaluateUserSafety } from './safetyService.js';
import { getCycleState } from './cycleService.js';
import { RESPONSE_STATES, SOURCES } from '../utils/apiResponse.js';

/**
 * Care Plan service (spec §10, §20).
 *
 * Assembles the deterministic signal context, runs the rule engine, records
 * what was surfaced, and enforces the safety suppression.
 */

const SIGNAL_WINDOW_DAYS = 14;

function average(values) {
  if (values.length === 0) return null;
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

/**
 * Builds the derived signal context the rules read. Everything here comes from
 * stored events or deterministic calculations - nothing is generated.
 */
export async function buildSignalContext(userId, { referenceDate = new Date() } = {}) {
  const stageState = await getLifeStageState(userId);
  const lifeStage = normalizeLifeStage(stageState.lifeStage, null);
  const capabilities = getBranchCapabilities(lifeStage);
  const branchContext = stageState.branchContext ?? {};

  const from = new Date(referenceDate.getTime() - SIGNAL_WINDOW_DAYS * 86400000).toISOString();
  const events = await listEvents(userId, {
    eventTypes: ['sleep_logged', 'energy_logged', 'mood_logged', 'pain_logged', 'hydration_logged', 'activity_logged', 'life_scene_set'],
    from,
    limit: 400,
  });

  const sleepHours = events.filter((e) => e.eventType === 'sleep_logged').map((e) => Number(e.payload?.durationHours)).filter(Number.isFinite);
  const energyLevels = events.filter((e) => e.eventType === 'energy_logged').map((e) => Number(e.payload?.level)).filter(Number.isFinite);
  const hydration = events.filter((e) => e.eventType === 'hydration_logged').map((e) => Number(e.payload?.glasses)).filter(Number.isFinite);
  const activityMinutes = events.filter((e) => e.eventType === 'activity_logged').map((e) => Number(e.payload?.durationMinutes)).filter(Number.isFinite);

  const painEvents = events.filter((e) => e.eventType === 'pain_logged');
  const moodEvents = events.filter((e) => e.eventType === 'mood_logged');

  // Consecutive low mood days, newest first.
  const lowMoods = new Set(['low', 'awful', 'sad']);
  const moodByDay = new Map();
  for (const event of moodEvents) {
    const day = String(event.timestamp).slice(0, 10);
    if (!moodByDay.has(day)) moodByDay.set(day, String(event.payload?.mood ?? '').toLowerCase());
  }
  const sortedDays = [...moodByDay.keys()].sort().reverse();
  let consecutiveLowMoodDays = 0;
  for (const day of sortedDays) {
    if (lowMoods.has(moodByDay.get(day))) consecutiveLowMoodDays += 1;
    else break;
  }

  let daysUntilNextPeriod = null;
  if (capabilities.cyclePredictions) {
    const cycle = await getCycleState(userId, { referenceDate: referenceDate.toISOString().slice(0, 10) });
    daysUntilNextPeriod = cycle.data?.prediction?.daysUntilNextPeriod ?? null;
  }

  let gestationalWeek = null;
  if (capabilities.pregnancy) {
    const pregnancy = calculatePregnancyState({
      dueDate: branchContext.due_date,
      lmpDate: branchContext.lmp_date,
      week: branchContext.pregnancy_week,
      weekRecordedOn: branchContext.pregnancy_week_recorded_on,
      referenceDate,
    });
    gestationalWeek = pregnancy.gestationalWeek;
  }

  let screeningCheckpointDue = null;
  if (capabilities.postpartum) {
    const postpartum = calculatePostpartumState({ birthDate: branchContext.baby_birth_date, referenceDate });
    if (postpartum.state === 'ready') {
      const completed = await getCompletedCheckpointDays(userId, 'EPDS');
      screeningCheckpointDue = getDueCheckpoint('EPDS', postpartum.daysSinceBirth, completed);
    }
  }

  const activeInsights = await listInsights(userId, { limit: 5 });
  const latestScene = events.find((e) => e.eventType === 'life_scene_set');

  return {
    lifeStage,
    capabilities,
    cycleLanguageAllowed: capabilities.cycleLanguage,
    averageSleepHours: average(sleepHours),
    averageEnergyLevel: average(energyLevels),
    latestEnergyLevel: energyLevels.length > 0 ? energyLevels[0] : null,
    averageHydrationGlasses: average(hydration),
    latestPainSeverity: painEvents.length > 0 ? Number(painEvents[0].payload?.severity) : null,
    latestMood: moodEvents.length > 0 ? String(moodEvents[0].payload?.mood ?? '').toLowerCase() : null,
    consecutiveLowMoodDays,
    daysUntilNextPeriod,
    gestationalWeek,
    screeningCheckpointDue,
    hasPatterns: activeInsights.length > 0,
    lifeScene: latestScene?.payload?.scene ?? null,
    totalActivityMinutes: activityMinutes.reduce((sum, v) => sum + v, 0),
  };
}

export async function getCarePlan(userId, { referenceDate = new Date(), userSelectedMode = null } = {}) {
  const context = await buildSignalContext(userId, { referenceDate });
  const safety = await evaluateUserSafety(userId, { surface: 'care_plan' });
  const history = await getHistory(userId, { limit: 150 });

  const adaptiveMode = resolveAdaptiveMode({
    latestEnergyLevel: context.latestEnergyLevel,
    latestMood: context.latestMood,
    userSelectedMode,
  });

  const plan = buildCarePlan({
    context,
    history: history.map((entry) => ({
      actionId: entry.actionId,
      surfacedAt: entry.surfacedAt,
      completionState: entry.completionState,
    })),
    suppressWellness: safety.suppressWellnessContent,
    adaptiveMode,
    referenceDate,
  });

  // Record what is actually shown, so cooldowns reflect reality.
  for (const action of plan.actions) {
    await recordSurfaced(userId, action);
  }

  return {
    state: plan.state === 'ready' ? RESPONSE_STATES.READY
      : plan.state === 'restricted' ? RESPONSE_STATES.RESTRICTED
        : RESPONSE_STATES.EMPTY,
    version: plan.rulesetVersion,
    source: SOURCES.RULE,
    data: {
      actions: plan.actions,
      adaptiveMode: plan.adaptiveMode,
      suppressed: plan.suppressed,
      suppressionReason: plan.suppressionReason,
      energyBudget: buildEnergyBudget({
        averageSleepHours: context.averageSleepHours,
        averageEnergyLevel: context.averageEnergyLevel,
        activityMinutes: context.totalActivityMinutes,
      }),
      lifeScene: context.lifeScene,
    },
  };
}

export async function completeAction(userId, actionId) {
  const record = await setCompletionState(userId, actionId, COMPLETION_STATES.COMPLETED);
  await recordAnalyticsEvent({
    userId,
    pseudonymousId: null,
    eventName: 'care_action_completed',
    properties: { actionId, category: record?.category ?? undefined },
  });
  return record;
}

export async function dismissAction(userId, actionId) {
  return setCompletionState(userId, actionId, COMPLETION_STATES.DISMISSED);
}

export { ADAPTIVE_MODES };
