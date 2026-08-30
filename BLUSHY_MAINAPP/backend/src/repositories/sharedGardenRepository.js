import { db } from '../utils/db.js';

/**
 * The garden a couple tends together.
 *
 * It was stored under `shared_garden_state` in device storage -- local to one
 * phone despite the name, so the partner never saw it and a reinstall reset it.
 * It also started at 3 flowers and 1 tree, so the first thing anyone saw was a
 * garden they had not grown.
 *
 * It belongs to the connection, not to either person: whatever one does, the
 * other sees.
 */
const COLLECTION = 'shared_gardens';

/** A new garden is empty. Growth has to be earned. */
const EMPTY_GARDEN = Object.freeze({ flowers: 0, trees: 0, hasPond: false });

function mapRow(row) {
  return {
    flowers: Number(row?.flowers ?? EMPTY_GARDEN.flowers),
    trees: Number(row?.trees ?? EMPTY_GARDEN.trees),
    hasPond: row?.has_pond === true,
    updatedAt: row?.updated_at ? new Date(row.updated_at).toISOString() : null,
    updatedByUserId: row?.updated_by_user_id ?? null,
  };
}

export async function getGarden(connectionId) {
  const row = await db.collection(COLLECTION).findOne({ connection_id: connectionId });
  return mapRow(row);
}

/**
 * Applies growth atomically.
 *
 * `$inc` rather than read-modify-write: both partners can be tending the same
 * garden at once, and a lost update would silently discard someone's work.
 */
export async function growGarden(connectionId, userId, { flowers = 0, trees = 0, addPond = false }) {
  const inc = {};
  if (flowers !== 0) inc.flowers = flowers;
  if (trees !== 0) inc.trees = trees;

  const update = {
    $set: { updated_at: new Date(), updated_by_user_id: userId },
    $setOnInsert: { connection_id: connectionId, created_at: new Date() },
  };
  if (Object.keys(inc).length > 0) update.$inc = inc;
  if (addPond) update.$set.has_pond = true;

  const result = await db.collection(COLLECTION).findOneAndUpdate(
    { connection_id: connectionId },
    update,
    { upsert: true, returnDocument: 'after' },
  );

  return mapRow(result);
}

export async function deleteGarden(connectionId) {
  const result = await db.collection(COLLECTION).deleteOne({ connection_id: connectionId });
  return result.deletedCount > 0;
}
