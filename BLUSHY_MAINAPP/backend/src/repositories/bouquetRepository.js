import { randomUUID } from 'node:crypto';

import { db } from '../utils/db.js';

/**
 * Digital bouquets: an arrangement someone made, kept and optionally sent.
 *
 * These lived in SharedPreferences on one device, so a reinstall lost every
 * bouquet and "Send Digital Flowers" sent nothing anywhere -- the button only
 * opened the builder.
 *
 * A sent bouquet is a copy, not a pointer. The sender may later delete theirs
 * or edit their garden; what someone was given should not change or vanish
 * underneath them.
 */
const COLLECTION = 'bouquets';

/** Caps on the design, so one arrangement cannot be an unbounded payload. */
const MAX_FLOWERS = 60;
const MAX_MESSAGE = 500;

function sanitizeDesign(design = {}) {
  const flowers = Array.isArray(design.flowers)
    ? design.flowers.slice(0, MAX_FLOWERS).map((f) => String(f).slice(0, 64))
    : [];

  return {
    flowers,
    greenery_index: Number.isInteger(design.greeneryIndex) ? design.greeneryIndex : 0,
    seed: Number.isInteger(design.seed) ? design.seed : 0,
    mode: design.mode === 'mono' ? 'mono' : 'color',
    message: String(design.message ?? '').trim().slice(0, MAX_MESSAGE),
    wrapping_paper: String(design.wrappingPaper ?? 'wrap-classic').slice(0, 64),
    ribbon_color_index: Number.isInteger(design.ribbonColorIndex) ? design.ribbonColorIndex : 0,
  };
}

function mapRow(row) {
  if (!row) return null;

  return {
    bouquetId: row.bouquet_id,
    flowers: row.flowers ?? [],
    greeneryIndex: row.greenery_index ?? 0,
    seed: row.seed ?? 0,
    mode: row.mode ?? 'color',
    message: row.message ?? '',
    wrappingPaper: row.wrapping_paper ?? 'wrap-classic',
    ribbonColorIndex: row.ribbon_color_index ?? 0,
    creator: row.creator_name ?? '',
    // Present only on a bouquet someone was given.
    fromUserId: row.from_user_id ?? null,
    receivedAt: row.received_at ? new Date(row.received_at).toISOString() : null,
    openedAt: row.opened_at ? new Date(row.opened_at).toISOString() : null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

export async function createBouquet({ userId, creatorName, design }) {
  const clean = sanitizeDesign(design);
  if (clean.flowers.length === 0) {
    return { ok: false, reason: 'empty' };
  }

  const doc = {
    bouquet_id: randomUUID(),
    user_id: userId,
    creator_name: String(creatorName ?? '').trim().slice(0, 80),
    ...clean,
    from_user_id: null,
    received_at: null,
    opened_at: null,
    created_at: new Date(),
  };

  await db.collection(COLLECTION).insertOne(doc);
  return { ok: true, bouquet: mapRow(doc) };
}

/** The bouquets someone made themselves. */
export async function listOwnBouquets(userId, { limit = 50 } = {}) {
  const rows = await db.collection(COLLECTION)
    .find({ user_id: userId, from_user_id: null })
    .sort({ created_at: -1 })
    .limit(limit)
    .toArray();

  return rows.map(mapRow);
}

/** The bouquets someone was given. */
export async function listReceivedBouquets(userId, { limit = 50 } = {}) {
  const rows = await db.collection(COLLECTION)
    .find({ user_id: userId, from_user_id: { $ne: null } })
    .sort({ received_at: -1 })
    .limit(limit)
    .toArray();

  return rows.map(mapRow);
}

export async function getBouquet(userId, bouquetId) {
  return mapRow(await db.collection(COLLECTION).findOne({ user_id: userId, bouquet_id: bouquetId }));
}

/**
 * Delivers a copy to the recipient.
 *
 * Copied rather than shared so the recipient's bouquet is theirs: it cannot be
 * edited or deleted out from under them by the sender.
 */
export async function sendBouquetCopy({ bouquetId, senderUserId, recipientUserId, senderName }) {
  const original = await db.collection(COLLECTION).findOne({
    bouquet_id: bouquetId,
    user_id: senderUserId,
  });
  if (!original) return { ok: false, reason: 'not_found' };

  const now = new Date();
  const copy = {
    bouquet_id: randomUUID(),
    user_id: recipientUserId,
    creator_name: String(senderName ?? original.creator_name ?? '').slice(0, 80),
    flowers: original.flowers ?? [],
    greenery_index: original.greenery_index ?? 0,
    seed: original.seed ?? 0,
    mode: original.mode ?? 'color',
    message: original.message ?? '',
    wrapping_paper: original.wrapping_paper ?? 'wrap-classic',
    ribbon_color_index: original.ribbon_color_index ?? 0,
    from_user_id: senderUserId,
    received_at: now,
    opened_at: null,
    created_at: now,
  };

  await db.collection(COLLECTION).insertOne(copy);
  return { ok: true, bouquet: mapRow(copy) };
}

export async function markBouquetOpened(userId, bouquetId, { now = new Date() } = {}) {
  const result = await db.collection(COLLECTION).findOneAndUpdate(
    { user_id: userId, bouquet_id: bouquetId, opened_at: null },
    { $set: { opened_at: now } },
    { returnDocument: 'after' },
  );
  // Already opened is not an error; return whatever is there.
  return mapRow(result) ?? getBouquet(userId, bouquetId);
}

export async function deleteBouquet(userId, bouquetId) {
  const result = await db.collection(COLLECTION).deleteOne({ user_id: userId, bouquet_id: bouquetId });
  return result.deletedCount > 0;
}

export async function purgeUserBouquets(userId) {
  const result = await db.collection(COLLECTION).deleteMany({ user_id: userId });
  return result.deletedCount ?? 0;
}
