import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';
import { evaluateDelivery, defaultNotificationPreferences } from '../domain/notifications.js';
import { getPreferences } from '../repositories/notificationRepository.js';
import { parseServiceAccount, getAccessToken, sendMessage } from './fcmClient.js';

/**
 * Push delivery (spec §19, §24).
 *
 * The scheduling, category preferences, quiet hours and lock-screen redaction
 * all already happen in the notification engine. This is the transport layer
 * that would hand a notification to APNs or FCM.
 *
 * Transport is FCM HTTP v1, which covers Android, iOS (via an APNs key
 * uploaded to Firebase) and web. It activates only when
 * `FCM_SERVICE_ACCOUNT_JSON` is set; without it `deliver` records what it would
 * have sent and returns `delivered: false` with `reason:
 * 'no_provider_configured'` rather than pretending to have sent anything.
 */

const DEVICE_TOKENS = 'push_device_tokens';
const DELIVERY_LOG = 'push_delivery_log';

export const PUSH_PLATFORMS = Object.freeze(['ios', 'android', 'web']);

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

/**
 * Registers a device for push. One row per (user, token) so the same device
 * re-registering does not accumulate duplicates.
 */
export async function registerDevice(userId, { token, platform, appVersion = null }) {
  if (typeof token !== 'string' || token.trim().length === 0) {
    return { ok: false, error: 'A device token is required.' };
  }
  if (!PUSH_PLATFORMS.includes(platform)) {
    return { ok: false, error: `platform must be one of: ${PUSH_PLATFORMS.join(', ')}.` };
  }

  const uid = cleanUserId(userId);
  const now = new Date();

  await db.collection(DEVICE_TOKENS).updateOne(
    { user_id: uid, token: token.trim() },
    {
      $set: { platform, app_version: appVersion, last_seen_at: now, revoked_at: null },
      $setOnInsert: { device_id: randomUUID(), user_id: uid, token: token.trim(), created_at: now },
    },
    { upsert: true },
  );

  return { ok: true };
}

/**
 * Removes a device. Called on sign-out, so notifications for one account never
 * arrive on a device someone else is now signed into.
 */
export async function unregisterDevice(userId, token) {
  const result = await db.collection(DEVICE_TOKENS).deleteOne({
    user_id: cleanUserId(userId),
    token: typeof token === 'string' ? token.trim() : token,
  });
  return { ok: result.deletedCount > 0 };
}

export async function listDevices(userId) {
  const rows = await db.collection(DEVICE_TOKENS)
    .find({ user_id: cleanUserId(userId), revoked_at: null })
    .toArray();

  return rows.map((row) => ({
    deviceId: row.device_id,
    platform: row.platform,
    appVersion: row.app_version ?? null,
    // The token itself is never returned: it is a credential for sending to
    // that device.
    lastSeenAt: row.last_seen_at ? new Date(row.last_seen_at).toISOString() : null,
  }));
}

/**
 * Builds the payload that would go to a provider.
 *
 * The visible text comes from `evaluateDelivery`, which applies the category
 * preference, quiet hours and the lock-screen redaction. Sensitive categories
 * are redacted by default, so a period reminder does not display its subject
 * on a locked screen (spec §19).
 */
export function buildPushPayload({ notification, preferences }) {
  const decision = evaluateDelivery({
    category: notification.category,
    preferences: preferences ?? defaultNotificationPreferences(),
    title: notification.title,
    body: notification.body,
    now: new Date(),
  });

  if (!decision.deliver) {
    return { deliverable: false, reason: decision.reason, deferred: decision.deferUntilQuietHoursEnd };
  }

  return {
    deliverable: true,
    reason: null,
    deferred: false,
    payload: {
      // Only the redacted strings ever reach the transport.
      title: decision.lockScreenTitle,
      body: decision.lockScreenBody,
      data: {
        notificationId: notification.notificationId,
        category: notification.category,
        deepLink: notification.deepLink ?? null,
      },
    },
  };
}

/**
 * Attempts delivery. Records the outcome either way so a missing provider is
 * visible in the log rather than silently swallowed.
 */
