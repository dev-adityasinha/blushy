import { randomUUID } from 'node:crypto';

import { db } from '../utils/db.js';

/**
 * Time capsules: something written now, opened later.
 *
 * The feature existed only in device storage, so "Deliver in 6 Months" opened
 * nothing and a reinstall lost every capsule. Sealing is the whole point, so
 * the seal is enforced on read: a capsule's body is never returned before its
 * deliver-at date, rather than being sent down and hidden by the client.
 */
const COLLECTION = 'time_capsules';

function mapRow(row, { now = new Date(), includeSealedBody = false } = {}) {
  if (!row) return null;

  const deliverAt = row.deliver_at ? new Date(row.deliver_at) : null;
  const isOpen = !deliverAt || deliverAt <= now;

  return {
    capsuleId: row.capsule_id,
    title: row.title,
    // Withheld until it is due. The client never receives a sealed body, so a
    // sealed capsule cannot be read by inspecting the response.
    body: isOpen || includeSealedBody ? (row.body ?? '') : null,
    sealed: !isOpen,
    deliverAt: deliverAt ? deliverAt.toISOString() : null,
    openedAt: row.opened_at ? new Date(row.opened_at).toISOString() : null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

export async function createCapsule({ userId, title, body, deliverAt }) {
  const doc = {
    capsule_id: randomUUID(),
    user_id: userId,
    title: String(title ?? '').trim().slice(0, 120),
    body: String(body ?? '').trim().slice(0, 5000),
    deliver_at: deliverAt ? new Date(deliverAt) : null,
    opened_at: null,
    notified_at: null,
    created_at: new Date(),
  };

  await db.collection(COLLECTION).insertOne(doc);
  return mapRow(doc, { includeSealedBody: false });
}

export async function listCapsules(userId, { now = new Date(), limit = 50 } = {}) {
  const rows = await db.collection(COLLECTION)
    .find({ user_id: userId })
    .sort({ deliver_at: 1, created_at: -1 })
    .limit(limit)
    .toArray();

  return rows.map((row) => mapRow(row, { now }));
}

export async function getCapsule(userId, capsuleId, { now = new Date() } = {}) {
  const row = await db.collection(COLLECTION).findOne({ user_id: userId, capsule_id: capsuleId });
  return mapRow(row, { now });
}

/**
 * Marks a due capsule as opened. A sealed one cannot be opened early, so the
 * date is checked here rather than trusted from the caller.
 */
export async function openCapsule(userId, capsuleId, { now = new Date() } = {}) {
  const row = await db.collection(COLLECTION).findOne({ user_id: userId, capsule_id: capsuleId });
  if (!row) return { ok: false, reason: 'not_found' };

  const deliverAt = row.deliver_at ? new Date(row.deliver_at) : null;
  if (deliverAt && deliverAt > now) {
    return { ok: false, reason: 'sealed', deliverAt: deliverAt.toISOString() };
  }

  if (!row.opened_at) {
    await db.collection(COLLECTION).updateOne(
      { capsule_id: capsuleId },
      { $set: { opened_at: now } },
    );
    row.opened_at = now;
  }

  return { ok: true, capsule: mapRow(row, { now }) };
}

export async function deleteCapsule(userId, capsuleId) {
  const result = await db.collection(COLLECTION).deleteOne({ user_id: userId, capsule_id: capsuleId });
  return result.deletedCount > 0;
}

/**
 * Capsules that have come due and have not been announced yet.
 *
 * `notified_at` is what stops the same capsule being announced every time the
 * scheduler runs.
 */
export async function findDueCapsules({ now = new Date(), limit = 200 } = {}) {
  const rows = await db.collection(COLLECTION)
    .find({ deliver_at: { $ne: null, $lte: now }, notified_at: null })
    .limit(limit)
    .toArray();

  return rows.map((row) => ({
    capsuleId: row.capsule_id,
    userId: row.user_id,
    title: row.title,
    deliverAt: row.deliver_at ? new Date(row.deliver_at).toISOString() : null,
  }));
}

export async function markCapsuleNotified(capsuleId, { now = new Date() } = {}) {
  await db.collection(COLLECTION).updateOne(
    { capsule_id: capsuleId },
    { $set: { notified_at: now } },
  );
}

export async function purgeUserCapsules(userId) {
  const result = await db.collection(COLLECTION).deleteMany({ user_id: userId });
  return result.deletedCount ?? 0;
}
