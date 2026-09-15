import {
  authorizeConnection,
  getPartnerSafeContext,
  getSharedSurface,
  getPartnerHome,
  updatePermissions,
  getSharingState,
  PERMISSION_MATRIX_VERSION,
  requestPermission,
  respondToPermissionRequest,
  listPermissionRequests,
  withdrawPermissionRequest,
} from '../services/partnerSafeService.js';
import { PERMISSIONS, PERMISSION_KEYS, describeSharingState } from '../domain/partnerPermissions.js';
import {
  SUPPORT_REQUEST_TYPES,
  SUPPORT_REQUEST_STATES,
  validateSupportRequest,
} from '../domain/supportRequests.js';
import {
  createSupportRequest,
  listSupportRequests,
  transitionSupportRequest,
  revokeAllForConnection,
} from '../repositories/supportRequestRepository.js';
import { scheduleNotification } from '../repositories/notificationRepository.js';
import { getGarden, growGarden } from '../repositories/sharedGardenRepository.js';
import { partnerRepository } from '../repositories/partnerRepository.js';
import { publishToUsers } from '../utils/realtimeHub.js';
import { listPermissionAudit, recordAnalyticsEvent } from '../repositories/auditRepository.js';
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
 * Partner-safe API (spec §9, §10, §11, §19, §20, §21, §25, §30).
 *
 * Every endpoint here authorizes the relationship first, then applies the
 * permission filter server side. A revoked permission stops data flowing on the
 * very next request.
 */

function authError(res, errorCode) {
  if (errorCode === 'NOT_FOUND') {
    return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Connection not found.');
  }
  if (errorCode === 'FORBIDDEN') {
    return sendError(res, 403, ERROR_CODES.FORBIDDEN, 'You do not have access to this connection.');
  }
  return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'Request could not be processed.');
}

/* ------------------------------------------------------------------ *
 * Permission matrix
 * ------------------------------------------------------------------ */

export const getPermissionMatrix = contractHandler(async (_req, res) => {
  const matrix = PERMISSION_KEYS.map((key) => ({
    key,
    label: PERMISSIONS[key].label,
    example: PERMISSIONS[key].example,
    default: PERMISSIONS[key].default,
    alwaysOn: Boolean(PERMISSIONS[key].alwaysOn),
    grants: PERMISSIONS[key].grants,
  }));

  return sendData(res, matrix, {
    state: RESPONSE_STATES.READY,
    version: PERMISSION_MATRIX_VERSION,
    source: SOURCES.RULE,
  });
});

export const getMySharingState = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await getSharingState(req.params.connectionId, userId);
  if (!result.ok) return authError(res, result.errorCode);

  return sendData(res, result.data, { state: result.state, version: result.version, source: SOURCES.RULE });
});

export const patchPermissions = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await updatePermissions(req.params.connectionId, userId, req.body?.permissions ?? req.body ?? {});

  if (!result.ok) {
    if (result.errorCode === 'FORBIDDEN') {
      return sendError(res, 403, ERROR_CODES.FORBIDDEN, result.message ?? 'Only the person sharing can change these permissions.');
    }
    if (result.errorCode === 'NOT_FOUND') return authError(res, 'NOT_FOUND');
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.message ?? 'Invalid permission update.', { rejected: result.rejected });
  }

  return sendData(res, {
    permissions: result.permissions,
    changes: result.changes,
    revoked: result.revoked,
    sharingState: result.sharingState,
  }, {
    state: RESPONSE_STATES.READY,
    version: result.matrixVersion,
    source: SOURCES.MANUAL,
    permissions: { rejectedKeys: result.rejected },
  });
});

export const getPermissionHistory = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const auth = await authorizeConnection(req.params.connectionId, userId);
  if (!auth.ok) return authError(res, auth.errorCode);
  // Only the person whose data it is may read the sharing audit trail.
  if (!auth.viewerIsSubject) return sendError(res, 403, ERROR_CODES.FORBIDDEN, 'Not permitted.');

  const audit = await listPermissionAudit(req.params.connectionId);
  return sendData(res, audit, {
    state: audit.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: PERMISSION_MATRIX_VERSION,
    source: SOURCES.RULE,
  });
});

/* ------------------------------------------------------------------ *
 * Partner read models
 * ------------------------------------------------------------------ */

export const getPartnerHomeScreen = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await getPartnerHome(req.params.connectionId, userId);
  if (!result.ok) return authError(res, result.errorCode);

  return sendData(res, result.data, { state: result.state, version: result.version, source: result.source });
});

export const getPartnerContext = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await getPartnerSafeContext(req.params.connectionId, userId);
  if (!result.ok) return authError(res, result.errorCode);

  return sendData(res, result.data, {
    state: result.state,
    version: result.version,
    source: result.source ?? SOURCES.RULE,
    permissions: result.permissions ?? null,
    errorCode: result.errorCode ?? null,
  });
});

