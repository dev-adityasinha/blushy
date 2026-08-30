import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';
import { MODERATION_STATES, isVisibleState } from '../domain/communityModeration.js';

/**
 * Community moderation state, blocks and the review queue
 * (spec §12, §22, §27 "Community moderation" and "Audit logs").
 */

const POSTS = 'posts';
const COMMENTS = 'comments';
const BLOCKS = 'community_blocks';
const MODERATION_AUDIT = 'community_moderation_audit';

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

/**
 * Applies the engine's decision to a post. Only ever writes moderation
 * metadata; the post's own content is never altered.
 */
export async function applyModeration(postId, decision, { actorId = 'system' } = {}) {
  const now = new Date();

  await db.collection(POSTS).updateOne(
    { post_id: postId },
    {
      $set: {
        moderation_state: decision.state,
        moderation_reason: decision.reason,
        moderation_notice: decision.notice,
        sensitive_topics: decision.sensitiveTopics,
        claim_signals: decision.claimSignals,
        requires_human_review: decision.requiresHumanReview,
        moderation_ruleset_version: decision.rulesetVersion,
        moderation_updated_at: now,
      },
    },
  );

  await recordModerationAudit(postId, 'evaluated', actorId, {
    state: decision.state,
    reason: decision.reason,
  });

  return decision;
}

/**
 * A moderator decision. Recorded separately from the automatic evaluation so
 * the audit shows who decided what (spec §27).
 */
export async function setModerationState(postId, state, { actorId, action, notes = null }) {
  const existing = await db.collection(POSTS).findOne({ post_id: postId });
  if (!existing) return null;

  await db.collection(POSTS).updateOne(
    { post_id: postId },
    {
      $set: {
        moderation_state: state,
        requires_human_review: false,
        reviewed_by: cleanUserId(actorId),
        reviewed_at: new Date(),
        moderation_updated_at: new Date(),
      },
    },
  );

  await recordModerationAudit(postId, action, actorId, {
    from: existing.moderation_state ?? MODERATION_STATES.VISIBLE,
    to: state,
    notes: notes ? String(notes).slice(0, 1000) : null,
  });

  const updated = await db.collection(POSTS).findOne({ post_id: postId });
  return mapModerationRow(updated);
}

export function mapModerationRow(row) {
  if (!row) return null;
  return {
    postId: row.post_id,
    authorId: row.author_id,
    audience: row.audience ?? 'female_user',
    anonymous: row.anonymous === true,
    title: row.title ?? '',
    text: row.text ?? '',
    moderationState: row.moderation_state ?? MODERATION_STATES.VISIBLE,
    moderationReason: row.moderation_reason ?? null,
    moderationNotice: row.moderation_notice ?? null,
    sensitiveTopics: row.sensitive_topics ?? [],
    claimSignals: row.claim_signals ?? [],
    requiresHumanReview: row.requires_human_review === true,
    rulesetVersion: row.moderation_ruleset_version ?? null,
    reportCount: Array.isArray(row.reports) ? row.reports.length : 0,
    reportReasons: Array.isArray(row.reports) ? row.reports.map((r) => r.reason) : [],
    reviewedBy: row.reviewed_by ?? null,
    reviewedAt: row.reviewed_at ? new Date(row.reviewed_at).toISOString() : null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    isVisible: isVisibleState(row.moderation_state),
  };
}

export async function getModerationView(postId) {
  const row = await db.collection(POSTS).findOne({ post_id: postId });
  return mapModerationRow(row);
}

/**
 * Everything awaiting a human decision, oldest first so nothing is starved.
 */
export async function getReviewQueue({ state = null, limit = 50 } = {}) {
  const query = { requires_human_review: true };
  if (state) query.moderation_state = state;
  const capped = Math.min(limit, 200);

  const [postRows, commentRows] = await Promise.all([
    db.collection(POSTS).find(query).sort({ moderation_updated_at: 1 }).limit(capped).toArray(),
    db.collection(COMMENTS).find(query).sort({ moderation_updated_at: 1 }).limit(capped).toArray(),
  ]);

  // Oldest first across both types, so nothing is starved behind the other.
  return [
    ...postRows.map((row) => ({ ...mapModerationRow(row), targetType: 'post' })),
    ...commentRows.map(mapCommentModerationRow),
  ]
    .sort((a, b) => new Date(a.createdAt ?? 0) - new Date(b.createdAt ?? 0))
    .slice(0, capped);
}

/* ------------------------------------------------------------------ *
 * Comments
 *
 * A treatment claim is no safer for being in a reply, so comments carry the
 * same moderation metadata and appear in the same review queue as posts.
 * ------------------------------------------------------------------ */

export async function applyCommentModeration(commentId, decision, { actorId = 'system' } = {}) {
  const now = new Date();

  await db.collection(COMMENTS).updateOne(
    { comment_id: commentId },
    {
      $set: {
        moderation_state: decision.state,
        moderation_reason: decision.reason,
        moderation_notice: decision.notice,
        sensitive_topics: decision.sensitiveTopics,
        claim_signals: decision.claimSignals,
        requires_human_review: decision.requiresHumanReview,
        moderation_ruleset_version: decision.rulesetVersion,
        moderation_updated_at: now,
      },
    },
  );

  await recordModerationAudit(commentId, 'evaluated', actorId, {
    target: 'comment',
    state: decision.state,
    reason: decision.reason,
  });

  return decision;
}

