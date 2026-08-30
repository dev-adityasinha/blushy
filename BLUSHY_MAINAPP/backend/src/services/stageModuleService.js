import { calculatePregnancyState, getMilestones, PREGNANCY_CALC_VERSION } from '../domain/pregnancy.js';
import {
  calculatePostpartumState,
  getRecoveryMilestones,
  RECOVERY_METRICS,
  POSTPARTUM_CALC_VERSION,
} from '../domain/postpartum.js';
import { buildFertilityIndicators, ttcDurationSummary, FERTILITY_CALC_VERSION } from '../domain/fertility.js';
import { getDueCheckpoint, getInstrument } from '../domain/screening.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { listEvents } from '../repositories/healthEventRepository.js';
import { getContentBatch } from '../repositories/medicalContentRepository.js';
import { getCompletedCheckpointDays, getLatestScreening } from '../repositories/screeningRepository.js';
import { getCycleState } from './cycleService.js';
import { RESPONSE_STATES, SOURCES } from '../utils/apiResponse.js';

/**
 * Branch-specific read models: pregnancy, postpartum and TTC/fertility
 * (spec §14 branch requirements, §15, §16, §13).
 *
 * All arithmetic is deterministic; displayed copy is resolved from approved
 * medical content, so nothing clinical is free-form.
 */

/* ------------------------------------------------------------------ *
 * Pregnancy
 * ------------------------------------------------------------------ */

export async function getPregnancyModule(userId, { referenceDate = new Date() } = {}) {
  const stageState = await getLifeStageState(userId);
  const context = stageState.branchContext ?? {};

  if (stageState.pregnancyContentBlocked) {
    return {
      state: RESPONSE_STATES.RESTRICTED,
      version: PREGNANCY_CALC_VERSION,
      source: SOURCES.RULE,
      data: { reason: 'pregnancy_ended', message: 'Pregnancy content is no longer shown.' },
    };
  }

  const pregnancy = calculatePregnancyState({
    dueDate: context.due_date,
    lmpDate: context.lmp_date,
    week: context.pregnancy_week,
    weekRecordedOn: context.pregnancy_week_recorded_on,
    referenceDate,
  });

  if (pregnancy.state !== 'ready') {
    return {
      state: RESPONSE_STATES.INSUFFICIENT_DATA,
      version: pregnancy.calculationVersion,
      source: SOURCES.RULE,
      data: pregnancy,
      errorCode: 'INSUFFICIENT_DATA',
    };
  }

  const milestones = getMilestones(pregnancy.gestationalWeek);
  const contentIds = [
    milestones.current?.contentId,
    ...milestones.upcoming.map((m) => m.contentId),
  ].filter(Boolean);
  const articles = await getContentBatch(contentIds, { approvedOnly: true });
  const articlesById = new Map(articles.map((a) => [a.contentId, a]));

  const decorate = (milestone) => (milestone
    ? { ...milestone, content: articlesById.get(milestone.contentId) ?? null, contentAvailable: articlesById.has(milestone.contentId) }
    : null);

  return {
    state: RESPONSE_STATES.READY,
    version: pregnancy.calculationVersion,
    source: SOURCES.RULE,
    data: {
      ...pregnancy,
      milestones: {
        current: decorate(milestones.current),
        upcoming: milestones.upcoming.map(decorate),
        passedCount: milestones.passed.length,
      },
    },
  };
}

/* ------------------------------------------------------------------ *
 * Postpartum
 * ------------------------------------------------------------------ */

