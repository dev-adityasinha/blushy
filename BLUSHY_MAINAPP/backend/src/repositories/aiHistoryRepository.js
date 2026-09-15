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
    // Carried so the app can show which exchanges have been shared with a
    // partner. Without it the share control resets on every launch.
    sharedWithPartner: row.shared_with_partner === true,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
  };
}

async function appendConversation({ userKey, role, userMessage, assistantMessage, model }) {
  if (!userKey || !userKey.startsWith('user:')) {
    throw new Error('Authenticated user key required to persist conversation.');
  }

  const userId = userKey.replace('user:', '');
  const collName = await getColl(userId, 'ai_chat_history');
  const id = randomUUID();

  const doc = {
    id,
    user_key: `user:${userId}`,
    user_id: userId,
    role: normalizeStoredRole(role),
    user_message: userMessage,
    assistant_message: assistantMessage,
    model,
    created_at: new Date(),
  };

  await db.collection(collName).insertOne(doc);

  // Keep only latest 300 records per user scope.
  const latestDocs = await db.collection(collName)
    .find({
      $or: [
        { user_key: `user:${userId}` },
        { user_id: userId },
      ]
    })
    .sort({ created_at: -1 })
    .limit(300)
    .project({ id: 1 })
    .toArray();

  const idsToKeep = latestDocs.map((d) => d.id);

  await db.collection(collName).deleteMany({
    $or: [
      { user_key: `user:${userId}` },
      { user_id: userId },
    ],
    id: { $nin: idsToKeep },
  });

  return mapRow(doc);
}

async function listHistory(userKey) {
  if (!userKey || !userKey.startsWith('user:')) {
    return [];
  }

  const userId = userKey.replace('user:', '');
  const collName = await getColl(userId, 'ai_chat_history');

  const query = {
    $or: [
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
  if (!userKey || !userKey.startsWith('user:')) {
    return;
  }

  const userId = userKey.replace('user:', '');
  const collName = await getColl(userId, 'ai_chat_history');
  await db.collection(collName).deleteMany({
    $or: [
      { user_key: `user:${userId}` },
      { user_key: userId },
      { user_id: userId },
    ]
  });
}

async function listUserKeysWithHistory() {
  const keysMan = await db.collection('ai_chat_history_man').distinct('user_key');
  const keysWoman = await db.collection('ai_chat_history_woman').distinct('user_key');
  // Quarantine: Exclude any unauthenticated/anonymous keys from user listings
  const keys = [...new Set([...keysMan, ...keysWoman])].filter(k => typeof k === 'string' && k.startsWith('user:'));

  return keys;
}


/**
 * Marks one Docsy exchange as shareable with a partner, or takes it back.
 *
 * Same rule as the journal: the `sia_conversations` permission says a partner
 * may receive conversations, this flag says which ones. Docsy is where people
 * disclose the things they have not told anyone, so a blanket release would be
 * the single worst default in the app.
 */
async function setConversationShared({ userId, conversationId, shared }) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const collName = await getColl(cleanUserId, 'ai_chat_history');

  const result = await db.collection(collName).updateOne(
    { id: conversationId, user_id: cleanUserId },
    { $set: { shared_with_partner: shared === true, shared_at: shared === true ? new Date() : null } },
  );

  if (result.matchedCount === 0) return null;
  return { conversationId, sharedWithPartner: shared === true };
}

/**
 * Only the exchanges explicitly marked shared.
 */
async function listSharedConversations(userId, limit = 10) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const collName = await getColl(cleanUserId, 'ai_chat_history');

  const docs = await db.collection(collName)
    .find({ user_id: cleanUserId, shared_with_partner: true })
    .sort({ created_at: -1 })
    .limit(limit)
    .toArray();

  return docs.map((doc) => ({
    id: doc.id,
    userMessage: doc.user_message ?? '',
    assistantMessage: doc.assistant_message ?? '',
    sharedAt: doc.shared_at ?? null,
    createdAt: doc.created_at,
  }));
}

export const aiHistoryRepository = {
  setConversationShared,
  listSharedConversations,
  appendConversation,
  listHistory,
  clearHistory,
  listUserKeysWithHistory,
};
