import { randomUUID } from 'node:crypto';

import { db } from '../utils/db.js';
import { normalizeRole as normalizeRoleValue } from '../utils/role.js';

function normalizeStoredRole(role) {
  return normalizeRoleValue(role, 'woman');
}

async function getColl(userId, baseName) {
  const isMan = await db.collection('users_man').findOne({ user_id: userId });
  return isMan ? `${baseName}_man` : `${baseName}_woman`;
}

function mapRow(row) {
  if (!row) {
    return null;
  }

  const userMsg = row.user_message || row.userMessage || row.query || row.prompt || (row.role === 'user' ? (row.content || row.text || row.message) : null);
  const assistantMsg = row.assistant_message || row.assistantMessage || row.reply || row.response || (row.role !== 'user' ? (row.content || row.text || row.message) : null);

  return {
    id: row.id || String(row._id),
    role: row.role || 'woman',
    userMessage: userMsg || null,
    assistantMessage: assistantMsg || null,
    content: assistantMsg || userMsg || row.content || row.text || row.message || '',
    model: row.model || 'sia',
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
  };
}

async function appendConversation({ userKey, role, userMessage, assistantMessage, model }) {
  const userId = userKey.replace('user:', '');
  const collName = await getColl(userId, 'ai_chat_history');
  const id = randomUUID();

  const doc = {
    id,
    user_key: userKey,
    role: normalizeStoredRole(role),
    user_message: userMessage,
    assistant_message: assistantMessage,
    model,
    created_at: new Date(),
  };

  await db.collection(collName).insertOne(doc);

  // Keep only latest 300 records per user scope.
  const latestDocs = await db.collection(collName)
    .find({ user_key: userKey })
    .sort({ created_at: -1 })
    .limit(300)
    .project({ id: 1 })
    .toArray();

  const idsToKeep = latestDocs.map((d) => d.id);

  await db.collection(collName).deleteMany({
    user_key: userKey,
    id: { $nin: idsToKeep },
  });

  return mapRow(doc);
}

async function listHistory(userKey) {
  const userId = userKey.replace('user:', '');
  const collName = await getColl(userId, 'ai_chat_history');

  const query = {
    $or: [
      { user_key: userKey },
      { user_key: `user:${userId}` },
      { user_key: userId },
      { user_id: userId },
    ]
  };

  const docs = await db.collection(collName)
    .find(query)
    .sort({ created_at: 1 })
    .toArray();

  return docs.map(mapRow).filter(Boolean);
}

async function clearHistory(userKey) {
  const userId = userKey.replace('user:', '');
  const collName = await getColl(userId, 'ai_chat_history');
  await db.collection(collName).deleteMany({ user_key: userKey });
}

async function listUserKeysWithHistory() {
  const keysMan = await db.collection('ai_chat_history_man').distinct('user_key');
  const keysWoman = await db.collection('ai_chat_history_woman').distinct('user_key');
  const keys = [...new Set([...keysMan, ...keysWoman])];

  return keys
    .map((key) => (typeof key === 'string' ? key : ''))
    .filter((value) => value.length > 0)
    .sort();
}

export const aiHistoryRepository = {
  appendConversation,
  listHistory,
  clearHistory,
  listUserKeysWithHistory,
};
