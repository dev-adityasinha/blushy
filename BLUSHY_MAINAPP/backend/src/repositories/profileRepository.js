import { db, findUserDocument } from '../utils/db.js';
import { followRepository } from './followRepository.js';

async function calculateKarma(userId) {
  // Aggregate post scores
  const posts = await db.collection('posts').find({ author_id: userId }).toArray();
  const postsScore = posts.reduce((sum, p) => sum + (p.score ?? 0), 0);

  // Aggregate comment scores
  const comments = await db.collection('comments').find({ author_id: userId }).toArray();
  const commentsScore = comments.reduce((sum, c) => sum + (c.score ?? 0), 0);

  return postsScore + commentsScore;
}

async function getUserProfile(userId, viewerUserId = null) {
  const user = await findUserDocument({ user_id: userId });
  if (!user) return null;

  const displayName = user.onboarding_answers?.preferred_name ?? 'Anonymous';
  
  const profileDoc = await db.collection('user_profiles').findOne({ user_id: userId });
  const bio = profileDoc?.bio ?? '';

  const karma = await calculateKarma(userId);
  const followersCount = await followRepository.getFollowersCount(userId);
  const followingCount = await followRepository.getFollowingCount(userId);
  const isFollowing = viewerUserId ? await followRepository.isFollowing(viewerUserId, userId) : false;

  return {
    userId,
    displayName,
    bio,
    karma,
    followersCount,
    followingCount,
    isFollowing,
  };
}

async function updateUserProfile(userId, { bio }) {
  await db.collection('user_profiles').updateOne(
    { user_id: userId },
    { $set: { bio, updated_at: new Date() } },
    { upsert: true }
  );
  return getUserProfile(userId, userId);
}

export const profileRepository = {
  getUserProfile,
  updateUserProfile,
};
