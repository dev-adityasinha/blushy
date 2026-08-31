import {
  normalizePermissions,
  sanitizePermissionPatch,
  buildPartnerSafeContext,
  filterSharedInsights,
  describeSharingState,
  isConnectionActive,
  normalizeConnectionState,
  hasGrant,
  PERMISSION_MATRIX_VERSION,
  PERMISSION_KEYS,
  PERMISSIONS,
} from '../domain/partnerPermissions.js';
import { normalizeLifeStage, getBranchCapabilities } from '../domain/lifeStages.js';
import { calculatePregnancyState, getMilestones } from '../domain/pregnancy.js';
import { calculatePostpartumState, getRecoveryMilestones } from '../domain/postpartum.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { listEvents } from '../repositories/healthEventRepository.js';
import { listInsights } from '../repositories/insightRepository.js';
import { listSupportRequests } from '../repositories/supportRequestRepository.js';
import { recordPermissionChange, recordAnalyticsEvent } from '../repositories/auditRepository.js';
import { cancelByCategory, scheduleNotification } from '../repositories/notificationRepository.js';
import {
  REQUEST_STATES,
  findPendingRequest,
  createRequest,
  getRequest,
  listRequests,
  resolveRequest,
} from '../repositories/partnerPermissionRequestRepository.js';
import { journalRepository } from '../repositories/journalRepository.js';
import { aiHistoryRepository } from '../repositories/aiHistoryRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { getCycleState } from './cycleService.js';
import { RESPONSE_STATES, SOURCES } from '../utils/apiResponse.js';
import { db } from '../utils/db.js';

/**
 * Partner-safe data layer (spec §9, §10, §19-§21, §25, §30 example flow).
 *
 * Every partner-facing read goes through here. The permission filter is
 * server-side and runs before any AI context is built, so unpermitted data
 * never reaches the partner app or a prompt.
 */

const PARTNER_CONTRACT_VERSION = 'partner-safe-v1.0.0';
const CONNECTIONS = 'partner_connections';

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

/**
 * Loads a connection and verifies the caller is part of it. Returns the woman's
 * user id (the data subject) and the current permissions.
 */
export async function authorizeConnection(connectionId, viewerUserId) {
  const uid = cleanUserId(viewerUserId);
  const row = await db.collection(CONNECTIONS).findOne({ connection_id: connectionId });

  if (!row) {
    return { ok: false, errorCode: 'NOT_FOUND' };
  }
  if (row.user_a_id !== uid && row.user_b_id !== uid) {
    // Same response as a missing connection: an outsider learns nothing about
    // whether the id exists (spec §28 IDOR protection).
    return { ok: false, errorCode: 'NOT_FOUND' };
  }

  const connectionState = normalizeConnectionState(row.status);
  const permissions = normalizePermissions(row.permissions ?? {});

  // The data subject is whoever owns the permissions - the woman. Existing rows
  // always carry permission_owner_user_id; the fallback covers legacy rows
  // written before that column existed.
  let subjectUserId = row.permission_owner_user_id ?? null;
  if (!subjectUserId) {
    const userA = await userRepository.getUserById(row.user_a_id);
    subjectUserId = userA?.role === 'woman' ? row.user_a_id : row.user_b_id;
  }
  const partnerUserId = subjectUserId === row.user_a_id ? row.user_b_id : row.user_a_id;

  return {
    ok: true,
    connectionId,
    connectionState,
    active: isConnectionActive(row.status),
    permissions,
    subjectUserId,
    partnerUserId,
    viewerIsSubject: uid === subjectUserId,
    viewerIsPartner: uid === partnerUserId,
    relationshipType: row.relationship_type ?? null,
    rawStatus: row.status,
  };
}

/**
 * Assembles the woman's full context, then filters it. The unfiltered object
 * never leaves this function.
 */
