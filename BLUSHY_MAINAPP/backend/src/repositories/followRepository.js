import { db } from '../utils/db.js';

async function followUser(followerId, followingId) {
  if (followerId === followingId) {
    throw new Error('You cannot follow yourself');
  }

  await db.collection('user_follows').updateOne(
    { follower_id: followerId, following_id: followingId },
    { $setOnInsert: { created_at: new Date() } },
    { upsert: true }
  );
  return true;
}

async function unfollowUser(followerId, followingId) {
  await db.collection('user_follows').deleteOne({
    follower_id: followerId,
    following_id: followingId
  });
  return true;
}

async function isFollowing(followerId, followingId) {
  if (!followerId || !followingId) return false;
  const doc = await db.collection('user_follows').findOne({
    follower_id: followerId,
    following_id: followingId
  });
  return Boolean(doc);
}

async function getFollowersCount(userId) {
  return db.collection('user_follows').countDocuments({ following_id: userId });
}

async function getFollowingCount(userId) {
  return db.collection('user_follows').countDocuments({ follower_id: userId });
}

export const followRepository = {
  followUser,
  unfollowUser,
  isFollowing,
  getFollowersCount,
  getFollowingCount,
};