export async function deliver(userId, notification) {
  const uid = cleanUserId(userId);
  const preferences = await getPreferences(uid);
  const built = buildPushPayload({ notification, preferences });

  if (!built.deliverable) {
    await recordDelivery(uid, notification, { delivered: false, reason: built.reason });
    return { delivered: false, reason: built.reason, deferred: built.deferred };
  }

  const devices = await listDevices(uid);
  if (devices.length === 0) {
    await recordDelivery(uid, notification, { delivered: false, reason: 'no_registered_device' });
    return { delivered: false, reason: 'no_registered_device' };
  }

  const serviceAccount = parseServiceAccount(process.env.FCM_SERVICE_ACCOUNT_JSON);
  if (!serviceAccount) {
    // Stated plainly rather than reported as a success.
    await recordDelivery(uid, notification, { delivered: false, reason: 'no_provider_configured' });
    return {
      delivered: false,
      reason: 'no_provider_configured',
      wouldHaveSent: built.payload,
      deviceCount: devices.length,
    };
  }

  return _sendToProvider(devices, built.payload, notification, uid, serviceAccount);
}

/**
 * Sends one redacted payload to each of the user's devices.
 *
 * A token that FCM reports as permanently dead is deleted rather than retried:
 * the app has been uninstalled or the token replaced, and keeping it would mean
 * a failure on every future send. Transient failures are left alone so the next
 * notification can try again.
 *
 * The outcome is recorded per device, so a partial delivery reads as partial in
 * the log instead of collapsing to a single success or failure.
 */
async function _sendToProvider(devices, payload, notification, userId, serviceAccount) {
  let accessToken;
  try {
    accessToken = await getAccessToken(serviceAccount);
  } catch (error) {
    await recordDelivery(userId, notification, { delivered: false, reason: 'provider_auth_failed' });
    return { delivered: false, reason: 'provider_auth_failed', error: error.message };
  }

  let delivered = 0;
  let pruned = 0;
  const failures = [];

  for (const device of devices) {
    const token = await tokenForDevice(userId, device.deviceId);
    if (!token) continue;

    let result;
    try {
      result = await sendMessage({ serviceAccount, accessToken, deviceToken: token, payload });
    } catch (error) {
      result = { ok: false, tokenIsDead: false, errorCode: 'TRANSPORT_ERROR' };
      failures.push({ deviceId: device.deviceId, errorCode: 'TRANSPORT_ERROR', message: error.message });
    }

    if (result.ok) {
      delivered += 1;
      await recordDelivery(userId, notification, { delivered: true, reason: 'sent' });
      continue;
    }

    if (result.tokenIsDead) {
      await unregisterDevice(userId, token);
      pruned += 1;
    }
    failures.push({ deviceId: device.deviceId, errorCode: result.errorCode });
    await recordDelivery(userId, notification, {
      delivered: false,
      reason: result.tokenIsDead ? `token_dead:${result.errorCode}` : `send_failed:${result.errorCode}`,
    });
  }

  return {
    delivered: delivered > 0,
    reason: delivered > 0 ? 'sent' : 'all_sends_failed',
    deliveredCount: delivered,
    prunedCount: pruned,
    failures,
  };
}

/**
 * The send token is deliberately absent from `listDevices`, so it is read here
 * and never leaves this module.
 */
async function tokenForDevice(userId, deviceId) {
  const row = await db.collection(DEVICE_TOKENS).findOne({ user_id: userId, device_id: deviceId });
  return row?.token ?? null;
}

async function recordDelivery(userId, notification, { delivered, reason }) {
  await db.collection(DELIVERY_LOG).insertOne({
    log_id: randomUUID(),
    user_id: userId,
    notification_id: notification.notificationId,
    category: notification.category,
    delivered,
    reason,
    created_at: new Date(),
  });
}

export async function getDeliveryLog(userId, limit = 50) {
  const rows = await db.collection(DELIVERY_LOG)
    .find({ user_id: cleanUserId(userId) })
    .sort({ created_at: -1 })
    .limit(Math.min(limit, 200))
    .toArray();

  return rows.map((row) => ({
    logId: row.log_id,
    notificationId: row.notification_id,
    category: row.category,
    delivered: row.delivered,
    reason: row.reason,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  }));
}