export const getUsSurface = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await getSharedSurface(req.params.connectionId, userId);
  if (!result.ok) return authError(res, result.errorCode);

  return sendData(res, result.data, {
    state: result.state,
    version: result.version,
    source: result.source ?? SOURCES.RULE,
    permissions: result.permissions ?? null,
    errorCode: result.errorCode ?? null,
  });
});

/* ------------------------------------------------------------------ *
 * Support requests (spec §11)
 * ------------------------------------------------------------------ */

export const getSupportRequestTypes = contractHandler(async (_req, res) => {
  const types = Object.values(SUPPORT_REQUEST_TYPES).map((type) => ({
    key: type.key,
    label: type.label,
    defaultMessage: type.defaultMessage,
  }));
  return sendData(res, types, { state: RESPONSE_STATES.READY, source: SOURCES.RULE });
});

export const createRequest = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const auth = await authorizeConnection(req.params.connectionId, userId);
  if (!auth.ok) return authError(res, auth.errorCode);
  if (!auth.active) return sendError(res, 409, ERROR_CODES.RELATIONSHIP_INACTIVE, 'This relationship is not active.');
  if (!auth.viewerIsSubject) {
    return sendError(res, 403, ERROR_CODES.FORBIDDEN, 'Only the person receiving support can create a request.');
  }

  const validation = validateSupportRequest(req.body ?? {});
  if (!validation.ok) return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, validation.error);

  const request = await createSupportRequest({
    connectionId: req.params.connectionId,
    requesterUserId: auth.subjectUserId,
    partnerUserId: auth.partnerUserId,
    ...validation.value,
  });

  // The partner is notified of the request only - no health data travels with
  // it (spec §11).
  await scheduleNotification(auth.partnerUserId, {
    category: 'partner_support_request',
    title: 'A support request',
    body: request.message,
    entityType: 'support_request',
    entityId: request.requestId,
    dedupeKey: `support_request:${request.requestId}`,
  });

  await recordAnalyticsEvent({
    userId,
    pseudonymousId: null,
    eventName: 'support_request_sent',
    properties: { requestType: request.type },
  });

  return sendData(res, request, { httpStatus: 201, state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export const listRequests = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const auth = await authorizeConnection(req.params.connectionId, userId);
  if (!auth.ok) return authError(res, auth.errorCode);
  if (!auth.active) {
    return sendData(res, [], { state: RESPONSE_STATES.RESTRICTED, errorCode: ERROR_CODES.RELATIONSHIP_INACTIVE, source: SOURCES.RULE });
  }

  const states = typeof req.query.states === 'string'
    ? req.query.states.split(',').map((s) => s.trim()).filter(Boolean)
    : null;

  const requests = await listSupportRequests({
    connectionId: req.params.connectionId,
    viewerUserId: userId,
    viewerRole: auth.viewerIsPartner ? 'partner' : 'requester',
    states,
  });

  return sendData(res, requests, {
    state: requests.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.MANUAL,
  });
});

export const updateRequestState = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const nextState = req.body?.state;
  if (!Object.values(SUPPORT_REQUEST_STATES).includes(nextState)) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, `state must be one of: ${Object.values(SUPPORT_REQUEST_STATES).join(', ')}.`);
  }

  const result = await transitionSupportRequest({
    requestId: req.params.requestId,
    actorUserId: userId,
    nextState,
  });

  if (result.notFound) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Support request not found.');
  if (result.forbidden) return sendError(res, 403, ERROR_CODES.FORBIDDEN, 'You cannot change this request.');
  if (!result.ok) {
    return sendError(res, 409, ERROR_CODES.CONFLICT, `Cannot move a ${result.currentState} request to ${nextState}.`, {
      currentState: result.currentState,
      errorCode: result.errorCode,
    });
  }

  if (nextState === SUPPORT_REQUEST_STATES.COMPLETED) {
    await recordAnalyticsEvent({
      userId,
      pseudonymousId: null,
      eventName: 'support_request_completed',
      properties: { requestType: result.request.type },
    });
  }

  return sendData(res, result.request, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

/**
 * Ending a relationship revokes outstanding requests immediately (spec §28).
 */
export const revokeConnectionRequests = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const auth = await authorizeConnection(req.params.connectionId, userId);
  if (!auth.ok) return authError(res, auth.errorCode);

  const revoked = await revokeAllForConnection(req.params.connectionId);
  return sendData(res, { revoked }, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export { describeSharingState };

/* ------------------------------------------------------------------ *
 * Permission requests (spec section 10)
 *
 * A partner can ask to be shown something that is off. Asking never shares
 * anything: the person whose data it is stays the only one who can approve.
 * ------------------------------------------------------------------ */

export const createPermissionRequest = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const permissionKey = String(req.body?.permissionKey ?? '').trim();
  if (!permissionKey) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'permissionKey is required.');
  }

  const result = await requestPermission(req.params.connectionId, userId, {
    permissionKey,
    message: req.body?.message,
  });

  if (!result.ok) {
    if (result.errorCode === 'FORBIDDEN') {
      return sendError(res, 403, ERROR_CODES.FORBIDDEN, result.message ?? 'Not allowed.');
    }
    if (result.errorCode === 'VALIDATION_FAILED') {
      return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.message ?? 'Invalid request.');
    }
    return authError(res, result.errorCode);
  }

  return sendData(res, {
    request: result.request,
    // Re-asking is not an error, but the caller should know nothing new
    // happened rather than believing a second nudge was sent.
    alreadyPending: Boolean(result.alreadyPending),
  }, {
    httpStatus: result.alreadyPending ? 200 : 201,
    state: RESPONSE_STATES.READY,
    source: SOURCES.MANUAL,
  });
});

