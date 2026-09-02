import { getHomeModules, normalizeLifeStage, getBranchCapabilities, LIFE_STAGE_CONFIG_VERSION } from '../domain/lifeStages.js';
import { envelope, RESPONSE_STATES, SOURCES } from '../utils/apiResponse.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { listEvents } from '../repositories/healthEventRepository.js';
import { listContent } from '../repositories/medicalContentRepository.js';
import { getReflection } from '../repositories/reflectionRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { getCycleState } from './cycleService.js';
import { getPatterns } from './insightService.js';
import { getCarePlan } from './carePlanService.js';
import { getPregnancyModule, getPostpartumModule, getFertilityModule } from './stageModuleService.js';
import { evaluateUserSafety, buildSafetyFlow } from './safetyService.js';
import { buildTimeline } from './timelineService.js';

/**
 * Home read model (spec §5 "HOME SCREEN FUNCTIONAL CONTRACT", §29 API contract:
 * "Use read models optimized for Home").
 *
 * The backend returns module data, not UI. Each module carries its own state so
 * one failing module never breaks the whole screen, and the ordering comes from
 * the life stage config so the backend can re-prioritise without a frontend
 * change.
 */

const HOME_CONTRACT_VERSION = 'home-v1.0.0';

function timeContext(date = new Date(), timezone = null) {
  let hour;
  try {
    hour = Number(new Intl.DateTimeFormat('en-GB', { timeZone: timezone ?? 'UTC', hour: '2-digit', hour12: false }).format(date));
  } catch {
    hour = date.getUTCHours();
  }
  if (hour < 5) return 'night';
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  if (hour < 22) return 'evening';
  return 'night';
}

function periodKeyFor(date = new Date()) {
  return date.toISOString().slice(0, 7);
}

/**
 * Each builder returns a contract envelope. Failures are contained so the rest
 * of Home still renders (spec §4 "Error ... retry without breaking the whole
 * Home screen").
 */
async function safely(builder) {
  try {
    return await builder();
  } catch (error) {
    console.error('[home] module failed:', error.message);
    return envelope(null, {
      state: RESPONSE_STATES.ERROR,
      errorCode: 'MODULE_UNAVAILABLE',
    });
  }
}