async function buildSubjectContext(subjectUserId, { referenceDate = new Date() } = {}) {
  const [stageState, user] = await Promise.all([
    getLifeStageState(subjectUserId),
    userRepository.getUserById(cleanUserId(subjectUserId)),
  ]);

  const lifeStage = normalizeLifeStage(stageState.lifeStage, null);
  const capabilities = getBranchCapabilities(lifeStage);
  const branchContext = stageState.branchContext ?? {};

  const context = {
    preferredName: user?.onboardingAnswers?.preferred_name ?? user?.displayName ?? null,
    lifeStage,
    relationshipType: null,
  };

  const recent = await listEvents(subjectUserId, {
    eventTypes: ['mood_logged', 'energy_logged', 'sleep_logged', 'symptom_logged', 'appointment_logged'],
    from: new Date(referenceDate.getTime() - 7 * 86400000).toISOString(),
    limit: 100,
  });

  const latestOf = (type) => recent.find((event) => event.eventType === type) ?? null;

  const mood = latestOf('mood_logged');
  if (mood) context.mood = { value: mood.payload?.mood, loggedAt: mood.timestamp };

  const energy = latestOf('energy_logged');
  if (energy) context.energyLevel = { value: energy.payload?.level, scale: '1_5', loggedAt: energy.timestamp };

  const sleep = latestOf('sleep_logged');
  if (sleep) context.sleep = { durationHours: sleep.payload?.durationHours, quality: sleep.payload?.quality, loggedAt: sleep.timestamp };

  const symptoms = recent.filter((event) => event.eventType === 'symptom_logged').slice(0, 5);
  if (symptoms.length > 0) {
    context.symptoms = symptoms.map((event) => ({ symptom: event.payload?.symptom, loggedAt: event.timestamp }));
  }

  const appointments = recent.filter((event) => event.eventType === 'appointment_logged').slice(0, 5);
  if (appointments.length > 0) {
    context.appointments = appointments.map((event) => ({
      title: event.payload?.title,
      date: event.payload?.date,
      time: event.payload?.time ?? null,
    }));
  }

  if (capabilities.cyclePredictions || capabilities.cycleTracking) {
    const cycle = await getCycleState(subjectUserId, { referenceDate: referenceDate.toISOString().slice(0, 10) });
    if (cycle.state === RESPONSE_STATES.READY) {
      context.cyclePhase = { phase: cycle.data.currentCycle?.phase, cycleDay: cycle.data.currentCycle?.currentCycleDay };
      if (cycle.data.prediction?.nextPeriodStartDate) {
        context.nextPeriodWindow = {
          earliest: cycle.data.prediction.predictionRange?.earliestDate ?? cycle.data.prediction.nextPeriodStartDate,
          latest: cycle.data.prediction.predictionRange?.latestDate ?? cycle.data.prediction.nextPeriodStartDate,
          isEstimate: true,
        };
      }
      if (capabilities.fertility && cycle.data.prediction?.fertileWindowStart) {
        context.fertileWindow = {
          start: cycle.data.prediction.fertileWindowStart,
          end: cycle.data.prediction.fertileWindowEnd,
          isEstimate: true,
        };
      }
    }
  }

  if (capabilities.pregnancy && !stageState.pregnancyContentBlocked) {
    const pregnancy = calculatePregnancyState({
      dueDate: branchContext.due_date,
      lmpDate: branchContext.lmp_date,
      week: branchContext.pregnancy_week,
      weekRecordedOn: branchContext.pregnancy_week_recorded_on,
      referenceDate,
    });
    if (pregnancy.state === 'ready') {
      context.pregnancyWeek = { week: pregnancy.gestationalWeek, trimester: pregnancy.trimester, dueDate: pregnancy.dueDate };
      const milestones = getMilestones(pregnancy.gestationalWeek);
      if (milestones.current) {
        context.pregnancyMilestone = { id: milestones.current.id, title: milestones.current.title, week: milestones.current.week };
      }
    }
  }

  if (capabilities.postpartum) {
    const postpartum = calculatePostpartumState({ birthDate: branchContext.baby_birth_date, referenceDate });
    if (postpartum.state === 'ready') {
      const milestones = getRecoveryMilestones(postpartum.daysSinceBirth);
      if (milestones.current) {
        context.postpartumMilestone = {
          id: milestones.current.id,
          title: milestones.current.title,
          weeksSinceBirth: postpartum.weeksSinceBirth,
        };
      }
    }
  }

  const insights = await listInsights(subjectUserId, { limit: 5 });
  if (insights.length > 0) {
    context.generalInsights = insights.map((insight) => ({
      id: insight.id,
      title: insight.title,
      description: insight.description,
      generatedAt: insight.generatedAt,
      confidence: insight.confidence,
    }));
  }

  return context;
}