export const listPermissionRequestsController = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const statesParam = typeof req.query?.states === 'string' ? req.query.states.trim() : '';
  const states = statesParam.length > 0 ? statesParam.split(',') : null;

  const result = await listPermissionRequests(req.params.connectionId, userId, { states });
  if (!result.ok) return authError(res, result.errorCode);

  return sendData(res, result.data, {
    state: result.data.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.MANUAL,
  });
});

export const respondToPermissionRequestController = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const approve = req.body?.approve;
  if (typeof approve !== 'boolean') {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'approve must be true or false.');
  }

  const result = await respondToPermissionRequest(req.params.requestId, userId, { approve });
  if (!result.ok) {
    if (result.errorCode === 'FORBIDDEN') {
      return sendError(res, 403, ERROR_CODES.FORBIDDEN, result.message ?? 'Not allowed.');
    }
    if (result.errorCode === 'VALIDATION_FAILED') {
      return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.message ?? 'Invalid request.');
    }
    return authError(res, result.errorCode);
  }

  return sendData(res, result.request, {
    state: RESPONSE_STATES.READY,
    source: SOURCES.MANUAL,
  });
});

export const withdrawPermissionRequestController = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await withdrawPermissionRequest(req.params.requestId, userId);
  if (!result.ok) {
    if (result.errorCode === 'FORBIDDEN') {
      return sendError(res, 403, ERROR_CODES.FORBIDDEN, result.message ?? 'Not allowed.');
    }
    if (result.errorCode === 'VALIDATION_FAILED') {
      return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.message ?? 'Invalid request.');
    }
    return authError(res, result.errorCode);
  }

  return sendData(res, result.request, {
    state: RESPONSE_STATES.READY,
    source: SOURCES.MANUAL,
  });
});

/* ------------------------------------------------------------------ *
 * The shared garden (spec section 21)
 * ------------------------------------------------------------------ */

export const getSharedGardenController = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const connection = await partnerRepository.getConnectionForUser(req.params.connectionId, userId);
  if (!connection) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Connection not found.');

  const garden = await getGarden(req.params.connectionId);
  return sendData(res, garden, {
    state: (garden.flowers > 0 || garden.trees > 0 || garden.hasPond)
      ? RESPONSE_STATES.READY
      // An empty garden is a real state: it is what a new couple starts with.
      : RESPONSE_STATES.EMPTY,
    source: SOURCES.MANUAL,
  });
});

export const growSharedGardenController = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const connection = await partnerRepository.getConnectionForUser(req.params.connectionId, userId);
  if (!connection) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Connection not found.');

  const flowers = Number(req.body?.flowers ?? 0);
  const trees = Number(req.body?.trees ?? 0);
  const addPond = req.body?.addPond === true;

  if (!Number.isInteger(flowers) || !Number.isInteger(trees)) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'flowers and trees must be whole numbers.');
  }
  // Growth only. Letting a client send negatives would turn a shared keepsake
  // into something either person could quietly tear down.
  if (flowers < 0 || trees < 0) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'A garden only grows.');
  }
  if (flowers > 10 || trees > 10) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'That is too much growth at once.');
  }
  if (flowers === 0 && trees === 0 && !addPond) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'Nothing to add.');
  }

  const garden = await growGarden(req.params.connectionId, userId, { flowers, trees, addPond });

  // Both people are looking at the same garden, so both are told it changed.
  publishToUsers(
    [connection.partnerUserId, userId],
    'partner.updated',
    { reason: 'garden-grown', connectionId: req.params.connectionId },
  );

  return sendData(res, garden, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});
