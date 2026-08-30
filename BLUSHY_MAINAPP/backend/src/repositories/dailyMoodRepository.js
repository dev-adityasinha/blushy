import { db } from '../utils/db.js';
import { todayIso, dayStart, dayIsoFromStored } from '../utils/appCalendar.js';

async function getColl(userId, baseName) {
  const isMan = await db.collection('users_man').findOne({ user_id: userId });
  return isMan ? `${baseName}_man` : `${baseName}_woman`;
}


function mapRow(row) {
  if (!row) {
    return null;
  }

  return {
    userId: row.user_id,
    entryDate: dayIsoFromStored(row.entry_date),
    mood: row.mood,
    energyLevel: row.energy_level,
    stressLevel: row.stress_level,
    symptoms: Array.isArray(row.symptoms) ? row.symptoms : [],
    notes: row.notes ?? '',
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}


async function pruneDailyMoodHistory(userId, retentionDays = 30) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const safeRetentionDays = Number.isInteger(retentionDays) && retentionDays > 0 ? retentionDays : 30;

  const todayStr = todayIso();
  const today = dayStart(todayStr);
  today.setUTCDate(today.getUTCDate() - (safeRetentionDays - 1));

  await db.collection(await getColl(cleanUserId, 'user_daily_moods')).deleteMany({
    user_id: cleanUserId,
    entry_date: { $lt: today },
  });
}

async function getDailyMood(userId, entryDate = todayIso()) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  await pruneDailyMoodHistory(cleanUserId, 30);

  const finalEntryDate = entryDate || todayIso();
  const entryDateObj = dayStart(finalEntryDate);

  const doc = await db.collection(await getColl(cleanUserId, 'user_daily_moods')).findOne({
    user_id: cleanUserId,
    entry_date: entryDateObj,
  });

  return mapRow(doc);
}

async function upsertDailyMood({ userId, entryDate = todayIso(), mood, energyLevel, stressLevel, symptoms = [], notes = '' }) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  await pruneDailyMoodHistory(cleanUserId, 30);

  const finalEntryDate = entryDate || todayIso();
  const entryDateObj = dayStart(finalEntryDate);

  const filter = { user_id: cleanUserId, entry_date: entryDateObj };
  const collectionName = await getColl(cleanUserId, 'user_daily_moods');

  const updateFields = {
    mood,
    energy_level: energyLevel,
    stress_level: stressLevel,
    notes,
    updated_at: new Date(),
  };
  if (Array.isArray(symptoms) && symptoms.length > 0) {
    updateFields.symptoms = symptoms;
  }

  await db.collection(collectionName).updateOne(
    filter,
    {
      $set: updateFields,
      $setOnInsert: {
        created_at: new Date(),
      }
    },
    { upsert: true }
  );

  const updatedDoc = await db.collection(collectionName).findOne(filter);

  return mapRow(updatedDoc);
}

async function getRecentDailyMoods(userId, days = 30) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const safeDays = Number.isInteger(days) && days > 0 ? Math.min(days, 30) : 30;
  await pruneDailyMoodHistory(cleanUserId, 30);

  const result = await db.collection(await getColl(cleanUserId, 'user_daily_moods'))
    .find({ user_id: cleanUserId })
    .sort({ entry_date: -1 })
    .limit(safeDays)
    .toArray();

  return result.map(mapRow);
}

async function getMoodStreakDays(userId, endDate = todayIso()) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  await pruneDailyMoodHistory(cleanUserId, 30);

  const finalEndDate = endDate || todayIso();
  const endDateObj = dayStart(finalEndDate);

  const result = await db.collection(await getColl(cleanUserId, 'user_daily_moods'))
    .find({
      user_id: cleanUserId,
      entry_date: { $lte: endDateObj },
    })
    .sort({ entry_date: -1 })
    .toArray();

  let streakDays = 0;
  const cursor = dayStart(finalEndDate);

  for (const doc of result) {
    const entryDate = dayIsoFromStored(doc.entry_date);
    const expectedDate = cursor.toISOString().slice(0, 10);

    if (entryDate !== expectedDate) {
      break;
    }

    streakDays += 1;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }

  return streakDays;
}

async function getMoodsByUserId(userId, limit = 30) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const docs = await db.collection(await getColl(cleanUserId, 'user_daily_moods'))
    .find({ user_id: cleanUserId })
    .sort({ entry_date: -1 })
    .limit(limit)
    .toArray();

  return docs.map((doc) => ({
    date: doc.entry_date ? dayIsoFromStored(doc.entry_date) : null,
    mood: doc.mood,
    energy: doc.energy_level,
    stress: doc.stress_level,
  }));
}

export const dailyMoodRepository = {
  pruneDailyMoodHistory,
  getDailyMood,
  upsertDailyMood,
  getRecentDailyMoods,
  getMoodStreakDays,
  getMoodsByUserId,
};
