import { ObjectId } from 'mongodb';
import { db } from '../utils/db.js';
import { logger } from '../utils/logger.js';
import { periodPredictionConfig } from '../config/periodPredictionConfig.js';

async function getColl(userId, baseName = 'user_period_logs') {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const isMan = await db.collection('users_man').findOne({ user_id: cleanUserId });
  return isMan ? `${baseName}_man` : `${baseName}_woman`;
}

function formatDateOnly(value) {
  if (!value) return null;

  if (value instanceof Date) {
    const y = value.getFullYear();
    const m = String(value.getMonth() + 1).padStart(2, '0');
    const d = String(value.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
      return trimmed;
    }
    const parsed = new Date(trimmed);
    if (!Number.isNaN(parsed.getTime())) {
      const y = parsed.getFullYear();
      const m = String(parsed.getMonth() + 1).padStart(2, '0');
      const d = String(parsed.getDate()).padStart(2, '0');
      return `${y}-${m}-${d}`;
    }
  }

  return null;
}

function mapRow(row) {
  if (!row) return null;

  return {
    id: row._id ? row._id.toString() : null,
    userId: row.user_id,
    periodStartDate: formatDateOnly(row.period_start_date),
    periodEndDate: formatDateOnly(row.period_end_date),
    flowIntensity: row.flow_intensity || null,
    source: row.source || 'manual_tracker',
    notes: row.notes || null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

async function syncLatestPeriodToUser(userId) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const collName = await getColl(cleanUserId);
  const usersColl = collName.endsWith('_man') ? 'users_man' : 'users_woman';

  const newest = await db.collection(collName)
    .find({ user_id: cleanUserId })
    .sort({ period_start_date: -1 })
    .limit(1)
    .toArray();

  if (newest.length > 0) {
    const latestDateStr = formatDateOnly(newest[0].period_start_date);
    const parsedDate = new Date(latestDateStr);

    // Same shape as syncLegacyProfileStage: rebuilding the object handles a
    // null, absent or wrongly-typed onboarding_answers in one atomic update,
    // instead of reading the document first and branching on what it found.
    await db.collection(usersColl).updateOne(
      { user_id: cleanUserId },
      [
        {
          $set: {
            cycle_start_date: parsedDate,
            updated_at: new Date(),
            onboarding_answers: {
              $mergeObjects: [
                {
                  $cond: [
                    { $eq: [{ $type: '$onboarding_answers' }, 'object'] },
                    '$onboarding_answers',
                    {},
                  ],
                },
                {
                  last_period: latestDateStr,
                  cycle_start_date: latestDateStr,
                  period_last_start_date: latestDateStr,
                },
              ],
            },
          },
        },
      ],
    );
  }
}

export async function createOrUpdatePeriodEntry(userId, data) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const collName = await getColl(cleanUserId);

  const startDateStr = formatDateOnly(data.periodStartDate || data.startDate || data.period_start_date);
  if (!startDateStr) {
    throw new Error('Valid periodStartDate (YYYY-MM-DD) is required.');
  }

  const endDateStr = formatDateOnly(data.periodEndDate || data.endDate || data.period_end_date);
  const flowIntensity = ['spotting', 'light', 'medium', 'heavy'].includes(data.flowIntensity)
    ? data.flowIntensity
    : null;
  const source = data.source || 'manual_tracker';
  const notes = typeof data.notes === 'string' ? data.notes.slice(0, 500) : null;

  const now = new Date();
  const updateDoc = {
    $set: {
      period_start_date: startDateStr,
      period_end_date: endDateStr,
      flow_intensity: flowIntensity,
      source,
      notes,
      updated_at: now,
    },
    $setOnInsert: {
      user_id: cleanUserId,
      created_at: now,
    },
  };

  // Logging a start *corrects* the current cycle; it does not add another one.
  //
  // The upsert matched an exact date only, so every correction appended a new
  // row. Someone fixing their start date built up a cluster -- 24th, 25th,
  // 26th, 27th, 28th, 31st -- and since the current cycle start is the most
  // recent of them, an earlier correction could never take effect. It looked
  // like the date was being rejected; in fact all six were stored, and the one
  // she was trying to replace still won.
  //
  // Starts closer together than a cycle can be are the same period, which the
  // interval maths already assumes. So a new start supersedes any existing one
  // inside that window, and anything older is a genuinely different cycle and
  // is left alone.
  const windowDays = periodPredictionConfig.minCycleLengthDays;
  const supersededFrom = new Date(`${startDateStr}T00:00:00.000Z`);
  supersededFrom.setUTCDate(supersededFrom.getUTCDate() - windowDays + 1);
  const supersededTo = new Date(`${startDateStr}T00:00:00.000Z`);
  supersededTo.setUTCDate(supersededTo.getUTCDate() + windowDays - 1);

  const superseded = await db.collection(collName).deleteMany({
    user_id: cleanUserId,
    period_start_date: {
      $ne: startDateStr,
      $gte: formatDateOnly(supersededFrom),
      $lte: formatDateOnly(supersededTo),
    },
  });

  if (superseded?.deletedCount) {
    logger.info(
      `Period start ${startDateStr} superseded ${superseded.deletedCount} ` +
      `entry/entries within ${windowDays} days for ${cleanUserId}.`,
    );
  }

  const result = await db.collection(collName).findOneAndUpdate(
    { user_id: cleanUserId, period_start_date: startDateStr },
    updateDoc,
    { upsert: true, returnDocument: 'after' }
  );

  await syncLatestPeriodToUser(cleanUserId);

  const savedDoc = result?.value || result || await db.collection(collName).findOne({
    user_id: cleanUserId,
    period_start_date: startDateStr,
  });

  return mapRow(savedDoc);
}

export async function getPeriodEntries(userId, limit = 50) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const collName = await getColl(cleanUserId);

  const rows = await db.collection(collName)
    .find({ user_id: cleanUserId })
    .sort({ period_start_date: -1 })
    .limit(Math.min(limit, 100))
    .toArray();

  return rows.map(mapRow);
}

export async function getPeriodEntryById(userId, entryId) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const collName = await getColl(cleanUserId);

  let query = { user_id: cleanUserId };
  if (ObjectId.isValid(entryId)) {
    query._id = new ObjectId(entryId);
  } else {
    query._id = entryId;
  }

  const row = await db.collection(collName).findOne(query);
  return mapRow(row);
}

export async function deletePeriodEntry(userId, entryId) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const collName = await getColl(cleanUserId);

  let query = { user_id: cleanUserId };
  if (ObjectId.isValid(entryId)) {
    query._id = new ObjectId(entryId);
  } else {
    query._id = entryId;
  }

  const res = await db.collection(collName).deleteOne(query);
  if (res.deletedCount > 0) {
    await syncLatestPeriodToUser(cleanUserId);
    return true;
  }
  return false;
}

export async function batchCreateOnboardingEntries(userId, dateStrings = [], source = 'onboarding') {
  if (!Array.isArray(dateStrings) || dateStrings.length === 0) {
    return [];
  }

  const results = [];
  for (const dateStr of dateStrings) {
    const formatted = formatDateOnly(dateStr);
    if (formatted) {
      const entry = await createOrUpdatePeriodEntry(userId, {
        periodStartDate: formatted,
        source,
      });
      results.push(entry);
    }
  }
  return results;
}