export async function getHome(userId, { referenceDate = new Date(), timezone = null, userSelectedMode = null } = {}) {
  const [stageState, user] = await Promise.all([
    getLifeStageState(userId),
    userRepository.getUserById(typeof userId === 'string' ? userId.replace(/^user:/, '') : userId),
  ]);

  const lifeStage = normalizeLifeStage(stageState.lifeStage, null);
  const capabilities = getBranchCapabilities(lifeStage);
  const effectiveTimezone = timezone ?? stageState.timezone ?? user?.onboardingAnswers?.timezone ?? null;

  // Onboarding is not complete until a life journey has been chosen; Home says
  // so explicitly rather than guessing a branch.
  if (!lifeStage) {
    return {
      state: RESPONSE_STATES.EMPTY,
      version: HOME_CONTRACT_VERSION,
      data: {
        lifeStage: null,
        onboardingRequired: true,
        modules: [],
      },
    };
  }

  const safety = await evaluateUserSafety(userId, { surface: 'home' });
  const moduleOrder = getHomeModules(lifeStage);
  const modules = {};

  const preferredName = user?.onboardingAnswers?.preferred_name ?? user?.displayName ?? null;

  for (const { moduleId, order } of moduleOrder) {
    modules[moduleId] = { order, data: null };
  }

  const assign = (moduleId, contract) => {
    if (!modules[moduleId]) return;
    modules[moduleId] = { ...modules[moduleId], ...contract };
  };

  // ---- Greeting ----
  assign('greeting', envelope(
    { preferredName, timeContext: timeContext(referenceDate, effectiveTimezone), timezone: effectiveTimezone },
    { state: preferredName ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY, source: SOURCES.MANUAL, version: HOME_CONTRACT_VERSION },
  ));

  // ---- Today's context ----
  assign('today_context', envelope(
    {
      lifeStage,
      capabilities,
      date: referenceDate.toISOString().slice(0, 10),
      branchContext: stageState.branchContext ?? {},
      configVersion: LIFE_STAGE_CONFIG_VERSION,
    },
    { state: RESPONSE_STATES.READY, source: SOURCES.RULE, version: LIFE_STAGE_CONFIG_VERSION },
  ));

  // ---- Safety banner (only present when a rule actually fired) ----
  if (modules.safety_banner || safety.triggered) {
    const flow = await safely(() => buildSafetyFlow(safety));
    assign('safety_banner', envelope(flow.data, {
      state: flow.state === 'ready' ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
      source: SOURCES.MEDICAL_REFERENCE,
      version: safety.rulesetVersion,
    }));
    if (safety.triggered && !modules.safety_banner) {
      modules.safety_banner = { order: -1, ...envelope(flow.data, {
        state: RESPONSE_STATES.READY,
        source: SOURCES.MEDICAL_REFERENCE,
        version: safety.rulesetVersion,
      }) };
    }
  }

  // ---- Hero tracker (cycle) ----
  if (modules.hero_tracker) {
    const cycle = await safely(() => getCycleState(userId, { timezone: effectiveTimezone, referenceDate: referenceDate.toISOString().slice(0, 10) }));
    assign('hero_tracker', envelope(cycle.data, {
      state: cycle.state,
      source: cycle.source ?? SOURCES.RULE,
      version: cycle.version,
      lastUpdated: cycle.lastUpdated,
    }));
  }

  // ---- Pregnancy / postpartum / fertility trackers ----
  if (modules.pregnancy_tracker || modules.milestones) {
    const pregnancy = await safely(() => getPregnancyModule(userId, { referenceDate }));
    assign('pregnancy_tracker', envelope(pregnancy.data, { state: pregnancy.state, source: pregnancy.source, version: pregnancy.version, errorCode: pregnancy.errorCode ?? null }));
    assign('milestones', envelope(pregnancy.data?.milestones ?? null, { state: pregnancy.state, source: SOURCES.MEDICAL_REFERENCE, version: pregnancy.version }));
  }

  if (modules.postpartum_tracker || modules.recovery_milestones || modules.screening_checkpoint) {
    const postpartum = await safely(() => getPostpartumModule(userId, { referenceDate }));
    assign('postpartum_tracker', envelope(postpartum.data, { state: postpartum.state, source: postpartum.source, version: postpartum.version, errorCode: postpartum.errorCode ?? null }));
    assign('recovery_milestones', envelope(postpartum.data?.milestones ?? null, { state: postpartum.state, source: SOURCES.MEDICAL_REFERENCE, version: postpartum.version }));
    assign('screening_checkpoint', envelope(postpartum.data?.screening ?? null, { state: postpartum.state, source: SOURCES.MEDICAL_REFERENCE, version: postpartum.version }));
  }

  if (modules.fertility_indicators) {
    const fertility = await safely(() => getFertilityModule(userId, { referenceDate }));
    assign('fertility_indicators', envelope(fertility.data, { state: fertility.state, source: fertility.source, version: fertility.version }));
  }

  // ---- Patterns ----
  if (modules.patterns) {
    const patterns = await safely(() => getPatterns(userId, { limit: 5 }));
    assign('patterns', envelope(patterns.data, {
      state: patterns.state,
      source: patterns.source ?? SOURCES.RULE,
      version: patterns.version,
      errorCode: patterns.state === RESPONSE_STATES.INSUFFICIENT_DATA ? 'INSUFFICIENT_DATA' : null,
    }));
  }

  // ---- Docsy note (structured insight card) ----
  if (modules.sia_note) {
    const patterns = await safely(() => getPatterns(userId, { limit: 1 }));
    const top = Array.isArray(patterns.data) && patterns.data.length > 0 ? patterns.data[0] : null;
    assign('sia_note', envelope(
      // Suppressed entirely while a safety escalation is active (spec §15).
      safety.suppressWellnessContent ? null : top,
      {
        state: safety.suppressWellnessContent
          ? RESPONSE_STATES.RESTRICTED
          : (top ? RESPONSE_STATES.READY : RESPONSE_STATES.INSUFFICIENT_DATA),
        source: top?.source ?? SOURCES.RULE,
        version: top?.engineVersion ?? patterns.version,
        errorCode: safety.suppressWellnessContent ? 'SAFETY_SUPPRESSED' : null,
      },
    ));
  }

  // ---- Care plan ----
  if (modules.care_plan) {
    const carePlan = await safely(() => getCarePlan(userId, { referenceDate, userSelectedMode }));
    assign('care_plan', envelope(carePlan.data, { state: carePlan.state, source: carePlan.source, version: carePlan.version }));
  }

  // ---- Timeline ----
  if (modules.timeline) {
    const timeline = await safely(() => buildTimeline(userId, { limit: 20 }));
    assign('timeline', envelope(timeline.data, { state: timeline.state, source: SOURCES.MANUAL, version: timeline.version }));
  }

  // ---- Reflection ----
  if (modules.reflection) {
    const key = periodKeyFor(referenceDate);
    const reflection = await safely(() => getReflection(userId, key));
    assign('reflection', envelope(
      { periodKey: key, reflection: reflection ?? null },
      { state: reflection ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY, source: SOURCES.MANUAL, version: HOME_CONTRACT_VERSION },
    ));
  }

  // ---- Education / preventive / experiments (content driven) ----
  for (const [moduleId, topic] of [
    ['education_checklist', null],
    ['preventive_care', 'preventive_care'],
    ['guided_experiments', 'guided_experiments'],
    ['condition_profile', 'conditions'],
    ['wellness_tracker', null],
    ['symptom_tracker', null],
  ]) {
    if (!modules[moduleId]) continue;

    if (moduleId === 'wellness_tracker' || moduleId === 'symptom_tracker') {
      const recent = await safely(() => listEvents(userId, {
        eventTypes: ['mood_logged', 'energy_logged', 'sleep_logged', 'symptom_logged', 'hot_flash_logged', 'hydration_logged', 'stress_logged'],
        limit: 30,
      }));
      const rows = Array.isArray(recent) ? recent : [];
      assign(moduleId, envelope(rows, {
        state: rows.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
        source: SOURCES.MANUAL,
        version: HOME_CONTRACT_VERSION,
      }));
      continue;
    }

    const content = await safely(() => listContent({
      lifeStage,
      topic,
      audience: 'female_user',
      limit: 5,
    }));
    const rows = Array.isArray(content) ? content : [];
    assign(moduleId, envelope(rows, {
      state: rows.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
      source: SOURCES.MEDICAL_REFERENCE,
      version: HOME_CONTRACT_VERSION,
    }));
  }

  // ---- Quick actions ----
  const quickActions = buildQuickActions(lifeStage, capabilities);
  assign('quick_actions', envelope(quickActions, { state: RESPONSE_STATES.READY, source: SOURCES.RULE, version: HOME_CONTRACT_VERSION }));

  const ordered = Object.entries(modules)
    .map(([moduleId, value]) => ({ moduleId, ...value }))
    .sort((a, b) => a.order - b.order);

  return {
    state: RESPONSE_STATES.READY,
    version: HOME_CONTRACT_VERSION,
    data: {
      lifeStage,
      capabilities,
      onboardingRequired: false,
      safetyActive: safety.triggered,
      adaptiveModeHint: safety.suppressWellnessContent ? 'safety' : null,
      modules: ordered,
    },
  };
}

