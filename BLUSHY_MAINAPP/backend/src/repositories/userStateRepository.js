import { db } from '../utils/db.js';

/**
 * Small per-user documents that used to live only on the device.
 *
 * Thirteen keys -- her period kit, the school bag, what she is noticing, her
 * life mode, her treatments and support circle, her health records, the
 * reflections she writes -- were written to device storage and nowhere else.
 * They were invisible on the web, absent for her clinician, and gone with a
 * reinstall. Treatments in particular is medication history.
 *
 * One collection rather than thirteen: the shapes differ, none of them is
 * queried by anything but its own screen, and a generic store is the
 * difference between one endpoint to get right and thirteen to get wrong.
 * The value is stored as given; only the key is interpreted here.
 */
const COLLECTION = 'user_state';

/**
 * Keys are namespaced by screen, so they cannot collide by accident.
 *
 * Hyphens are allowed because some documents are per-day and carry the date:
 * `stage2_flow_2026-09-17`. Still no slashes or dots, so a key can never be
 * read as a path.
 */
const KEY_PATTERN = /^[a-z0-9_-]{1,64}$/;

export function isValidKey(key) {
  return typeof key === 'string' && KEY_PATTERN.test(key);
}

async function listForUser(userId) {
  if (!userId) return {};
  const rows = await db.collection(COLLECTION).find({ user_id: userId }).toArray();
  const out = {};
  for (const row of rows) {
    if (row?.key) out[row.key] = row.value ?? null;
  }
  return out;
}

async function getForUser(userId, key) {
  if (!userId || !isValidKey(key)) return null;
  const row = await db.collection(COLLECTION).findOne({ user_id: userId, key });
  return row?.value ?? null;
}

/**
 * Last write wins, which is what a single-owner document wants: the screen
 * holds the whole value and sends it entire, so merging fields would invent a
 * state neither device had.
 */
async function putForUser(userId, key, value) {
  if (!userId) throw new Error('A user id is required to store user state.');
  if (!isValidKey(key)) throw new Error(`Invalid user state key: ${key}`);

  const now = new Date();
  await db.collection(COLLECTION).updateOne(
    { user_id: userId, key },
    {
      $set: { value: value ?? null, updated_at: now },
      $setOnInsert: { user_id: userId, key, created_at: now },
    },
    { upsert: true },
  );
  return { key, updatedAt: now.toISOString() };
}

async function removeForUser(userId, key) {
  if (!userId || !isValidKey(key)) return 0;
  const result = await db.collection(COLLECTION).deleteOne({ user_id: userId, key });
  return result?.deletedCount ?? 0;
}

export const userStateRepository = {
  listForUser,
  getForUser,
  putForUser,
  removeForUser,
  isValidKey,
  COLLECTION,
};
