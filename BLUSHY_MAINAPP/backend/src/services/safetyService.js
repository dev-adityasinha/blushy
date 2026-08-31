import {
  evaluateRedFlags,
  getEmergencyResources,
  resolveRegion,
  applySafetyGate,
  RED_FLAG_RULES,
  RED_FLAG_RULESET_VERSION,
} from '../domain/safety.js';
import { normalizeLifeStage } from '../domain/lifeStages.js';
import { calculatePregnancyState } from '../domain/pregnancy.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { listEvents } from '../repositories/healthEventRepository.js';
import { getLatestScreening } from '../repositories/screeningRepository.js';
import { recordSafetyIncident, recordAnalyticsEvent } from '../repositories/auditRepository.js';
import { getContentBatch } from '../repositories/medicalContentRepository.js';

/**
 * Safety orchestration (spec §15, §16, §22, §26).
 *
 * Deterministic rules decide; the AI layer only ever receives the result. This
 * service is the single place that decides whether ordinary wellness content is
 * suppressed for a user right now.
 */

const RECENT_SYMPTOM_WINDOW_DAYS = 3;

/**
 * Evaluates the user's current safety state from stored events plus optional
 * inbound free text (a Dr. Docsy message or journal entry being written now).
 */
export async function evaluateUserSafety(userId, { freeText = '', surface = 'unknown' } = {}) {
  const stageState = await getLifeStageState(userId);
  const lifeStage = normalizeLifeStage(stageState.lifeStage, null);

  const since = new Date(Date.now() - RECENT_SYMPTOM_WINDOW_DAYS * 86400000).toISOString();
  const events = await listEvents(userId, {
    eventTypes: ['symptom_logged', 'pain_logged', 'mood_logged'],
    from: since,
    limit: 200,
  });

  const symptoms = events
    .filter((event) => event.eventType === 'symptom_logged')
    .map((event) => ({ symptom: event.payload?.symptom, severity: event.payload?.severity }));

  for (const event of events.filter((e) => e.eventType === 'pain_logged')) {
    symptoms.push({
      symptom: event.payload?.location ? `${event.payload.location} pain` : 'pain',
      severity: event.payload?.severity,
    });
    // Pain is also matched under the generic terms the rules use.
    symptoms.push({ symptom: 'severe cramps', severity: event.payload?.severity });
    symptoms.push({ symptom: 'abdominal pain', severity: event.payload?.severity });
    symptoms.push({ symptom: 'pelvic pain', severity: event.payload?.severity });
  }

  let gestationalWeek = null;
  if (lifeStage === 'pregnancy') {
    const context = stageState.branchContext ?? {};
    const pregnancy = calculatePregnancyState({
      dueDate: context.due_date,
      lmpDate: context.lmp_date,
      week: context.pregnancy_week,
      weekRecordedOn: context.pregnancy_week_recorded_on,
    });
    gestationalWeek = pregnancy.gestationalWeek;
  }

  const redFlags = evaluateRedFlags({ lifeStage, symptoms, freeText, gestationalWeek });

  // A concerning or crisis screening result also suppresses wellness content
  // (spec §16).
  let screeningSuppression = false;
  const latestEpds = await getLatestScreening(userId, 'EPDS');
  if (latestEpds?.requiresProfessionalSupport) {
    const ageDays = latestEpds.completedAt
      ? (Date.now() - new Date(latestEpds.completedAt).getTime()) / 86400000
      : Infinity;
    if (ageDays <= 14) screeningSuppression = true;
  }

  const region = resolveRegion({
    region: stageState.region,
    locale: stageState.locale,
    timezone: stageState.timezone,
  });
  const resources = getEmergencyResources(region);

  const result = {
    triggered: redFlags.triggered,
    level: redFlags.level,
    rules: redFlags.rules,
    suppressWellnessContent: redFlags.suppressWellnessContent || screeningSuppression,
    suppressionSources: [
      ...(redFlags.suppressWellnessContent ? ['red_flag'] : []),
      ...(screeningSuppression ? ['screening_result'] : []),
    ],
    rulesetVersion: redFlags.rulesetVersion,
    evaluatedAt: redFlags.evaluatedAt,
    region: resources.region,
    emergencyResources: resources,
    lifeStage,
  };

  if (redFlags.triggered) {
    await recordSafetyIncident(userId, {
      ruleIds: redFlags.rules.map((rule) => rule.ruleId),
      level: redFlags.level,
      rulesetVersion: redFlags.rulesetVersion,
      surface,
      suppressedWellness: result.suppressWellnessContent,
    });
    await recordAnalyticsEvent({
      userId,
      pseudonymousId: null,
      eventName: 'safety_escalation',
      properties: { level: redFlags.level, surface, lifeStage: lifeStage ?? 'unknown' },
    });
  }

  return result;
}

/**
 * Builds the full safety flow shown to the user when a red flag fires:
 * the reviewed instruction, the linked approved article and location-aware
 * resources.
 */
export async function buildSafetyFlow(safetyResult) {
  if (!safetyResult?.triggered) {
    return { state: 'empty', data: null };
  }

  const contentIds = safetyResult.rules.map((rule) => rule.contentId).filter(Boolean);
  const articles = await getContentBatch(contentIds, { approvedOnly: true });
  const articlesById = new Map(articles.map((article) => [article.contentId, article]));

  return {
    state: 'ready',
    data: {
      level: safetyResult.level,
      suppressWellnessContent: safetyResult.suppressWellnessContent,
      rulesetVersion: safetyResult.rulesetVersion,
      steps: safetyResult.rules.map((rule) => ({
        ruleId: rule.ruleId,
        title: rule.title,
        // The instruction is reviewed text held in the rule itself, so it is
        // available even when the content service is unreachable (spec §25).
        instruction: rule.instruction,
        level: rule.level,
        source: rule.source,
        reviewer: rule.reviewer,
        reviewDate: rule.reviewDate,
        ruleVersion: rule.ruleVersion,
        article: articlesById.get(rule.contentId) ?? null,
        articleAvailable: articlesById.has(rule.contentId),
      })),
      emergencyResources: safetyResult.emergencyResources,
      region: safetyResult.region,
    },
  };
}

/**
 * Final gate for any AI output. Never let generated text stand in front of a
 * live emergency escalation (spec §22).
 */
export function gateAiOutput(aiOutput, safetyResult) {
  return applySafetyGate({
    aiOutput,
    redFlagResult: safetyResult,
    emergencyResources: safetyResult?.emergencyResources ?? null,
  });
}

/**
 * Admin view of the ruleset (spec §27 "Red flag rule management/versioning").
 */
export function listRedFlagRules() {
  return {
    rulesetVersion: RED_FLAG_RULESET_VERSION,
    rules: RED_FLAG_RULES.map((rule) => ({
      id: rule.id,
      title: rule.title,
      lifeStages: rule.lifeStages,
      symptoms: rule.symptoms,
      minSeverity: rule.minSeverity ?? null,
      minGestationalWeek: rule.minGestationalWeek ?? null,
      level: rule.level,
      source: rule.source,
      reviewer: rule.reviewer,
      reviewDate: rule.reviewDate,
      version: rule.version,
      status: rule.status,
    })),
  };
}

export { getEmergencyResources, resolveRegion };
