import { randomUUID } from 'node:crypto';
import { db, findUserDocument } from '../utils/db.js';

async function mapPostRow(row, viewerUserId = null) {
  if (!row) return null;
  
  let userVote = 0;
  if (viewerUserId) {
    const voteDoc = await db.collection('post_votes').findOne({
      user_id: viewerUserId,
      target_id: row.post_id,
    });
    if (voteDoc) {
      userVote = voteDoc.vote_value;
    }
  }

  const author = await findUserDocument({ user_id: row.author_id });
  const display_name = author?.onboarding_answers?.preferred_name ?? 'Anonymous';

  return {
    postId: row.post_id,
    authorId: row.author_id,
    authorName: display_name,
    title: row.title ?? '',
    text: row.text ?? '',
    tags: row.tags ?? [],
    score: row.score ?? 0,
    privacy: row.privacy ?? 'public',
    userVote,
    createdAt: new Date(row.created_at).toISOString(),
    updatedAt: new Date(row.updated_at).toISOString(),
  };
}

async function createPost({ authorId, title, text, tags = [], privacy = 'public' }) {
  const postId = randomUUID();
  const now = new Date();

  const doc = {
    post_id: postId,
    author_id: authorId,
    title: title || '',
    text: text || '',
    tags: tags || [],
    score: 0,
    privacy: privacy === 'private' ? 'private' : 'public',
    reports: [],
    created_at: now,
    updated_at: now,
  };

  await db.collection('posts').insertOne(doc);
  return mapPostRow(doc, authorId);
}

async function getPost(postId, viewerUserId = null) {
  const post = await db.collection('posts').findOne({ post_id: postId });
  if (!post) return null;
  return mapPostRow(post, viewerUserId);
}

async function editPost(postId, authorId, { title, text, tags }) {
  const post = await db.collection('posts').findOne({ post_id: postId });
  if (!post) return null;
  if (post.author_id !== authorId) {
    throw new Error('Unauthorized to edit this post');
  }

  const updateDoc = {
    updated_at: new Date(),
  };
  if (title !== undefined) updateDoc.title = title;
  if (text !== undefined) updateDoc.text = text;
  if (tags !== undefined) updateDoc.tags = tags;

  await db.collection('posts').updateOne(
    { post_id: postId },
    { $set: updateDoc }
  );

  const updated = await db.collection('posts').findOne({ post_id: postId });
  return mapPostRow(updated, authorId);
}

async function deletePost(postId, authorId) {
  const post = await db.collection('posts').findOne({ post_id: postId });
  if (!post) return false;
  if (post.author_id !== authorId) {
    throw new Error('Unauthorized to delete this post');
  }

  await db.collection('posts').deleteOne({ post_id: postId });
  await db.collection('comments').deleteMany({ post_id: postId });
  await db.collection('post_votes').deleteMany({ target_id: postId });
  return true;
}

async function votePost(postId, userId, value) {
  // value can be 1, -1, or 0 (clear vote)
  const voteVal = Number(value);
  if (![1, 0, -1].includes(voteVal)) {
    throw new Error('Invalid vote value');
  }

  const post = await db.collection('posts').findOne({ post_id: postId });
  if (!post) return null;

  const existingVote = await db.collection('post_votes').findOne({
    user_id: userId,
    target_id: postId,
  });

  let scoreDiff = 0;
  if (existingVote) {
    scoreDiff -= existingVote.vote_value;
    if (voteVal === 0) {
      await db.collection('post_votes').deleteOne({
        user_id: userId,
        target_id: postId,
      });
    } else {
      await db.collection('post_votes').updateOne(
        { user_id: userId, target_id: postId },
        { $set: { vote_value: voteVal, updated_at: new Date() } }
      );
      scoreDiff += voteVal;
    }
  } else if (voteVal !== 0) {
    await db.collection('post_votes').insertOne({
      user_id: userId,
      target_id: postId,
      vote_value: voteVal,
      created_at: new Date(),
      updated_at: new Date(),
    });
    scoreDiff += voteVal;
  }

  if (scoreDiff !== 0) {
    await db.collection('posts').updateOne(
      { post_id: postId },
      { $inc: { score: scoreDiff } }
    );
  }

  const updated = await db.collection('posts').findOne({ post_id: postId });
  return mapPostRow(updated, userId);
}

async function reportPost(postId, userId, reason) {
  const post = await db.collection('posts').findOne({ post_id: postId });
  if (!post) return false;

  await db.collection('posts').updateOne(
    { post_id: postId },
    {
      $push: {
        reports: {
          user_id: userId,
          reason: reason || 'Unspecified',
          created_at: new Date(),
        }
      }
    }
  );
  return true;
}

async function listFeed(userId, type = 'home') {
  let query = { privacy: 'public' };

  // If feed is following, filter by followed user IDs
  if (type === 'following') {
    const follows = await db.collection('user_follows').find({ follower_id: userId }).toArray();
    const followedIds = follows.map(f => f.following_id);
    query = { author_id: { $in: followedIds }, privacy: 'public' };
  }

  let sortOption = { created_at: -1 };
  if (type === 'trending' || type === 'popular') {
    sortOption = { score: -1, created_at: -1 };
  }

  const posts = await db.collection('posts').find(query).sort(sortOption).toArray();

  const mappedPosts = [];
  for (const p of posts) {
    mappedPosts.push(await mapPostRow(p, userId));
  }

  return mappedPosts;
}

export const postRepository = {
  createPost,
  getPost,
  editPost,
  deletePost,
  votePost,
  reportPost,
  listFeed,
};