/**
 * Partner-safe context. This is what Partner Dr. Docsy receives - nothing more.
 */
export async function getPartnerSafeContext(connectionId, viewerUserId, { referenceDate = new Date() } = {}) {
  const auth = await authorizeConnection(connectionId, viewerUserId);
  if (!auth.ok) return { ok: false, errorCode: auth.errorCode };

  if (!auth.active) {
    return {
      ok: true,
      state: RESPONSE_STATES.RESTRICTED,
      version: PERMISSION_MATRIX_VERSION,
      data: { relationshipActive: false, connectionState: auth.connectionState },
      errorCode: 'RELATIONSHIP_INACTIVE',
    };
  }

  const fullContext = await buildSubjectContext(auth.subjectUserId, { referenceDate });
  fullContext.relationshipType = auth.relationshipType;

  const filtered = buildPartnerSafeContext(fullContext, auth.permissions, { connectionState: auth.connectionState });

  return {
    ok: true,
    state: filtered.state === 'ready' ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: filtered.matrixVersion,
    source: SOURCES.RULE,
    permissions: {
      allowedGrants: filtered.allowedGrants,
      restrictedGrants: filtered.restrictedGrants,
    },
    data: filtered.context,
  };
}

/**
 * The "Us" page (spec §21). Only explicitly shared objects - the partner never
 * queries the woman's raw records.
 */
export async function getSharedSurface(connectionId, viewerUserId, { referenceDate = new Date() } = {}) {
  const auth = await authorizeConnection(connectionId, viewerUserId);
  if (!auth.ok) return { ok: false, errorCode: auth.errorCode };

  if (!auth.active) {
    return {
      ok: true,
      state: RESPONSE_STATES.RESTRICTED,
      version: PARTNER_CONTRACT_VERSION,
      data: null,
      errorCode: 'RELATIONSHIP_INACTIVE',
    };
  }

  const contextResult = await getPartnerSafeContext(connectionId, viewerUserId, { referenceDate });
  const context = contextResult.data ?? {};
  const perms = auth.permissions;

  const supportRequests = await listSupportRequests({
    connectionId,
    viewerUserId,
    viewerRole: auth.viewerIsPartner ? 'partner' : 'requester',
    states: ['pending', 'acknowledged'],
    limit: 10,
  });

  // Journal days and Dr. Docsy exchanges reach a partner only when both the category
  // permission is on AND that specific item was marked shared. The grants
  // existed in the permission matrix from the start but nothing ever served
  // them, so turning either category on delivered nothing at all.
  const subjectUserId = auth.subjectUserId ?? auth.permissionOwnerUserId ?? null;

  const sharedJournals = hasGrant(perms, 'journal.entry') && subjectUserId
    ? await journalRepository.listSharedJournals(subjectUserId, 10).catch(() => [])
    : [];

  const sharedConversations = hasGrant(perms, 'sia.conversation') && subjectUserId
    ? await aiHistoryRepository.listSharedConversations(subjectUserId, 10).catch(() => [])
    : [];

  const sharedInsights = filterSharedInsights(
    (context.generalInsights ?? []).map((insight) => ({ ...insight, requiredGrants: ['insight.general'] })),
    perms,
    { connectionState: auth.connectionState },
  );

  const sections = [
    { key: 'shared_insights', enabled: hasGrant(perms, 'insight.general'), items: sharedInsights },
    { key: 'cycle_context', enabled: hasGrant(perms, 'cycle.phase'), items: context.cyclePhase ? [context.cyclePhase] : [] },
    { key: 'fertility_context', enabled: hasGrant(perms, 'fertility.window'), items: context.fertileWindow ? [context.fertileWindow] : [] },
    { key: 'pregnancy_milestones', enabled: hasGrant(perms, 'pregnancy.milestone'), items: context.pregnancyMilestone ? [context.pregnancyMilestone] : [] },
    { key: 'postpartum_milestones', enabled: hasGrant(perms, 'postpartum.milestone'), items: context.postpartumMilestone ? [context.postpartumMilestone] : [] },
    { key: 'appointments', enabled: hasGrant(perms, 'appointment.summary'), items: context.appointments ?? [] },
    { key: 'care_requests', enabled: true, items: supportRequests },
    { key: 'shared_journal', enabled: hasGrant(perms, 'journal.entry'), items: sharedJournals },
    { key: 'shared_sia_conversations', enabled: hasGrant(perms, 'sia.conversation'), items: sharedConversations },
  ];

  const populated = sections.filter((section) => section.enabled && section.items.length > 0);

  return {
    ok: true,
    // Empty is a real, designed state here (spec §21 "Nothing shared empty
    // state"), not an error.
    state: populated.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: PARTNER_CONTRACT_VERSION,
    source: SOURCES.RULE,
    permissions: { allowedGrants: contextResult.permissions?.allowedGrants ?? [] },
    data: {
      sections,
      nothingShared: populated.length === 0,
      partnerPreferredName: context.partnerPreferredName ?? null,
      lifeStage: context.lifeStage ?? null,
    },
  };
}

