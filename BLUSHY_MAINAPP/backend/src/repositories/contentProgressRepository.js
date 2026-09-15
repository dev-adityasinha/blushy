import { db } from '../utils/db.js';

/**
 * M Studio / Learn progress and bookmarks (spec §13 "M Studio / Learn",
 * §23 "M STUDIO / LEARN FUNCTIONALITY").
 *
 * Supports saved/bookmarked and read/progress states for both audiences.
 */

const COLLECTION = 'user_content_progress';

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

function mapRow(row) {
  if (!row) return null;
  return {
    userId: row.user_id,
    contentId: row.content_id,
    progressPercent: row.progress_percent ?? 0,
    positionSeconds: row.position_seconds ?? null,
    completed: Boolean(row.completed),
    bookmarked: Boolean(row.bookmarked),
    lastOpenedAt: row.last_opened_at ? new Date(row.last_opened_at).toISOString() : null,
    completedAt: row.completed_at ? new Date(row.completed_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

export async function upsertProgress(userId, contentId, { progressPercent, positionSeconds, completed, opened } = {}) {
  const uid = cleanUserId(userId);
  const now = new Date();
  const set = { updated_at: now };

  if (Number.isFinite(Number(progressPercent))) {
    set.progress_percent = Math.min(100, Math.max(0, Math.round(Number(progressPercent))));
  }
  if (Number.isFinite(Number(positionSeconds))) {
    set.position_seconds = Math.max(0, Math.round(Number(positionSeconds)));
  }
  if (completed !== undefined) {
    set.completed = Boolean(completed);
    if (completed) {
      set.completed_at = now;
      set.progress_percent = 100;
    }
  }
  if (opened) set.last_opened_at = now;

  await db.collection(COLLECTION).updateOne(
    { user_id: uid, content_id: contentId },
    {
      $set: set,
      $setOnInsert: {
        user_id: uid,
        content_id: contentId,
        bookmarked: false,
        created_at: now,
      },
    },
    { upsert: true },
  );

  const row = await db.collection(COLLECTION).findOne({ user_id: uid, content_id: contentId });
  return mapRow(row);
}

export async function setBookmark(userId, contentId, bookmarked) {
  const uid = cleanUserId(userId);
  const now = new Date();
  await db.collection(COLLECTION).updateOne(
    { user_id: uid, content_id: contentId },
    {
      $set: { bookmarked: Boolean(bookmarked), updated_at: now },
      $setOnInsert: { user_id: uid, content_id: contentId, progress_percent: 0, completed: false, created_at: now },
    },
    { upsert: true },
  );
  const row = await db.collection(COLLECTION).findOne({ user_id: uid, content_id: contentId });
  return mapRow(row);
}

export async function getProgressMap(userId, contentIds = []) {
  const uid = cleanUserId(userId);
  const query = { user_id: uid };
  if (Array.isArray(contentIds) && contentIds.length > 0) {
    query.content_id = { $in: contentIds };
  }
  const rows = await db.collection(COLLECTION).find(query).toArray();
  const map = {};
  for (const row of rows) {
    map[row.content_id] = mapRow(row);
  }
  return map;
}

export async function listBookmarks(userId, { limit = 50 } = {}) {
  const rows = await db.collection(COLLECTION)
    .find({ user_id: cleanUserId(userId), bookmarked: true })
    .sort({ updated_at: -1 })
    .limit(Math.min(limit, 100))
    .toArray();
  return rows.map(mapRow);
}

export async function listCompleted(userId, { limit = 50 } = {}) {
  const rows = await db.collection(COLLECTION)
    .find({ user_id: cleanUserId(userId), completed: true })
    .sort({ completed_at: -1 })
    .limit(Math.min(limit, 100))
    .toArray();
  return rows.map(mapRow);
}

export async function purgeUserProgress(userId) {
  const result = await db.collection(COLLECTION).deleteMany({ user_id: cleanUserId(userId) });
  return result.deletedCount ?? 0;
}
