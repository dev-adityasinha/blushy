import { calculatePeriodPredictions } from './periodPredictionService.js';
import { periodPredictionConfig } from '../config/periodPredictionConfig.js';
import { getBranchCapabilities, normalizeLifeStage, LIFE_STAGES } from '../domain/lifeStages.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { createOrUpdatePeriodEntry, getPeriodEntries, deletePeriodEntry } from '../repositories/periodRepository.js';
import { createEvent, listEvents, deleteEvent } from '../repositories/healthEventRepository.js';
import { RESPONSE_STATES, SOURCES } from '../utils/apiResponse.js';

/**
 * Cycle read model (spec §5 "Period & Cycle Tracking", §6 "PERIOD TRACKER --
 * MAKE THE EXISTING UI REAL", §28 example flow).
 *
 * Wraps the existing deterministic prediction service in the standard response
 * contract, and enforces the branch rules the spec is explicit about:
 *  - never show simulated cycle days to a user with no period data
 *  - `insufficient_data` rather than fake precision
 *  - no cycle-centric language after menopause
 *  - a late period never implies pregnancy
 */

const CYCLE_CONTRACT_VERSION = 'cycle-readmodel-v1.0.0';

function contractStateFor(prediction, capabilities) {
  if (!capabilities?.cycleTracking) return RESPONSE_STATES.RESTRICTED;
  if (prediction.trackingState === 'suppressed') return RESPONSE_STATES.RESTRICTED;
  if (prediction.trackingState === 'no_data') return RESPONSE_STATES.EMPTY;
  if (!capabilities.cyclePredictions) return RESPONSE_STATES.INSUFFICIENT_DATA;
  if (['learning_initial'].includes(prediction.trackingState)) return RESPONSE_STATES.INSUFFICIENT_DATA;
  return RESPONSE_STATES.READY;
}

/**
 * Builds the Cycle Hero read model.
 */
export async function getCycleState(userId, { timezone = null, referenceDate = null } = {}) {
  const stageState = await getLifeStageState(userId);
  const lifeStage = normalizeLifeStage(stageState.lifeStage, null);
  const capabilities = getBranchCapabilities(lifeStage);

  // Menopause and pregnancy do not use cycle-centric language at all.
  if (!capabilities.cycleTracking) {
    return {
      state: RESPONSE_STATES.RESTRICTED,
      version: CYCLE_CONTRACT_VERSION,
      source: SOURCES.RULE,
      data: {
        lifeStage,
        cycleTrackingAvailable: false,
        reason: lifeStage === LIFE_STAGES.MENOPAUSE
          ? 'menopause_uses_wellness_history'
          : 'branch_does_not_use_cycle_tracking',
        message: lifeStage === LIFE_STAGES.MENOPAUSE
          ? 'Your history is shown as wellness and symptom history rather than cycles.'
          : 'Cycle tracking is paused for your current stage.',
      },
    };
  }

  const prediction = await calculatePeriodPredictions(userId, { timezone, referenceDate });
  const state = contractStateFor(prediction, capabilities);

  // A branch that tracks periods but does not support predictions (first
  // period, perimenopause) must not receive a projected next date.
  const predictionBlock = capabilities.cyclePredictions
    ? prediction.prediction
    : {
      nextPeriodStartDate: null,
      predictionRange: null,
      daysUntilNextPeriod: null,
      estimatedOvulationDate: null,
      fertileWindowStart: null,
      fertileWindowEnd: null,
      isOvulationSupported: false,
      suppressedReason: lifeStage === LIFE_STAGES.FIRST_PERIOD
        ? 'early_post_menarche_precision_not_supported'
        : 'irregular_stage_precision_not_supported',
      disclaimer: periodPredictionConfig.disclaimerText,
    };

  return {
    state,
    version: prediction.algorithmVersion ?? CYCLE_CONTRACT_VERSION,
    source: SOURCES.RULE,
    lastUpdated: prediction.calculatedAt,
    data: {
      lifeStage,
      cycleTrackingAvailable: true,
      hasData: prediction.hasData,
      trackingState: prediction.trackingState,
      currentCycle: prediction.currentCycle,
      prediction: predictionBlock,
      dataSufficiency: prediction.dataSufficiency,
      historicalRecordsUsed: prediction.historicalRecordsUsed,
      todayDate: prediction.todayDate,
      userTimezone: prediction.userTimezone,
      calculationVersion: prediction.algorithmVersion,
      // A late period is a late period. Nothing here infers pregnancy
      // (spec §6: "Late period must not automatically mean pregnancy").
      pregnancyInferred: false,
      lateNotice: prediction.currentCycle?.isOverdue
        ? 'Your period is later than your logged pattern suggests. Cycles vary for many reasons.'
        : null,
    },
  };
}

