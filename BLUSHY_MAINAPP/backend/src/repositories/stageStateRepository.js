import { db } from '../utils/db.js';

/**
 * A per-user document store for stage services that used to keep their state in
 * process-level Map()s.
 *
 * Those Maps were lost on every restart and never shared between instances, so
 * a woman's postpartum, pregnancy or perimenopause data lived only on whichever
 * process happened to serve her and vanished on a deploy. Each service now
 * keeps one document per user in its own collection: load it, mutate the plain
 * object, save it. The service's own logic in between is unchanged.
 *
 * `defaults` maps each field to a factory that builds its empty value, so a
 * freshly loaded user has the same shape the Map code assumed and a missing
 * field never reads as undefined.
 */
export function makeUserDocStore(collectionName, defaults) {
  function withDefaults(state) {
    const out = {};
    for (const [key, make] of Object.entries(defaults)) {
      const v = state ? state[key] : undefined;
      out[key] = (v !== undefined && v !== null) ? v : make();
    }
    return out;
  }

  return {
    collectionName,
    /** The user's state with every field present, from Mongo. */
    async load(userId) {
      if (!userId) return withDefaults(null);
      const doc = await db.collection(collectionName).findOne({ user_id: userId });
      return withDefaults(doc ? doc.state : null);
    },
    /** Replace the user's whole state document. Last write wins. */
    async save(userId, state) {
      if (!userId) throw new Error('A user id is required to persist stage state.');
      const now = new Date();
      await db.collection(collectionName).updateOne(
        { user_id: userId },
        { $set: { state, updated_at: now }, $setOnInsert: { user_id: userId, created_at: now } },
        { upsert: true },
      );
      return state;
    },
  };
}
