import { randomUUID } from 'node:crypto';
import { db, findUserDocument } from '../utils/db.js';

function mapPostRow(row) {
  if (!row) return null;
  return {
    postId: row.post_id,
    authorId: row.author_id,
    authorName: row.display_name ?? 'Anonymous',
    text: row.text,
    imageUrl: row.image_url,
    privacy: row.privacy,
    createdAt: new Date(row.created_at).toISOString(),
    updatedAt: new Date(row.updated_at).toISOString(),
  };
}

async function createPost({ authorId, text, imageUrl, privacy }) {
  const postId = randomUUID();
  const safePrivacy = privacy === 'private' ? 'private' : 'public';
  const now = new Date();

  const doc = {
    post_id: postId,
    author_id: authorId,
    text,
    image_url: imageUrl,
    privacy: safePrivacy,
    created_at: now,
    updated_at: now,
  };

  await db.collection('posts').insertOne(doc);

  const author = await findUserDocument({ user_id: authorId });
  const display_name = author?.onboarding_answers?.preferred_name;

  return mapPostRow({
    ...doc,
    display_name,
  });
}

async function listFeed(userId) {
  const friendships = await db.collection('friendships').find({
    $or: [
      { user_id_1: userId },
      { user_id_2: userId }
    ],
    status: 'accepted'
  }).toArray();

  const friendIds = friendships.map(f => f.user_id_1 === userId ? f.user_id_2 : f.user_id_1);

  const posts = await db.collection('posts').find({
    $or: [
      { privacy: 'public' },
      { author_id: userId },
      { privacy: 'private', author_id: { $in: friendIds } }
    ]
  }).sort({ created_at: -1 }).toArray();

  const mappedPosts = [];
  for (const p of posts) {
    const author = await findUserDocument({ user_id: p.author_id });
    mappedPosts.push(mapPostRow({
      ...p,
      display_name: author?.onboarding_answers?.preferred_name
    }));
  }

  return mappedPosts;
}

export const postRepository = {
  createPost,
  listFeed,
};
