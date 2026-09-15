import {
  evaluatePost,
  evaluateComment,
  canView,
  audienceForRole,
  defaultAnonymity,
  MODERATOR_ACTIONS,
  MODERATION_STATES,
  MODERATION_RULESET_VERSION,
  isVisibleState,
} from '../domain/communityModeration.js';
import {
  applyModeration,
  applyCommentModeration,
  setModerationState,
  setCommentModerationState,
  getCommentModerationView,
  reportComment,
  getModerationView,
  getReviewQueue,
  getMutuallyBlockedIds,
  blockUser,
  unblockUser,
  getModerationAudit,
} from '../repositories/moderationRepository.js';
import { db } from '../utils/db.js';

/**
 * Community moderation (spec §12, §22, §27).
 *
 * Every post is evaluated on write and on report. The engine can hold content
 * for review and attach a notice, but only a human clears or removes it.
 */

/**
 * Called after a post is created or edited. Stores the audience and anonymity
 * defaults alongside the moderation decision.
 */
export async function moderateNewPost(postId, { title, text, role }) {
  const audience = audienceForRole(role);

  await db.collection('posts').updateOne(
    { post_id: postId },
    {
      $set: {
        audience,
        // The partner community is anonymous by default (spec §12).
        anonymous: defaultAnonymity(audience),
      },
    },
  );

  const decision = evaluatePost({ title, text, reportCount: 0, reportReasons: [] });
  await applyModeration(postId, decision, { actorId: 'system' });
  return decision;
}

/**
 * Re-evaluates after a report. Reports raise the stakes but never remove a
 * post on their own.
 */
export async function moderateAfterReport(postId) {
  const row = await db.collection('posts').findOne({ post_id: postId });
  if (!row) return null;

  const reports = Array.isArray(row.reports) ? row.reports : [];
  const decision = evaluatePost({
    title: row.title,
    text: row.text,
    reportCount: reports.length,
    reportReasons: reports.map((r) => r.reason),
  });

  // A human decision already made on this post is not overwritten by the
  // engine; only a new report threshold can pull it back into the queue.
  if (row.reviewed_by && !decision.requiresHumanReview) {
    return getModerationView(postId);
  }

  await applyModeration(postId, decision, { actorId: 'system' });
  return getModerationView(postId);
}

/**
 * Filters a list of posts for one viewer: audience separation, blocks and
 * moderation state, applied server side.
 */
export async function filterForViewer(posts, { viewerUserId, viewerRole, isModerator = false }) {
  const viewerAudience = audienceForRole(viewerRole);
  const blocked = viewerUserId ? await getMutuallyBlockedIds(viewerUserId) : [];

  return posts
    .filter((post) => canView({
      post: {
        authorId: post.authorId ?? post.author_id,
        audience: post.audience ?? 'female_user',
        moderationState: post.moderationState ?? post.moderation_state ?? MODERATION_STATES.VISIBLE,
      },
      viewerUserId,
      viewerAudience,
      blockedAuthorIds: blocked,
      isModerator,
    }))
    .map((post) => {
      const anonymous = (post.anonymous ?? post.anonymous === true) === true;
      return {
        ...post,
        // Anonymity is applied here, not in the client, so an author id never
        // reaches a partner-community reader.
        authorId: anonymous ? null : (post.authorId ?? post.author_id),
        authorName: anonymous ? 'Community member' : post.authorName,
        moderationNotice: post.moderationNotice ?? post.moderation_notice ?? null,
        isClinicallyReviewed: false,
      };
    });
}

/**
 * Comments go through the same rules as posts (spec §12, §22).
 */
export async function moderateNewComment(commentId, { text }) {
  const decision = evaluateComment({ text });
  await applyCommentModeration(commentId, decision, { actorId: 'system' });
  return decision;
}

export async function moderateCommentAfterReport(commentId, { userId, reason }) {
  const recorded = await reportComment(commentId, userId, reason);
  if (!recorded) return null;

  const view = await getCommentModerationView(commentId);
  const decision = evaluateComment({
    text: view.text,
    reportCount: view.reportCount,
    reportReasons: view.reportReasons,
  });

  // A human decision is not overwritten by the engine unless a new report
  // threshold pulls it back into the queue.
  if (view.reviewedBy && !decision.requiresHumanReview) return view;

  await applyCommentModeration(commentId, decision, { actorId: 'system' });
  return getCommentModerationView(commentId);
}

/**
 * Hides comments held for review or written by a blocked author. The author
 * keeps sight of their own held comment.
 */
export async function filterCommentsForViewer(comments, { viewerUserId, isModerator = false }) {
  const blocked = viewerUserId ? await getMutuallyBlockedIds(viewerUserId) : [];

  return comments
    .filter((comment) => {
      if (isModerator) return true;
      const state = comment.moderationState ?? comment.moderation_state ?? MODERATION_STATES.VISIBLE;
      const authorId = comment.authorId ?? comment.author_id;

      if (authorId === viewerUserId) return state !== MODERATION_STATES.REMOVED;
      if (blocked.includes(authorId)) return false;
      return isVisibleState(state);
    })
    .map((comment) => ({
      ...comment,
      moderationNotice: comment.moderationNotice ?? comment.moderation_notice ?? null,
      isClinicallyReviewed: false,
    }));
}

export async function applyCommentModeratorAction(commentId, action, { actorId, notes = null }) {
  const nextState = MODERATOR_ACTIONS[action];
  if (!nextState) return { ok: false, error: `Unknown moderator action: ${action}.` };

  const updated = await setCommentModerationState(commentId, nextState, { actorId, action, notes });
  if (!updated) return { ok: false, notFound: true };

  return { ok: true, comment: updated };
}

export async function applyModeratorAction(postId, action, { actorId, notes = null }) {
  const nextState = MODERATOR_ACTIONS[action];
  if (!nextState) {
    return { ok: false, error: `Unknown moderator action: ${action}.` };
  }

  const updated = await setModerationState(postId, nextState, { actorId, action, notes });
  if (!updated) return { ok: false, notFound: true };

  return { ok: true, post: updated };
}

export {
  getReviewQueue,
  getModerationView,
  getCommentModerationView,
  getModerationAudit,
  blockUser,
  unblockUser,
  MODERATION_RULESET_VERSION,
};
