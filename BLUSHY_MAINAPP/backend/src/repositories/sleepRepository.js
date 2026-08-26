import { db } from '../utils/db.js';

async function getColl(userId, baseName) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const isMan = await db.collection('users_man').findOne({ user_id: cleanUserId });
  return isMan ? `${baseName}_man` : `${baseName}_woman`;
}

function formatTime(value) {
  if (typeof value !== 'string' || value.length < 5) {
    return '';
  }
  return value.slice(0, 5);
}

function formatDateOnly(value) {
  if (!value) {
    return '';
  }

  if (value instanceof Date) {
    const y = value.getFullYear();
    const m = String(value.getMonth() + 1).padStart(2, '0');
    const d = String(value.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  if (typeof value === 'string') {
    if (value.length >= 10) {
      return value.slice(0, 10);
    }

    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      const y = parsed.getFullYear();
      const m = String(parsed.getMonth() + 1).padStart(2, '0');
      const d = String(parsed.getDate()).padStart(2, '0');
      return `${y}-${m}-${d}`;
    }
  }

  return '';
}

function mapRow(row) {
  if (!row) {
    return null;
  }

  return {
    userId: row.user_id,
    entryDate: formatDateOnly(row.entry_date),
    sleepTime: formatTime(row.sleep_time),
    wakeTime: formatTime(row.wake_time),
    durationMinutes: Number(row.duration_minutes) || 0,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

async function pruneSleepHistory(userId, retentionDays = 7) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const safeRetentionDays = Number.isInteger(retentionDays) && retentionDays > 0 ? retentionDays : 7;

  const todayStr = todayIso();
  const today = new Date(`${todayStr}T00:00:00.000Z`);
  today.setUTCDate(today.getUTCDate() - (safeRetentionDays - 1));

  const collName = await getColl(cleanUserId, 'user_sleep_logs');
  await db.collection(collName).deleteMany({
    user_id: cleanUserId,
    entry_date: { $lt: today },
  });
}

async function getSleepByDate(userId, entryDate = todayIso()) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const finalEntryDate = entryDate || todayIso();
  const entryDateObj = new Date(`${finalEntryDate}T00:00:00.000Z`);

  const collName = await getColl(cleanUserId, 'user_sleep_logs');
  const doc = await db.collection(collName).findOne({
    user_id: cleanUserId,
    entry_date: entryDateObj,
  });

  return mapRow(doc);
}

async function upsertSleepByDate({ userId, entryDate = todayIso(), sleepTime, wakeTime, durationMinutes }) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const finalEntryDate = entryDate || todayIso();
  const entryDateObj = new Date(`${finalEntryDate}T00:00:00.000Z`);

  const filter = { user_id: cleanUserId, entry_date: entryDateObj };
  const collName = await getColl(cleanUserId, 'user_sleep_logs');

  await db.collection(collName).updateOne(
    filter,
    {
      $set: {
        sleep_time: sleepTime,
        wake_time: wakeTime,
        duration_minutes: durationMinutes,
        updated_at: new Date(),
      },
      $setOnInsert: {
        created_at: new Date(),
      }
    },
    { upsert: true }
  );

  const updatedDoc = await db.collection(collName).findOne(filter);

  return mapRow(updatedDoc);
}

async function getRecentSleepLogs(userId, days = 7) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const safeDays = Number.isInteger(days) && days > 0 ? Math.min(days, 7) : 7;

  const collName = await getColl(cleanUserId, 'user_sleep_logs');
  const result = await db.collection(collName)
    .find({ user_id: cleanUserId })
    .sort({ entry_date: -1 })
    .limit(safeDays)
    .toArray();

  return result.map(mapRow).reverse();
}

async function getSleepByUserId(userId, limit = 30) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const collName = await getColl(cleanUserId, 'user_sleep_logs');
  const docs = await db.collection(collName)
    .find({ user_id: cleanUserId })
    .sort({ entry_date: -1 })
    .limit(limit)
    .toArray();

  return docs.map((doc) => ({
    date: doc.entry_date ? formatDateOnly(doc.entry_date) : null,
    sleepTime: doc.sleep_time,
    wakeTime: doc.wake_time,
    durationMinutes: doc.duration_minutes,
  }));
}

export const sleepRepository = {
  pruneSleepHistory,
  getSleepByDate,
  upsertSleepByDate,
  getRecentSleepLogs,
  getSleepByUserId,
};