/**
 * Partner Home read model (spec §19 partner functional contract).
 */
export async function getPartnerHome(connectionId, viewerUserId, { referenceDate = new Date() } = {}) {
  const auth = await authorizeConnection(connectionId, viewerUserId);
  if (!auth.ok) return { ok: false, errorCode: auth.errorCode };
  if (!auth.viewerIsPartner) return { ok: false, errorCode: 'FORBIDDEN' };

  const contextResult = await getPartnerSafeContext(connectionId, viewerUserId, { referenceDate });
  const shared = await getSharedSurface(connectionId, viewerUserId, { referenceDate });

  const supportRequests = await listSupportRequests({
    connectionId,
    viewerUserId,
    viewerRole: 'partner',
    states: ['pending', 'acknowledged'],
    limit: 10,
  });

  return {
    ok: true,
    state: RESPONSE_STATES.READY,
    version: PARTNER_CONTRACT_VERSION,
    source: SOURCES.RULE,
    data: {
      greeting: {
        // Partner Home always works, with or without shared data.
        prompt: 'How can I show up today?',
        partnerPreferredName: contextResult.data?.partnerPreferredName ?? null,
      },
      lifeStageContext: contextResult.data?.lifeStage ?? null,
      permittedContext: contextResult.data ?? {},
      allowedGrants: contextResult.permissions?.allowedGrants ?? [],
      supportRequests,
      sharedSections: shared.data?.sections ?? [],
      nothingShared: shared.data?.nothingShared ?? true,
      relationshipActive: auth.active,
    },
  };
}

/**
 * Permission update. Only the woman (the permission owner) may change these,
 * changes are audited, and revocation immediately cancels partner-facing
 * notifications in the affected categories.
 */