/**
 * Logs or corrects a period start. Writes both the canonical health event and
 * the existing period entry table so predictions and timeline agree.
 */
export async function logPeriod(userId, { startDate, endDate = null, flow = null, source = 'manual', clientEventId = null }) {
  const eventResult = await createEvent(userId, {
    eventType: 'period_logged',
    payload: { startDate, endDate, flow },
    timestamp: `${startDate}T00:00:00.000Z`,
    source,
    clientEventId,
  });

  if (!eventResult.ok) {
    return { ok: false, error: eventResult.error, field: eventResult.field };
  }

  const entry = await createOrUpdatePeriodEntry(userId, {
    periodStartDate: startDate,
    periodEndDate: endDate,
    flowIntensity: flow,
    source: source === 'manual' ? 'manual_tracker' : source,
  });

  return { ok: true, event: eventResult.event, entry, deduplicated: eventResult.deduplicated };
}

/**
 * Deletes a period. Returns the affected event IDs so the caller can invalidate
 * dependent insights (spec §6: "Deleting a period invalidates/recalculates
 * cycle derived cards").
 */
export async function removePeriod(userId, { entryId = null, eventId = null, startDate = null }) {
  const affectedEventIds = [];

  if (eventId) {
    const deleted = await deleteEvent(userId, eventId);
    if (deleted.ok) affectedEventIds.push(deleted.event.eventId);
  } else if (startDate) {
    const events = await listEvents(userId, { eventTypes: ['period_logged'], limit: 200 });
    for (const event of events) {
      if (event.payload?.startDate === startDate) {
        const deleted = await deleteEvent(userId, event.eventId);
        if (deleted.ok) affectedEventIds.push(deleted.event.eventId);
      }
    }
  }

  let entryDeleted = false;
  if (entryId) {
    entryDeleted = await deletePeriodEntry(userId, entryId);
  } else if (startDate) {
    const entries = await getPeriodEntries(userId, 100);
    const match = entries.find((e) => e.periodStartDate === startDate);
    if (match) entryDeleted = await deletePeriodEntry(userId, match.id);
  }

  if (!entryDeleted && affectedEventIds.length === 0) {
    return { ok: false, notFound: true };
  }

  return { ok: true, affectedEventIds, entryDeleted };
}

export async function listPeriods(userId, limit = 50) {
  return getPeriodEntries(userId, limit);
}

/**
 * Cycle day for an arbitrary date, used by the pattern engine to test whether
 * symptoms cluster at a point in the cycle. Returns null when there is no valid
 * anchor, so patterns never invent a cycle day.
 */
export async function buildCycleDayResolver(userId) {
  const entries = await getPeriodEntries(userId, 50);
  const starts = entries
    .map((entry) => entry.periodStartDate)
    .filter(Boolean)
    .sort();

  if (starts.length === 0) return null;

  return (timestamp) => {
    const day = new Date(timestamp);
    if (Number.isNaN(day.getTime())) return null;
    const key = day.toISOString().slice(0, 10);

    let anchor = null;
    for (const start of starts) {
      if (start <= key) anchor = start;
      else break;
    }
    if (!anchor) return null;

    const diff = Math.round(
      (new Date(`${key}T00:00:00Z`).getTime() - new Date(`${anchor}T00:00:00Z`).getTime()) / 86400000,
    );
    // Guard against a stale anchor: beyond the configured max cycle length the
    // day number stops being meaningful.
    if (diff < 0 || diff > periodPredictionConfig.maxCycleLengthDays) return null;
    return diff + 1;
  };
}