export async function setCommentModerationState(commentId, state, { actorId, action, notes = null }) {
  const existing = await db.collection(COMMENTS).findOne({ comment_id: commentId });
  if (!existing) return null;

  await db.collection(COMMENTS).updateOne(
    { comment_id: commentId },
    {
      $set: {
        moderation_state: state,
        requires_human_review: false,
        reviewed_by: cleanUserId(actorId),
        reviewed_at: new Date(),
        moderation_updated_at: new Date(),
      },
    },
  );

  await recordModerationAudit(commentId, action, actorId, {
    target: 'comment',
    from: existing.moderation_state ?? MODERATION_STATES.VISIBLE,
    to: state,
    notes: notes ? String(notes).slice(0, 1000) : null,
  });

  const updated = await db.collection(COMMENTS).findOne({ comment_id: commentId });
  return mapCommentModerationRow(updated);
}

export function mapCommentModerationRow(row) {
  if (!row) return null;
  return {
    targetType: 'comment',
    commentId: row.comment_id,
    postId: row.post_id,
    authorId: row.author_id,
    text: row.text ?? '',
    moderationState: row.moderation_state ?? MODERATION_STATES.VISIBLE,
    moderationReason: row.moderation_reason ?? null,
    moderationNotice: row.moderation_notice ?? null,
    sensitiveTopics: row.sensitive_topics ?? [],
    claimSignals: row.claim_signals ?? [],
    requiresHumanReview: row.requires_human_review === true,
    reportCount: Array.isArray(row.reports) ? row.reports.length : 0,
    reportReasons: Array.isArray(row.reports) ? row.reports.map((r) => r.reason) : [],
    reviewedBy: row.reviewed_by ?? null,
    reviewedAt: row.reviewed_at ? new Date(row.reviewed_at).toISOString() : null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    isVisible: isVisibleState(row.moderation_state),
  };
}

export async function getCommentModerationView(commentId) {
  const row = await db.collection(COMMENTS).findOne({ comment_id: commentId });
  return mapCommentModerationRow(row);
}

export async function reportComment(commentId, userId, reason) {
  const existing = await db.collection(COMMENTS).findOne({ comment_id: commentId });
  if (!existing) return false;

  await db.collection(COMMENTS).updateOne(
    { comment_id: commentId },
    { $push: { reports: { user_id: cleanUserId(userId), reason, created_at: new Date() } } },
  );
  return true;
}

/* ------------------------------------------------------------------ *
 * Blocks (spec §12 "Report, block and moderation workflows")
 * ------------------------------------------------------------------ */

export async function blockUser(blockerUserId, blockedUserId) {
  const blocker = cleanUserId(blockerUserId);
  const blocked = cleanUserId(blockedUserId);
  if (blocker === blocked) return { ok: false, error: 'You cannot block yourself.' };

  await db.collection(BLOCKS).updateOne(
    { blocker_user_id: blocker, blocked_user_id: blocked },
    { $setOnInsert: { block_id: randomUUID(), blocker_user_id: blocker, blocked_user_id: blocked, created_at: new Date() } },
    { upsert: true },
  );

  return { ok: true };
}

export async function unblockUser(blockerUserId, blockedUserId) {
  const result = await db.collection(BLOCKS).deleteOne({
    blocker_user_id: cleanUserId(blockerUserId),
    blocked_user_id: cleanUserId(blockedUserId),
  });
  return { ok: result.deletedCount > 0 };
}

export async function getBlockedAuthorIds(viewerUserId) {
  const rows = await db.collection(BLOCKS)
    .find({ blocker_user_id: cleanUserId(viewerUserId) })
    .toArray();
  return rows.map((row) => row.blocked_user_id);
}

/**
 * Blocking is mutual for visibility: neither side sees the other's posts, so
 * blocking someone does not leave the blocker exposed to them.
 */
export async function getMutuallyBlockedIds(viewerUserId) {
  const uid = cleanUserId(viewerUserId);
  const rows = await db.collection(BLOCKS)
    .find({ $or: [{ blocker_user_id: uid }, { blocked_user_id: uid }] })
    .toArray();

  const ids = new Set();
  for (const row of rows) {
    ids.add(row.blocker_user_id === uid ? row.blocked_user_id : row.blocker_user_id);
  }
  return [...ids];
}

/* ------------------------------------------------------------------ *
 * Audit
 * ------------------------------------------------------------------ */

async function recordModerationAudit(postId, action, actorId, details = null) {
  await db.collection(MODERATION_AUDIT).insertOne({
    audit_id: randomUUID(),
    post_id: postId,
    action,
    actor_id: actorId ?? 'system',
    details,
    created_at: new Date(),
  });
}

export async function getModerationAudit(postId, limit = 50) {
  const rows = await db.collection(MODERATION_AUDIT)
    .find({ post_id: postId })
    .sort({ created_at: -1 })
    .limit(Math.min(limit, 200))
    .toArray();

  return rows.map((row) => ({
    auditId: row.audit_id,
    postId: row.post_id,
    action: row.action,
    actorId: row.actor_id,
    details: row.details ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  }));
}
