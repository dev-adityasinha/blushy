import { db } from '../utils/db.js';

async function getColl(userId, baseName) {
  const isMan = await db.collection('users_man').findOne({ user_id: userId });
  return isMan ? `${baseName}_man` : `${baseName}_woman`;
}

async function upsertProfileMemory({ userId, profileData }) {
  const filter = { user_id: userId };
  const existing = await db.collection(await getColl(userId, 'user_profile_memory')).findOne(filter);

  const now = new Date();
  let mergedProfileData = {};

  if (existing) {
    mergedProfileData = {
      ...(existing.profile_data ?? {}),
      ...(profileData ?? {}),
    };
    await db.collection(await getColl(userId, 'user_profile_memory')).updateOne(
      filter,
      {
        $set: {
          profile_data: mergedProfileData,
          updated_at: now,
        },
      }
    );
  } else {
    mergedProfileData = profileData ?? {};
    await db.collection(await getColl(userId, 'user_profile_memory')).insertOne({
      user_id: userId,
      profile_data: mergedProfileData,
      created_at: now,
      updated_at: now,
    });
  }

  const row = await db.collection(await getColl(userId, 'user_profile_memory')).findOne(filter);
  if (!row) {
    return null;
  }

  return {
    user_id: row.user_id,
    profile_data: row.profile_data ?? {},
    created_at: row.created_at ? new Date(row.created_at).toISOString() : null,
    updated_at: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

async function getProfileMemory(userId) {
  const row = await db.collection(await getColl(userId, 'user_profile_memory')).findOne({ user_id: userId });
  if (!row) {
    return null;
  }

  return {
    user_id: row.user_id,
    profile_data: row.profile_data ?? {},
    created_at: row.created_at ? new Date(row.created_at).toISOString() : null,
    updated_at: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

export const profileMemoryRepository = {
  upsertProfileMemory,
  getProfileMemory,
};