export async function updatePermissions(connectionId, actorUserId, patch) {
  const auth = await authorizeConnection(connectionId, actorUserId);
  if (!auth.ok) return { ok: false, errorCode: auth.errorCode };

  if (!auth.viewerIsSubject) {
    return { ok: false, errorCode: 'FORBIDDEN', message: 'Only the person sharing can change these permissions.' };
  }

  const { clean, rejected } = sanitizePermissionPatch(patch);
  if (Object.keys(clean).length === 0) {
    return { ok: false, errorCode: 'VALIDATION_FAILED', message: 'No valid permission keys supplied.', rejected };
  }

  const previous = auth.permissions;
  const next = { ...previous, ...clean };

  await db.collection(CONNECTIONS).updateOne(
    { connection_id: connectionId },
    { $set: { permissions: next, permissions_version: PERMISSION_MATRIX_VERSION, updated_at: new Date() } },
  );

  const changes = {};
  for (const key of Object.keys(clean)) {
    if (previous[key] !== next[key]) changes[key] = { from: previous[key], to: next[key] };
  }

  await recordPermissionChange({
    connectionId,
    actorUserId,
    subjectUserId: auth.subjectUserId,
    changes,
    previous,
    next,
  });

  // Revoking a category stops the partner receiving its notifications straight
  // away (spec §10 "Revocation removes data from partner API responses and
  // partner caches").
  const revoked = Object.entries(changes).filter(([, value]) => value.from === true && value.to === false).map(([key]) => key);
  if (revoked.length > 0) {
    await cancelByCategory(auth.partnerUserId, 'partner_shared_update', 'permission_revoked');
  }

  for (const key of Object.keys(changes)) {
    await recordAnalyticsEvent({
      userId: actorUserId,
      pseudonymousId: null,
      eventName: 'permission_changed',
      properties: { permissionKey: key, enabled: next[key] },
    });
  }

  return {
    ok: true,
    permissions: next,
    changes,
    rejected,
    revoked,
    matrixVersion: PERMISSION_MATRIX_VERSION,
    sharingState: describeSharingState(next),
  };
}

/**
 * What the woman sees on her "what am I sharing" screen (spec §10).
 */
export async function getSharingState(connectionId, actorUserId) {
  const auth = await authorizeConnection(connectionId, actorUserId);
  if (!auth.ok) return { ok: false, errorCode: auth.errorCode };
  if (!auth.viewerIsSubject) return { ok: false, errorCode: 'FORBIDDEN' };

  return {
    ok: true,
    state: RESPONSE_STATES.READY,
    version: PERMISSION_MATRIX_VERSION,
    data: {
      connectionId,
      connectionState: auth.connectionState,
      permissions: describeSharingState(auth.permissions),
      permissionKeys: PERMISSION_KEYS,
    },
  };
}

export { PERMISSION_MATRIX_VERSION };

/* ------------------------------------------------------------------ *
 * Asking to be shown something (spec section 10)
 * ------------------------------------------------------------------ */

/**
 * A partner asks for one permission that is currently off.
 *
 * Asking changes nothing. It records the request and notifies the person who
 * owns the permissions, who remains the only one who can turn anything on.
 */
export async function requestPermission(connectionId, requesterUserId, { permissionKey, message }) {
  const auth = await authorizeConnection(connectionId, requesterUserId);
  if (!auth.ok) return { ok: false, errorCode: auth.errorCode };

  if (!auth.active) {
    return { ok: false, errorCode: 'RELATIONSHIP_INACTIVE' };
  }

  // The owner already decides these directly; letting them "request" would be
  // a second, weaker way to change their own settings.
  if (auth.viewerIsSubject) {
    return {
      ok: false,
      errorCode: 'FORBIDDEN',
      message: 'These are your own settings. You can change them directly.',
    };
  }

  if (!PERMISSION_KEYS.includes(permissionKey)) {
    return { ok: false, errorCode: 'VALIDATION_FAILED', message: 'Unknown permission.' };
  }

  const definition = PERMISSIONS[permissionKey];
  if (definition.alwaysOn) {
    return { ok: false, errorCode: 'VALIDATION_FAILED', message: 'That is always on already.' };
  }

  if (auth.permissions[permissionKey] === true) {
    return { ok: false, errorCode: 'VALIDATION_FAILED', message: 'That is already shared with you.' };
  }

  // One live request per permission. Re-asking should not stack up notices for
  // the other person to work through.
  const existing = await findPendingRequest({ connectionId, permissionKey });
  if (existing) {
    return { ok: true, alreadyPending: true, request: existing };
  }

  const request = await createRequest({
    connectionId,
    requesterUserId,
    ownerUserId: auth.subjectUserId,
    permissionKey,
    message,
  });

  // Best effort: the request stands whether or not the notice is delivered,
  // and it is visible in the app either way.
  try {
    await scheduleNotification(auth.subjectUserId, {
      category: 'partner_permission_request',
      title: 'Your partner asked to see something',
      body: `They asked if you would share "${definition.label}". You choose.`,
      entityType: 'partner_permission_request',
      entityId: request.requestId,
      deepLink: `blushy://partner/sharing?connectionId=${connectionId}`,
      dedupeKey: `permreq:${connectionId}:${permissionKey}`,
    });
  } catch (_) {
    // Logged by the notification layer; never fails the request itself.
  }

  return { ok: true, request };
}

