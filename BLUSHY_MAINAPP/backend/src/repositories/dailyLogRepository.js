import { ObjectId } from 'mongodb';
import { db } from '../utils/db.js';

async function getColl(userId) {
  const cleanId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const isMan = await db.collection('users_man').findOne({ user_id: cleanId });
  return isMan ? 'user_daily_logs_man' : 'user_daily_logs_woman';
}

function isValidDateString(str) {
  if (typeof str !== 'string') return false;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(str)) return false;
  const [y, m, d] = str.split('-').map(Number);
  if (m < 1 || m > 12) return false;
  const isLeap = (y % 4 === 0 && y % 100 !== 0) || (y % 400 === 0);
  const maxDays = [31, isLeap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1];
  return d >= 1 && d <= maxDays;
}

function mapRow(row) {
  if (!row) return null;
  return {
    id: row._id?.toString() ?? null,
    userId: row.user_id,
    logDate: row.log_date,
    mood: row.mood ?? null,
    energyLevel: row.energy_level ?? null,
    sleepHours: typeof row.sleep_hours === 'number' ? row.sleep_hours : null,
    symptoms: Array.isArray(row.symptoms) ? row.symptoms : [],
    notes: row.notes ?? null,
    source: row.source ?? 'manual_checkin',
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

export async function createOrUpdateDailyLog(userId, data) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const collName = await getColl(cleanUserId);

  const logDate = data.logDate || data.log_date;
  if (!logDate || !isValidDateString(logDate)) {
    throw new Error('Valid logDate in YYYY-MM-DD format is required.');
  }

  const mood = typeof data.mood === 'string' ? data.mood.slice(0, 50) : null;
  const energyLevel = typeof data.energyLevel === 'string' || typeof data.energy_level === 'string'
    ? (data.energyLevel || data.energy_level).slice(0, 50)
    : null;
  const sleepHours = typeof data.sleepHours === 'number'
    ? Math.max(0, Math.min(24, Math.round(data.sleepHours)))
    : (typeof data.sleep_hours === 'number' ? Math.max(0, Math.min(24, Math.round(data.sleep_hours))) : null);
  const symptoms = Array.isArray(data.symptoms)
    ? data.symptoms.filter((s) => typeof s === 'string' && s.trim().length > 0).map((s) => s.trim().slice(0, 50)).slice(0, 20)
    : [];
  const notes = typeof data.notes === 'string' ? data.notes.slice(0, 500) : null;
  const source = typeof data.source === 'string' ? data.source.slice(0, 50) : 'manual_checkin';

  const now = new Date();
  const updateDoc = {
    $set: {
      log_date: logDate,
      mood,
      energy_level: energyLevel,
      sleep_hours: sleepHours,
      symptoms,
      notes,
      source,
      updated_at: now,
    },
    $setOnInsert: {
      user_id: cleanUserId,
      created_at: now,
    },
  };

  const result = await db.collection(collName).findOneAndUpdate(
    { user_id: cleanUserId, log_date: logDate },
    updateDoc,
    { upsert: true, returnDocument: 'after' }
  );

  const savedDoc = result?.value || result || await db.collection(collName).findOne({
    user_id: cleanUserId,
    log_date: logDate,
  });

  return mapRow(savedDoc);
}

export async function getDailyLogsForRange(userId, startDate, endDate) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const collName = await getColl(cleanUserId);

  const rows = await db.collection(collName)
    .find({
      user_id: cleanUserId,
      log_date: { $gte: startDate, $lte: endDate },
    })
    .sort({ log_date: 1 })
    .toArray();

  return rows.map(mapRow);
}

export async function getDailyLogByDate(userId, logDate) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const collName = await getColl(cleanUserId);

  const row = await db.collection(collName).findOne({
    user_id: cleanUserId,
    log_date: logDate,
  });

  return mapRow(row);
}
