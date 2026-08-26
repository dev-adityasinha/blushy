import { randomUUID } from 'node:crypto';
import { db, findUserDocument } from '../utils/db.js';

async function mapCommentRow(row, viewerUserId = null) {
  if (!row) return null;

  let userVote = 0;
  if (viewerUserId) {
    const voteDoc = await db.collection('comment_votes').findOne({
      user_id: viewerUserId,
      target_id: row.comment_id,
    });
    if (voteDoc) {
      userVote = voteDoc.vote_value;
    }
  }

  const author = await findUserDocument({ user_id: row.author_id });
  const display_name = author?.onboarding_answers?.preferred_name ?? 'Anonymous';

  return {
    commentId: row.comment_id,
    postId: row.post_id,
    parentId: row.parent_id ?? null,
    authorId: row.author_id,
    authorName: display_name,
    text: row.text,
    score: row.score ?? 0,
    userVote,
    createdAt: new Date(row.created_at).toISOString(),
    updatedAt: new Date(row.updated_at).toISOString(),
  };
}

async function createComment({ postId, parentId = null, authorId, text }) {
  const commentId = randomUUID();
  const now = new Date();

  const doc = {
    comment_id: commentId,
    post_id: postId,
    parent_id: parentId || null,
    author_id: authorId,
    text,
    score: 0,
    created_at: now,
    updated_at: now,
  };

  await db.collection('comments').insertOne(doc);
  return mapCommentRow(doc, authorId);
}

async function editComment(commentId, authorId, text) {
  const comment = await db.collection('comments').findOne({ comment_id: commentId });
  if (!comment) return null;
  if (comment.author_id !== authorId) {
    throw new Error('Unauthorized to edit this comment');
  }

  await db.collection('comments').updateOne(
    { comment_id: commentId },
    { $set: { text, updated_at: new Date() } }
  );

  const updated = await db.collection('comments').findOne({ comment_id: commentId });
  return mapCommentRow(updated, authorId);
}

async function deleteComment(commentId, authorId) {
  const comment = await db.collection('comments').findOne({ comment_id: commentId });
  if (!comment) return false;
  if (comment.author_id !== authorId) {
    throw new Error('Unauthorized to delete this comment');
  }

  // Set text as [deleted] to preserve threaded children structure like Reddit
  await db.collection('comments').updateOne(
    { comment_id: commentId },
    { $set: { text: '[deleted]', updated_at: new Date() } }
  );
  return true;
}

async function voteComment(commentId, userId, value) {
  const voteVal = Number(value);
  if (![1, 0, -1].includes(voteVal)) {
    throw new Error('Invalid vote value');
  }

  const comment = await db.collection('comments').findOne({ comment_id: commentId });
  if (!comment) return null;

  const existingVote = await db.collection('comment_votes').findOne({
    user_id: userId,
    target_id: commentId,
  });

  let scoreDiff = 0;
  if (existingVote) {
    scoreDiff -= existingVote.vote_value;
    if (voteVal === 0) {
      await db.collection('comment_votes').deleteOne({
        user_id: userId,
        target_id: commentId,
      });
    } else {
      await db.collection('comment_votes').updateOne(
        { user_id: userId, target_id: commentId },
        { $set: { vote_value: voteVal, updated_at: new Date() } }
      );
      scoreDiff += voteVal;
    }
  } else if (voteVal !== 0) {
    await db.collection('comment_votes').insertOne({
      user_id: userId,
      target_id: commentId,
      vote_value: voteVal,
      created_at: new Date(),
      updated_at: new Date(),
    });
    scoreDiff += voteVal;
  }

  if (scoreDiff !== 0) {
    await db.collection('comments').updateOne(
      { comment_id: commentId },
      { $inc: { score: scoreDiff } }
    );
  }

  const updated = await db.collection('comments').findOne({ comment_id: commentId });
  return mapCommentRow(updated, userId);
}

async function listComments(postId, viewerUserId = null, sort = 'top') {
  let sortOption = { score: -1, created_at: -1 };
  if (sort === 'new') {
    sortOption = { created_at: -1 };
  } else if (sort === 'controversial') {
    sortOption = { score: 1, created_at: -1 };
  }

  const comments = await db.collection('comments')
    .find({ post_id: postId })
    .sort(sortOption)
    .toArray();

  const mapped = [];
  for (const c of comments) {
    mapped.push(await mapCommentRow(c, viewerUserId));
  }

  return mapped;
}

export const commentRepository = {
  createComment,
  editComment,
  deleteComment,
  voteComment,
  listComments,
};
