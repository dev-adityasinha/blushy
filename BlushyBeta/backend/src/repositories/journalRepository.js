import { db } from '../utils/db.js';

async function getColl(userId, baseName = 'user_journals') {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const isMan = await db.collection('users_man').findOne({ user_id: cleanUserId });
  return isMan ? `${baseName}_man` : `${baseName}_woman`;
}

function formatDateOnly(value) {
  if (!value) return '';
  if (value instanceof Date) {
    const y = value.getFullYear();
    const m = String(value.getMonth() + 1).padStart(2, '0');
    const d = String(value.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  if (typeof value === 'string') {
    if (value.length >= 10) return value.slice(0, 10);
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

async function getJournalsByUserId(userId, limit = 30) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const collName = await getColl(cleanUserId);
  const docs = await db.collection(collName)
    .find({ user_id: cleanUserId })
    .sort({ entry_date: -1 })
    .limit(limit)
    .toArray();

  return docs.map((doc) => ({
    id: doc._id.toString(),
    date: doc.entry_date ? formatDateOnly(doc.entry_date) : null,
    entries: doc.entries || [],
    summary: doc.summary || '',
    createdAt: doc.created_at,
    updatedAt: doc.updated_at,
  }));
}

async function upsertJournal({ userId, entryDate, entries, summary }) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const finalEntryDate = entryDate || formatDateOnly(new Date());
  const entryDateObj = new Date(`${finalEntryDate}T00:00:00.000Z`);

  const filter = { user_id: cleanUserId, entry_date: entryDateObj };
  const collName = await getColl(cleanUserId);

  await db.collection(collName).updateOne(
    filter,
    {
      $set: {
        entries: entries || [],
        summary: summary || '',
        updated_at: new Date(),
      },
      $setOnInsert: {
        created_at: new Date(),
      }
    },
    { upsert: true }
  );

  return {
    userId: cleanUserId,
    entryDate: finalEntryDate,
    entries: entries || [],
    summary: summary || '',
  };
}

export const journalRepository = {
  getJournalsByUserId,
  upsertJournal,
};
