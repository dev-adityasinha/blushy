import {
  createCapsule,
  listCapsules,
  getCapsule,
  openCapsule,
  deleteCapsule,
} from '../repositories/timeCapsuleRepository.js';
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
 * Time capsules (spec section 12).
 *
 * A sealed capsule's body never leaves the server before its date. Hiding it
 * client-side would make the seal a matter of trust in the app rather than a
 * property of the data.
 */

export const listMyCapsules = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const capsules = await listCapsules(userId);
  return sendData(res, capsules, {
    state: capsules.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.MANUAL,
  });
});

export const createMyCapsule = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const title = String(req.body?.title ?? '').trim();
  const body = String(req.body?.body ?? '').trim();
  const deliverAt = req.body?.deliverAt ?? null;

  if (title.length === 0) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'A title is required.');
  }
  if (body.length === 0) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'Write something to seal.');
  }

  let deliverDate = null;
  if (deliverAt !== null && deliverAt !== undefined && String(deliverAt).trim().length > 0) {
    deliverDate = new Date(deliverAt);
    if (Number.isNaN(deliverDate.getTime())) {
      return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'deliverAt must be a valid date.');
    }
  }

  const capsule = await createCapsule({ userId, title, body, deliverAt: deliverDate });
  return sendData(res, capsule, {
    httpStatus: 201,
    state: RESPONSE_STATES.READY,
    source: SOURCES.MANUAL,
  });
});

export const getMyCapsule = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const capsule = await getCapsule(userId, req.params.capsuleId);
  if (!capsule) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Capsule not found.');

  return sendData(res, capsule, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export const openMyCapsule = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await openCapsule(userId, req.params.capsuleId);

  if (!result.ok && result.reason === 'not_found') {
    return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Capsule not found.');
  }
  if (!result.ok && result.reason === 'sealed') {
    // Sealing is the feature. Opening early is refused, not merely discouraged.
    return sendError(res, 403, ERROR_CODES.FORBIDDEN, 'This capsule is still sealed.', {
      deliverAt: result.deliverAt,
    });
  }

  return sendData(res, result.capsule, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export const deleteMyCapsule = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const deleted = await deleteCapsule(userId, req.params.capsuleId);
  if (!deleted) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Capsule not found.');

  return sendData(res, { deleted: true }, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});
