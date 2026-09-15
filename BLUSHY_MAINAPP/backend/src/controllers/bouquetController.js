import {
  createBouquet,
  listOwnBouquets,
  listReceivedBouquets,
  getBouquet,
  sendBouquetCopy,
  markBouquetOpened,
  deleteBouquet,
} from '../repositories/bouquetRepository.js';
import { partnerRepository } from '../repositories/partnerRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { scheduleNotification } from '../repositories/notificationRepository.js';
import { publishToUsers } from '../utils/realtimeHub.js';
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
 * Digital bouquets (spec section 21).
 *
 * They were kept on one device, so a reinstall lost them and "Send Digital
 * Flowers" sent nothing -- the button only opened the builder.
 */

export const listMyBouquets = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const received = String(req.query?.received ?? '') === 'true';
  const bouquets = received
    ? await listReceivedBouquets(userId)
    : await listOwnBouquets(userId);

  return sendData(res, bouquets, {
    state: bouquets.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.MANUAL,
  });
});

export const createMyBouquet = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await createBouquet({
    userId,
    creatorName: req.body?.creator,
    design: req.body ?? {},
  });

  if (!result.ok) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'A bouquet needs at least one flower.');
  }

  return sendData(res, result.bouquet, {
    httpStatus: 201,
    state: RESPONSE_STATES.READY,
    source: SOURCES.MANUAL,
  });
});

/**
 * Sends a bouquet to a connected partner.
 *
 * The recipient is taken from the connection rather than the request body, so
 * a bouquet cannot be pushed at an arbitrary account.
 */
export const sendMyBouquet = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const connectionId = String(req.body?.connectionId ?? '').trim();
  if (!connectionId) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'connectionId is required.');
  }

  const connection = await partnerRepository.getConnectionForUser(connectionId, userId);
  if (!connection) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Connection not found.');
  if (connection.status !== 'active') {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'That connection is not active.');
  }

  const sender = await userRepository.getUserById(userId);
  const senderName = sender?.displayName || sender?.email?.split('@')[0] || 'Your partner';

  const result = await sendBouquetCopy({
    bouquetId: req.params.bouquetId,
    senderUserId: userId,
    recipientUserId: connection.partnerUserId,
    senderName,
  });

  if (!result.ok) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Bouquet not found.');

  // Best effort: the bouquet has arrived either way and is visible in their app.
  try {
    await scheduleNotification(connection.partnerUserId, {
      category: 'partner_shared_update',
      title: `${senderName} sent you flowers`,
      body: 'A bouquet is waiting for you.',
      entityType: 'bouquet',
      entityId: result.bouquet.bouquetId,
      deepLink: 'blushy://partner/boutique',
      dedupeKey: `bouquet:${result.bouquet.bouquetId}`,
    });
  } catch (_) {
    // Delivery of the notice is not what makes the bouquet real.
  }

  publishToUsers([connection.partnerUserId, userId], 'partner.updated', {
    reason: 'bouquet-sent',
    connectionId,
  });

  return sendData(res, { sent: true, bouquetId: result.bouquet.bouquetId }, {
    httpStatus: 201,
    state: RESPONSE_STATES.READY,
    source: SOURCES.MANUAL,
  });
});

export const openMyBouquet = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const existing = await getBouquet(userId, req.params.bouquetId);
  if (!existing) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Bouquet not found.');

  const bouquet = await markBouquetOpened(userId, req.params.bouquetId);
  return sendData(res, bouquet, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export const deleteMyBouquet = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const deleted = await deleteBouquet(userId, req.params.bouquetId);
  if (!deleted) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Bouquet not found.');

  return sendData(res, { deleted: true }, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});
