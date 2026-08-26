import { db } from '../utils/db.js';

async function linkPhoneHashToUserId(phoneHash, userId) {
  await db.collection('identities').updateOne(
    { phone_hash: phoneHash },
    { $set: { user_id: userId } },
    { upsert: true }
  );
}

async function getUserIdByPhoneHash(phoneHash) {
  const doc = await db.collection('identities').findOne({ phone_hash: phoneHash });
  return doc?.user_id ?? null;
}

export const identityRepository = {
  linkPhoneHashToUserId,
  getUserIdByPhoneHash,
};