import { listEvents, createEvent } from '../repositories/healthEventRepository.js';
import { listInsights } from '../repositories/insightRepository.js';
import { listContent } from '../repositories/medicalContentRepository.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { normalizeLifeStage } from '../domain/lifeStages.js';
import { RESPONSE_STATES, SOURCES } from '../utils/apiResponse.js';

/**
 * Condition profile (spec §14 "HORMONAL HEALTH FUNCTIONAL REQUIREMENTS").
 *
 * Conditions are only ever those the user explicitly selected or reported as
 * diagnosed - nothing here infers a diagnosis from logs. Insights linked to a
 * condition come from the same deterministic pattern engine as everywhere else
 * and describe the user's own symptom, sleep, mood and pain observations.
 *
 * Hormone levels are deliberately not modelled: the spec forbids displaying
 * estimated estrogen, progesterone or testosterone without validated lab or
 * device data, which Blushy does not ingest.
 */

const CONDITION_CONTRACT_VERSION = 'conditions-v1.0.0';

/**
 * Conditions the app can attach reviewed education to. A condition outside this
 * list is still stored and shown - the user's own report is authoritative -
 * it simply has no linked content yet.
 */
const CONDITION_TOPICS = Object.freeze({
  pcos: 'pcos',
  endometriosis: 'endometriosis',
  pmdd: 'pmdd',
  'thyroid condition': 'thyroid',
  fibroids: 'fibroids',
  adenomyosis: 'adenomyosis',
});

function topicFor(condition) {
  return CONDITION_TOPICS[String(condition).trim().toLowerCase()] ?? null;
}

/**
 * The conditions the user has reported, newest report wins.
 *
 * Module-internal: the read model below is the public surface. It was exported
 * with no importer, which reads like an endpoint that was never wired up when
 * it is only a helper.
 */
async function getReportedConditions(userId) {
  const events = await listEvents(userId, { eventTypes: ['condition_reported'], limit: 50 });
  if (events.length === 0) return { conditions: [], reportedAt: null, diagnosedBy: null };

  const latest = events[0];
  const conditions = (latest.payload?.conditions ?? [])
    .map((c) => String(c).trim())
    .filter((c) => c.length > 0 && c.toLowerCase() !== 'not diagnosed');

  return {
    conditions,
    reportedAt: latest.timestamp,
    diagnosedBy: latest.payload?.diagnosedBy ?? 'self_reported',
    eventId: latest.eventId,
  };
}

export async function recordConditions(userId, { conditions, diagnosedBy = 'self_reported' }) {
  const result = await createEvent(userId, {
    eventType: 'condition_reported',
    payload: { conditions, diagnosedBy },
    source: 'manual',
  });

  if (!result.ok) {
    return { ok: false, error: result.error, field: result.field };
  }
  return { ok: true, event: result.event };
}

/**
 * The condition profile read model: what the user reported, the reviewed
 * education that matches it, and the observations drawn from their own logs.
 */
export async function getConditionProfile(userId) {
  const stageState = await getLifeStageState(userId);
  const lifeStage = normalizeLifeStage(stageState.lifeStage, null);

  const reported = await getReportedConditions(userId);

  if (reported.conditions.length === 0) {
    return {
      state: RESPONSE_STATES.EMPTY,
      version: CONDITION_CONTRACT_VERSION,
      source: SOURCES.MANUAL,
      data: {
        lifeStage,
        conditions: [],
        // Stated explicitly so the absence reads as "not reported" rather than
        // "none present": Blushy never infers a diagnosis.
        inferredFromLogs: false,
        message: 'Add any conditions you have been diagnosed with to see related information here.',
        hormoneLevelsSupported: false,
      },
    };
  }

  // Reviewed education for each reported condition, where it exists.
  const conditionBlocks = [];
  for (const condition of reported.conditions) {
    const topic = topicFor(condition);
    const content = topic
      ? await listContent({ topic, audience: 'female_user', approvedOnly: true, limit: 3 })
      : [];

    conditionBlocks.push({
      condition,
      topic,
      // A condition with no linked article is not a gap in the user's record.
      content,
      contentAvailable: content.length > 0,
    });
  }

  // Observations come from the same engine as Patterns; nothing here is
  // condition-specific inference.
  const insights = await listInsights(userId, { limit: 5 });

  return {
    state: RESPONSE_STATES.READY,
    version: CONDITION_CONTRACT_VERSION,
    source: SOURCES.MANUAL,
    data: {
      lifeStage,
      conditions: conditionBlocks,
      reportedAt: reported.reportedAt,
      diagnosedBy: reported.diagnosedBy,
      // Every condition here was chosen by the user (spec §14).
      inferredFromLogs: false,
      observations: insights.map((insight) => ({
        id: insight.id,
        title: insight.title,
        description: insight.description,
        strength: insight.strength,
        confidence: insight.confidence,
        sourceEventIds: insight.sourceEventIds,
        generatedAt: insight.generatedAt,
      })),
      observationsSource: 'rule',
      // Blushy ingests no validated lab or device data, so it shows no
      // estimated hormone levels (spec §14).
      hormoneLevelsSupported: false,
      disclaimer: 'Based on the conditions you told Blushy about and the patterns in your own logs. ' +
        'Blushy does not diagnose conditions or estimate hormone levels.',
    },
  };
}
