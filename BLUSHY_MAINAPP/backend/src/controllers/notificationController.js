import {
  getPreferences,
  updatePreferences,
  listNotifications,
  countUnread,
  markRead,
  scheduleNotification,
  cancelForEntity,
} from '../repositories/notificationRepository.js';
import { NOTIFICATION_CATEGORIES, CATEGORY_KEYS, NOTIFICATION_ENGINE_VERSION } from '../domain/notifications.js';
import { recordAnalyticsEvent, ANALYTICS_EVENTS, getFunnelCounts } from '../repositories/auditRepository.js';
import { randomUUID, createHash } from 'node:crypto';
import {
  registerDevice,
  unregisterDevice,
  listDevices,
  getDeliveryLog,
  PUSH_PLATFORMS,
} from '../services/pushDeliveryService.js';
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
 * Notification preferences, delivery and analytics ingest
 * (spec §19, §24, §26).
 */

export const getCategories = contractHandler(async (_req, res) => {
  const categories = CATEGORY_KEYS.map((key) => ({
    key,
    label: NOTIFICATION_CATEGORIES[key].label,
    sensitive: NOTIFICATION_CATEGORIES[key].sensitive,
    defaultEnabled: NOTIFICATION_CATEGORIES[key].defaultEnabled,
    audience: NOTIFICATION_CATEGORIES[key].audience,
    alwaysOn: Boolean(NOTIFICATION_CATEGORIES[key].alwaysOn),
  }));

  return sendData(res, categories, {
    state: RESPONSE_STATES.READY,
    version: NOTIFICATION_ENGINE_VERSION,
    source: SOURCES.RULE,
  });
});

export const getMyPreferences = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const preferences = await getPreferences(userId);
  return sendData(res, preferences, {
    state: RESPONSE_STATES.READY,
    version: NOTIFICATION_ENGINE_VERSION,
    source: SOURCES.MANUAL,
  });
});

export const patchMyPreferences = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const preferences = await updatePreferences(userId, req.body ?? {});
  return sendData(res, preferences, {
    state: RESPONSE_STATES.READY,
    version: NOTIFICATION_ENGINE_VERSION,
    source: SOURCES.MANUAL,
  });
});

export const getMyNotifications = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const limit = Math.min(Number(req.query.limit) || 50, 100);
  const skip = Math.max(Number(req.query.skip) || 0, 0);

  const notifications = await listNotifications(userId, {
    unreadOnly: req.query.unreadOnly === 'true',
    limit,
    skip,
  });
  const unread = await countUnread(userId);

  return sendData(res, notifications, {
    state: notifications.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: NOTIFICATION_ENGINE_VERSION,
    source: SOURCES.RULE,
    meta: { unreadCount: unread, pagination: { limit, skip } },
  });
});

export const markNotificationsRead = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const ids = Array.isArray(req.body?.notificationIds) ? req.body.notificationIds : [];
  const updated = await markRead(userId, ids);

  return sendData(res, { markedRead: updated, unreadCount: await countUnread(userId) }, {
    state: RESPONSE_STATES.READY,
    source: SOURCES.MANUAL,
  });
});

/**
 * Creates a reminder tied to an entity, so it can be cancelled automatically
 * when that entity is deleted (spec §24: "Every reminder has an underlying
 * event/entity ID").
 */
export const createReminder = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { category, title, body, entityType, entityId, scheduledFor, deepLink } = req.body ?? {};
  if (!NOTIFICATION_CATEGORIES[category]) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, `category must be one of: ${CATEGORY_KEYS.join(', ')}.`);
  }
  if (!entityType || !entityId) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'entityType and entityId are required so the reminder can be cancelled with its source.');
  }

  const result = await scheduleNotification(userId, {
    category,
    title: title ?? NOTIFICATION_CATEGORIES[category].label,
    body: body ?? null,
    entityType,
    entityId,
    deepLink: deepLink ?? null,
    scheduledFor: scheduledFor ?? null,
    dedupeKey: `${entityType}:${entityId}:${category}`,
  });

  if (!result.ok) {
    // Not an error: the user has this category off, or quiet hours apply.
    return sendData(res, { scheduled: false, reason: result.reason }, {
      state: RESPONSE_STATES.RESTRICTED,
      version: NOTIFICATION_ENGINE_VERSION,
      source: SOURCES.RULE,
      errorCode: 'NOTIFICATION_SUPPRESSED',
    });
  }

  return sendData(res, result.notification, {
    httpStatus: result.deduplicated ? 200 : 201,
    state: RESPONSE_STATES.READY,
    version: NOTIFICATION_ENGINE_VERSION,
    source: SOURCES.RULE,
  });
});

export const cancelReminder = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { entityType, entityId } = req.params;
  const cancelled = await cancelForEntity(userId, entityType, entityId, 'cancelled_by_user');

  return sendData(res, { cancelled }, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

/* ------------------------------------------------------------------ *
 * Analytics ingest (spec §26)
 * ------------------------------------------------------------------ */

/**
 * Pseudonymous analytics ID derived from the user id, so analytics rows are not
 * keyed on the account identifier (spec §26: "Use pseudonymous analytics IDs
 * where possible").
 */
function pseudonymousIdFor(userId) {
  if (!userId) return `anon_${randomUUID()}`;
  return `px_${createHash('sha256').update(`blushy-analytics:${userId}`).digest('hex').slice(0, 24)}`;
}

export const getAnalyticsSchema = contractHandler(async (_req, res) => {
  return sendData(res, { events: ANALYTICS_EVENTS }, { state: RESPONSE_STATES.READY, source: SOURCES.RULE });
});

export const trackAnalytics = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  const { eventName, properties = {} } = req.body ?? {};

  const result = await recordAnalyticsEvent({
    userId,
    pseudonymousId: pseudonymousIdFor(userId),
    eventName,
    properties,
  });

  if (!result.ok) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.error, { allowedEvents: ANALYTICS_EVENTS });
  }

  return sendData(res, { recorded: true }, { httpStatus: 202, state: RESPONSE_STATES.READY, source: SOURCES.RULE });
});

export const getAnalyticsFunnel = contractHandler(async (req, res) => {
  const counts = await getFunnelCounts({ from: req.query.from ?? null, to: req.query.to ?? null });
  return sendData(res, counts, {
    state: Object.keys(counts).length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.RULE,
  });
});

/* ------------------------------------------------------------------ *
 * Push devices (spec §19, §24)
 * ------------------------------------------------------------------ */

export const registerPushDevice = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { token, platform, appVersion = null } = req.body ?? {};
  const result = await registerDevice(userId, { token, platform, appVersion });
  if (!result.ok) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.error, { platforms: PUSH_PLATFORMS });
  }

  return sendData(res, { registered: true }, {
    httpStatus: 201,
    state: RESPONSE_STATES.READY,
    source: SOURCES.MANUAL,
  });
});

/**
 * Called on sign-out, so notifications for one account never arrive on a
 * device someone else is now signed into.
 */
export const unregisterPushDevice = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  await unregisterDevice(userId, req.body?.token);
  return sendData(res, { unregistered: true }, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export const getPushDevices = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const devices = await listDevices(userId);
  return sendData(res, devices, {
    state: devices.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.MANUAL,
  });
});

export const getPushDeliveryLog = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const log = await getDeliveryLog(userId);
  return sendData(res, log, {
    state: log.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.RULE,
  });
});