/**
 * Quick actions map one-to-one onto event types, so every button on Home has a
 * defined backend action (spec §32 "Every interactive button has a defined
 * backend action").
 */
function buildQuickActions(lifeStage, capabilities) {
  const actions = [
    { actionId: 'log_mood', label: 'Log mood', eventType: 'mood_logged' },
    { actionId: 'log_energy', label: 'Log energy', eventType: 'energy_logged' },
    { actionId: 'log_sleep', label: 'Log sleep', eventType: 'sleep_logged' },
    { actionId: 'log_symptom', label: 'Log symptom', eventType: 'symptom_logged' },
    { actionId: 'write_journal', label: 'Journal', eventType: 'journal_created' },
  ];

  if (capabilities.cycleTracking) {
    actions.unshift({ actionId: 'log_period', label: 'Log period', eventType: 'period_logged' });
  }
  if (capabilities.fertility) {
    actions.push(
      { actionId: 'log_bbt', label: 'Log BBT', eventType: 'bbt_logged' },
      { actionId: 'log_lh', label: 'Log LH test', eventType: 'lh_test_logged' },
    );
  }
  if (capabilities.postpartum) {
    actions.push(
      { actionId: 'log_feeding', label: 'Log feeding', eventType: 'feeding_logged' },
      { actionId: 'log_recovery', label: 'Log recovery', eventType: 'recovery_metric_logged' },
    );
  }
  if (lifeStage === 'perimenopause' || lifeStage === 'menopause') {
    actions.push({ actionId: 'log_hot_flash', label: 'Log hot flash', eventType: 'hot_flash_logged' });
  }

  return actions;
}
