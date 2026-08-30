import { randomUUID } from 'node:crypto';

import { db } from '../utils/db.js';
import { normalizeRole as normalizeRoleValue } from '../utils/role.js';

async function getColl(userId, baseName) {
  const isMan = await db.collection('users_man').findOne({ user_id: userId });
  return isMan ? `${baseName}_man` : `${baseName}_woman`;
}

function mapRow(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    userKey: row.user_key,
    role: row.role,
    summaryDateIst: row.summary_date_ist,
    messageCount: row.message_count,
    firstMessageAt: row.first_message_at ? new Date(row.first_message_at).toISOString() : null,
    lastMessageAt: row.last_message_at ? new Date(row.last_message_at).toISOString() : null,
    summaryText: row.summary_text,
    createdAt: new Date(row.created_at).toISOString(),
  };
}

async function upsertDailySummary({
  userKey,
  role,
  summaryDateIst,
  messageCount,
  firstMessageAt,
  lastMessageAt,
  summaryText,
}) {
  const userId = userKey.replace('user:', '');
  const id = randomUUID();
  const filter = {
    user_key: userKey,
    summary_date_ist: summaryDateIst,
  };

  const update = {
    $set: {
      role: normalizeRoleValue(role, 'woman'),
      message_count: Math.max(0, Number(messageCount) || 0),
      first_message_at: firstMessageAt ? new Date(firstMessageAt) : null,
      last_message_at: lastMessageAt ? new Date(lastMessageAt) : null,
      summary_text: summaryText,
      created_at: new Date(),
    },
    $setOnInsert: {
      id,
    },
  };

  await db.collection(await getColl(userId, 'ai_chat_daily_summaries')).updateOne(filter, update, { upsert: true });

  const row = await db.collection(await getColl(userId, 'ai_chat_daily_summaries')).findOne(filter);
  return mapRow(row);
}

/**
 * A user's own daily summaries, newest first.
 *
 * These are built each night from the chat the user actually had, so this is
 * the only honest source for the daily letters the app shows them.
 */
async function listDailySummaries(userKey, limit = 7) {
  const userId = String(userKey).replace('user:', '');
  const rows = await db.collection(await getColl(userId, 'ai_chat_daily_summaries'))
    .find({ user_key: userKey })
    .sort({ summary_date_ist: -1 })
    .limit(Math.min(Math.max(Number(limit) || 7, 1), 30))
    .toArray();

  return rows.map(mapRow);
}

export const aiChatSummaryRepository = {
  upsertDailySummary,
  listDailySummaries,
};