/**
 * The owner approves or declines. Approving is what turns the permission on,
 * so a request can never share anything by itself.
 */
export async function respondToPermissionRequest(requestId, actorUserId, { approve }) {
  const request = await getRequest(requestId);
  if (!request) return { ok: false, errorCode: 'NOT_FOUND' };

  const auth = await authorizeConnection(request.connectionId, actorUserId);
  if (!auth.ok) return { ok: false, errorCode: auth.errorCode };

  if (!auth.viewerIsSubject) {
    return {
      ok: false,
      errorCode: 'FORBIDDEN',
      message: 'Only the person sharing can answer this.',
    };
  }

  if (request.status !== REQUEST_STATES.PENDING) {
    return { ok: false, errorCode: 'VALIDATION_FAILED', message: 'That request has already been answered.' };
  }

  const resolved = await resolveRequest({
    requestId,
    nextState: approve ? REQUEST_STATES.APPROVED : REQUEST_STATES.DECLINED,
  });

  if (!resolved) {
    return { ok: false, errorCode: 'VALIDATION_FAILED', message: 'That request has already been answered.' };
  }

  // Only now does anything become shared, and through the same audited path as
  // any other permission change.
  if (approve) {
    const update = await updatePermissions(request.connectionId, actorUserId, {
      [request.permissionKey]: true,
    });
    if (!update.ok) {
      return { ok: false, errorCode: update.errorCode, message: update.message };
    }
  }

  const label = PERMISSIONS[request.permissionKey]?.label ?? request.permissionKey;
  try {
    await scheduleNotification(request.requesterUserId, {
      category: 'partner_permission_request',
      title: approve ? 'They shared something with you' : 'They answered your request',
      body: approve
        ? `"${label}" is now shared with you.`
        : `They would rather not share "${label}" right now.`,
      entityType: 'partner_permission_request',
      entityId: requestId,
      dedupeKey: `permreq_result:${requestId}`,
    });
  } catch (_) {
    // Same as above: the answer stands regardless.
  }

  return { ok: true, request: resolved };
}

/**
 * Both sides can see the requests on their connection: the owner to answer
 * them, the partner to see what they already asked for.
 */
export async function listPermissionRequests(connectionId, viewerUserId, { states = null } = {}) {
  const auth = await authorizeConnection(connectionId, viewerUserId);
  if (!auth.ok) return { ok: false, errorCode: auth.errorCode };

  const requests = await listRequests({ connectionId, states });
  return {
    ok: true,
    data: requests.map((request) => ({
      ...request,
      permissionLabel: PERMISSIONS[request.permissionKey]?.label ?? request.permissionKey,
      viewerIsOwner: auth.viewerIsSubject,
    })),
  };
}

/**
 * The partner takes back a request they no longer want answered.
 */
export async function withdrawPermissionRequest(requestId, actorUserId) {
  const request = await getRequest(requestId);
  if (!request) return { ok: false, errorCode: 'NOT_FOUND' };

  if (request.requesterUserId !== actorUserId) {
    return { ok: false, errorCode: 'FORBIDDEN', message: 'Only the person who asked can withdraw it.' };
  }

  const resolved = await resolveRequest({ requestId, nextState: REQUEST_STATES.WITHDRAWN });
  if (!resolved) {
    return { ok: false, errorCode: 'VALIDATION_FAILED', message: 'That request has already been answered.' };
  }

  return { ok: true, request: resolved };
}