export async function getPostpartumModule(userId, { referenceDate = new Date() } = {}) {
  const stageState = await getLifeStageState(userId);
  const context = stageState.branchContext ?? {};

  const postpartum = calculatePostpartumState({
    birthDate: context.baby_birth_date,
    referenceDate,
  });

  if (postpartum.state !== 'ready') {
    return {
      state: RESPONSE_STATES.INSUFFICIENT_DATA,
      version: postpartum.calculationVersion,
      source: SOURCES.RULE,
      data: postpartum,
      errorCode: 'INSUFFICIENT_DATA',
    };
  }

  const milestones = getRecoveryMilestones(postpartum.daysSinceBirth);
  const contentIds = [milestones.current?.contentId, ...milestones.upcoming.map((m) => m.contentId)].filter(Boolean);
  const articles = await getContentBatch(contentIds, { approvedOnly: true });
  const articlesById = new Map(articles.map((a) => [a.contentId, a]));

  const completedCheckpoints = await getCompletedCheckpointDays(userId, 'EPDS');
  const dueCheckpoint = getDueCheckpoint('EPDS', postpartum.daysSinceBirth, completedCheckpoints);
  const latestScreening = await getLatestScreening(userId, 'EPDS');
  const instrument = getInstrument('EPDS');

  const recentMetrics = await listEvents(userId, {
    eventTypes: ['recovery_metric_logged', 'feeding_logged'],
    limit: 60,
  });

  return {
    state: RESPONSE_STATES.READY,
    version: postpartum.calculationVersion,
    source: SOURCES.RULE,
    data: {
      ...postpartum,
      milestones: {
        current: milestones.current
          ? { ...milestones.current, content: articlesById.get(milestones.current.contentId) ?? null }
          : null,
        upcoming: milestones.upcoming.map((m) => ({ ...m, content: articlesById.get(m.contentId) ?? null })),
        passedCount: milestones.passed.length,
      },
      screening: {
        instrumentId: 'EPDS',
        instrumentName: instrument?.name ?? null,
        instrumentVersion: instrument?.version ?? null,
        // Item wording is licensed clinical content served separately.
        itemsContentId: instrument?.contentId ?? null,
        checkpointDue: dueCheckpoint,
        latestResult: latestScreening
          ? {
            outcome: latestScreening.outcome,
            totalScore: latestScreening.totalScore,
            maxScore: latestScreening.maxScore,
            completedAt: latestScreening.completedAt,
            requiresProfessionalSupport: latestScreening.requiresProfessionalSupport,
            isDiagnosis: false,
          }
          : null,
      },
      recoveryMetrics: {
        definitions: RECOVERY_METRICS,
        // Explicitly self reported unless backed by clinical data (spec §16).
        dataProvenance: 'self_reported',
        recentEntries: recentMetrics.filter((e) => e.eventType === 'recovery_metric_logged').slice(0, 20),
      },
      feedingLogs: recentMetrics.filter((e) => e.eventType === 'feeding_logged').slice(0, 20),
    },
  };
}

/* ------------------------------------------------------------------ *
 * TTC / fertility
 * ------------------------------------------------------------------ */

export async function getFertilityModule(userId, { referenceDate = new Date() } = {}) {
  const stageState = await getLifeStageState(userId);
  const context = stageState.branchContext ?? {};

  const events = await listEvents(userId, {
    eventTypes: ['bbt_logged', 'lh_test_logged', 'cervical_mucus_logged'],
    from: new Date(referenceDate.getTime() - 90 * 86400000).toISOString(),
    limit: 400,
  });

  const cycle = await getCycleState(userId, { referenceDate: referenceDate.toISOString().slice(0, 10) });
  const cyclePrediction = cycle.state === RESPONSE_STATES.READY
    ? { prediction: cycle.data.prediction, algorithmVersion: cycle.data.calculationVersion }
    : null;

  const indicators = buildFertilityIndicators({
    events,
    cyclePrediction,
    referenceDate: referenceDate.toISOString().slice(0, 10),
    ttcOptedIn: Boolean(stageState.ttcOptedIn),
  });

  const duration = ttcDurationSummary({
    ttcStartDate: context.ttc_start_date,
    referenceDate: referenceDate.toISOString().slice(0, 10),
  });

  const stateMap = {
    ready: RESPONSE_STATES.READY,
    insufficient_data: RESPONSE_STATES.INSUFFICIENT_DATA,
    restricted: RESPONSE_STATES.RESTRICTED,
  };

  return {
    state: stateMap[indicators.state] ?? RESPONSE_STATES.EMPTY,
    version: FERTILITY_CALC_VERSION,
    source: SOURCES.RULE,
    data: {
      ...indicators,
      ttcDuration: duration,
      ttcOptedIn: Boolean(stageState.ttcOptedIn),
      // Named explicitly so no client can mistake absence for zero.
      conceptionProbabilitySupported: false,
    },
  };
}

export { POSTPARTUM_CALC_VERSION, PREGNANCY_CALC_VERSION };
