import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';
import {
  defaultNotificationPreferences,
  sanitizeNotificationPreferences,
  evaluateDelivery,
} from '../domain/notifications.js';

/**
 * Notification store and preferences (spec §19, §24).
 *
 * Every notification links back to the entity that caused it
 * (`entityType` + `entityId`), which is what makes cancellation on delete or
 * revocation possible.
 */

const COLLECTION = 'notifications';
const PREFS_COLLECTION = 'notification_preferences';

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

function mapRow(row) {
  if (!row) return null;
  return {
    notificationId: row.notification_id,
    userId: row.user_id,
    category: row.category,
    title: row.title,
    body: row.body,
    lockScreenTitle: row.lock_screen_title ?? null,
    lockScreenBody: row.lock_screen_body ?? null,
    entityType: row.entity_type ?? null,
    entityId: row.entity_id ?? null,
    deepLink: row.deep_link ?? null,
    scheduledFor: row.scheduled_for ? new Date(row.scheduled_for).toISOString() : null,
    deliveredAt: row.delivered_at ? new Date(row.delivered_at).toISOString() : null,
    readAt: row.read_at ? new Date(row.read_at).toISOString() : null,
    cancelledAt: row.cancelled_at ? new Date(row.cancelled_at).toISOString() : null,
    cancelReason: row.cancel_reason ?? null,
    status: row.status,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

export async function getPreferences(userId) {
  const row = await db.collection(PREFS_COLLECTION).findOne({ user_id: cleanUserId(userId) });
  if (!row) return defaultNotificationPreferences();
  return sanitizeNotificationPreferences(row.preferences, defaultNotificationPreferences());
}

export async function updatePreferences(userId, patch) {
  const uid = cleanUserId(userId);
  const current = await getPreferences(uid);
  const next = sanitizeNotificationPreferences(patch, current);

  await db.collection(PREFS_COLLECTION).updateOne(
    { user_id: uid },
    { $set: { preferences: next, updated_at: new Date() }, $setOnInsert: { user_id: uid, created_at: new Date() } },
    { upsert: true },
  );

  return next;
}

/**
 * Schedules a notification. Category preferences and quiet hours are applied
 * here, so a caller cannot bypass them by writing directly.
 *
 * `dedupeKey` prevents duplicate creation for the same underlying event.
 */
export async function scheduleNotification(userId, {
  category,
  title,
  body,
  entityType = null,
  entityId = null,
  deepLink = null,
  scheduledFor = null,
  dedupeKey = null,
}) {
  const uid = cleanUserId(userId);
  const preferences = await getPreferences(uid);
  const when = scheduledFor ? new Date(scheduledFor) : new Date();

  const decision = evaluateDelivery({ category, preferences, title, body, now: when });
  if (!decision.deliver && !decision.deferUntilQuietHoursEnd) {
    return { ok: false, skipped: true, reason: decision.reason };
  }

  if (dedupeKey) {
    const existing = await db.collection(COLLECTION).findOne({
      user_id: uid,
      dedupe_key: dedupeKey,
      status: { $in: ['scheduled', 'delivered'] },
    });
    if (existing) {
      return { ok: true, notification: mapRow(existing), deduplicated: true };
    }
  }

  const now = new Date();
  const doc = {
    notification_id: randomUUID(),
    user_id: uid,
    category,
    title,
    body,
    lock_screen_title: decision.lockScreenTitle,
    lock_screen_body: decision.lockScreenBody,
    entity_type: entityType,
    entity_id: entityId,
    deep_link: deepLink,
    dedupe_key: dedupeKey,
    scheduled_for: when,
    delivered_at: null,
    read_at: null,
    cancelled_at: null,
    cancel_reason: null,
    // Deferred by quiet hours stays scheduled; the delivery worker retries.
    status: 'scheduled',
    deferred_by_quiet_hours: Boolean(decision.deferUntilQuietHoursEnd),
    created_at: now,
  };

  await db.collection(COLLECTION).insertOne(doc);
  return { ok: true, notification: mapRow(doc), deduplicated: false };
}

/**
 * Notifications that are due to be sent: scheduled, not cancelled, and whose
 * time has arrived. Ones deferred by quiet hours stay scheduled and reappear
 * here on a later pass, which is how the deferral is honoured.
 */
export async function findDueNotifications({ now = new Date(), limit = 100 } = {}) {
  const rows = await db.collection(COLLECTION)
    .find({
      status: 'scheduled',
      scheduled_for: { $lte: now },
      $or: [{ delivery_attempts: { $lt: MAX_DELIVERY_ATTEMPTS } }, { delivery_attempts: { $exists: false } }],
    })
    .sort({ scheduled_for: 1 })
    .limit(Math.min(limit, 500))
    .toArray();

  return rows.map(mapRow);
}

export const MAX_DELIVERY_ATTEMPTS = 5;

export async function markNotificationDelivered(notificationId) {
  await db.collection(COLLECTION).updateOne(
    { notification_id: notificationId },
    { $set: { status: 'delivered', delivered_at: new Date() } },
  );
}

/**
 * Records a failed attempt. After MAX_DELIVERY_ATTEMPTS the notification stops
 * being retried, so one undeliverable row cannot occupy the worker forever.
 */
export async function recordDeliveryAttempt(notificationId, reason) {
  const result = await db.collection(COLLECTION).findOneAndUpdate(
    { notification_id: notificationId },
    { $inc: { delivery_attempts: 1 }, $set: { last_delivery_reason: reason } },
    { returnDocument: 'after' },
  );
  const attempts = result?.delivery_attempts ?? result?.value?.delivery_attempts ?? 0;
  if (attempts >= MAX_DELIVERY_ATTEMPTS) {
    await db.collection(COLLECTION).updateOne(
      { notification_id: notificationId },
      { $set: { status: 'failed', cancel_reason: reason } },
    );
  }
  return attempts;
}

/** For outcomes that can never succeed, such as a category the user turned off. */
export async function cancelNotification(notificationId, reason) {
  await db.collection(COLLECTION).updateOne(
    { notification_id: notificationId },
    { $set: { status: 'cancelled', cancelled_at: new Date(), cancel_reason: reason } },
  );
}

export async function listNotifications(userId, { status = null, unreadOnly = false, limit = 50, skip = 0 } = {}) {
  const query = { user_id: cleanUserId(userId) };
  if (status) query.status = status;
  else query.status = { $ne: 'cancelled' };
  if (unreadOnly) query.read_at = null;

  const rows = await db.collection(COLLECTION)
    .find(query)
    .sort({ scheduled_for: -1 })
    .skip(Math.max(Number(skip) || 0, 0))
    .limit(Math.min(Math.max(Number(limit) || 50, 1), 100))
    .toArray();

  return rows.map(mapRow);
}

export async function countUnread(userId) {
  return db.collection(COLLECTION).countDocuments({
    user_id: cleanUserId(userId),
    read_at: null,
    status: { $ne: 'cancelled' },
  });
}

export async function markRead(userId, notificationIds = []) {
  const uid = cleanUserId(userId);
  const query = { user_id: uid, read_at: null };
  if (Array.isArray(notificationIds) && notificationIds.length > 0) {
    query.notification_id = { $in: notificationIds };
  }
  const result = await db.collection(COLLECTION).updateMany(query, { $set: { read_at: new Date() } });
  return result.modifiedCount ?? 0;
}

/**
 * Cancels every notification tied to an entity. Called when a source event is
 * deleted or a partner permission is revoked (spec §19: "Notifications expire
 * when the underlying event is deleted/revoked").
 */
export async function cancelForEntity(userId, entityType, entityId, reason = 'source_removed') {
  const query = {
    entity_type: entityType,
    entity_id: entityId,
    status: { $in: ['scheduled', 'delivered'] },
  };
  if (userId) query.user_id = cleanUserId(userId);

  const result = await db.collection(COLLECTION).updateMany(query, {
    $set: { status: 'cancelled', cancelled_at: new Date(), cancel_reason: reason },
  });
  return result.modifiedCount ?? 0;
}

export async function cancelByCategory(userId, category, reason = 'permission_revoked') {
  const result = await db.collection(COLLECTION).updateMany(
    { user_id: cleanUserId(userId), category, status: { $in: ['scheduled', 'delivered'] } },
    { $set: { status: 'cancelled', cancelled_at: new Date(), cancel_reason: reason } },
  );
  return result.modifiedCount ?? 0;
}

export async function listRecentByCategory(userId, category, sinceDays = 7) {
  const since = new Date(Date.now() - sinceDays * 86400000);
  const rows = await db.collection(COLLECTION)
    .find({ user_id: cleanUserId(userId), category, created_at: { $gte: since }, status: { $ne: 'cancelled' } })
    .sort({ created_at: -1 })
    .toArray();
  return rows.map(mapRow);
}

export async function purgeUserNotifications(userId) {
  const uid = cleanUserId(userId);
  const a = await db.collection(COLLECTION).deleteMany({ user_id: uid });
  const b = await db.collection(PREFS_COLLECTION).deleteMany({ user_id: uid });
  return (a.deletedCount ?? 0) + (b.deletedCount ?? 0);
}
