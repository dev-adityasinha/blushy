import {
  moderateNewPost,
  moderateAfterReport,
  applyModeratorAction,
  getReviewQueue,
  getModerationView,
  getCommentModerationView,
  moderateCommentAfterReport,
  applyCommentModeratorAction,
  getModerationAudit,
  blockUser,
  unblockUser,
  MODERATION_RULESET_VERSION,
} from '../services/moderationService.js';
import {
  REPORT_REASONS,
  MODERATOR_ACTIONS,
  MODERATION_STATES,
  isValidReportReason,
  isValidModeratorAction,
  SENSITIVE_TOPICS,
} from '../domain/communityModeration.js';
import { getMutuallyBlockedIds } from '../repositories/moderationRepository.js';
import {
  sendData,
  sendError,
  resolveUserId,
  contractHandler,
  RESPONSE_STATES,
  ERROR_CODES,
  SOURCES,
} from '../utils/apiResponse.js';

/**
 * Community moderation API (spec §12, §22, §27).
 */

export const getModerationConfig = contractHandler(async (_req, res) => {
  return sendData(res, {
    reportReasons: REPORT_REASONS,
    moderatorActions: Object.keys(MODERATOR_ACTIONS),
    moderationStates: Object.values(MODERATION_STATES),
    // The topics the spec asks for extra safeguards around (§12).
    sensitiveTopics: Object.keys(SENSITIVE_TOPICS),
  }, {
    state: RESPONSE_STATES.READY,
    version: MODERATION_RULESET_VERSION,
    source: SOURCES.RULE,
  });
});

/**
 * Re-runs moderation for a post the caller just created or edited.
 */
export const evaluatePostModeration = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { title = '', text = '' } = req.body ?? {};
  const decision = await moderateNewPost(req.params.postId, { title, text, role: req.user?.role });

  return sendData(res, decision, {
    state: RESPONSE_STATES.READY,
    version: decision.rulesetVersion,
    source: SOURCES.RULE,
  });
});

/**
 * Records a report and re-evaluates. Reports never remove a post directly.
 */
export const reportForModeration = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const reason = req.body?.reason;
  if (!isValidReportReason(reason)) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, `reason must be one of: ${REPORT_REASONS.join(', ')}.`);
  }

  const view = await moderateAfterReport(req.params.postId);
  if (!view) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Post not found.');

  return sendData(res, {
    postId: view.postId,
    moderationState: view.moderationState,
    requiresHumanReview: view.requiresHumanReview,
    // The reporter is told it was received, not what the outcome will be.
    acknowledged: true,
  }, {
    state: RESPONSE_STATES.READY,
    version: MODERATION_RULESET_VERSION,
    source: SOURCES.RULE,
  });
});

export const getPostModeration = contractHandler(async (req, res) => {
  const view = await getModerationView(req.params.postId);
  if (!view) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Post not found.');

  return sendData(res, view, {
    state: RESPONSE_STATES.READY,
    version: view.rulesetVersion ?? MODERATION_RULESET_VERSION,
    source: SOURCES.RULE,
  });
});

/* ------------------------------------------------------------------ *
 * Blocks
 * ------------------------------------------------------------------ */

export const blockCommunityUser = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await blockUser(userId, req.params.userId);
  if (!result.ok) return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.error);

  return sendData(res, { blocked: req.params.userId }, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export const unblockCommunityUser = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  await unblockUser(userId, req.params.userId);
  return sendData(res, { unblocked: req.params.userId }, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export const listBlocked = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const blocked = await getMutuallyBlockedIds(userId);
  return sendData(res, blocked, {
    state: blocked.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.MANUAL,
  });
});

/* ------------------------------------------------------------------ *
 * Moderator queue (admin)
 * ------------------------------------------------------------------ */

export const getQueue = contractHandler(async (req, res) => {
  const queue = await getReviewQueue({ state: req.query.state ?? null });
  return sendData(res, queue, {
    state: queue.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: MODERATION_RULESET_VERSION,
    source: SOURCES.RULE,
    meta: { awaitingCount: queue.length },
  });
});

export const moderatePost = contractHandler(async (req, res) => {
  const actorId = resolveUserId(req);
  const { action, notes = null } = req.body ?? {};

  if (!isValidModeratorAction(action)) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED,
      `action must be one of: ${Object.keys(MODERATOR_ACTIONS).join(', ')}.`);
  }

  const result = await applyModeratorAction(req.params.postId, action, { actorId, notes });
  if (result.notFound) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Post not found.');
  if (!result.ok) return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.error);

  return sendData(res, result.post, {
    state: RESPONSE_STATES.READY,
    version: MODERATION_RULESET_VERSION,
    source: SOURCES.RULE,
  });
});

export const getPostAudit = contractHandler(async (req, res) => {
  const audit = await getModerationAudit(req.params.postId);
  return sendData(res, audit, {
    state: audit.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.RULE,
  });
});

/* ------------------------------------------------------------------ *
 * Comments (spec §12, §22)
 * ------------------------------------------------------------------ */

export const reportCommentForModeration = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const reason = req.body?.reason;
  if (!isValidReportReason(reason)) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, `reason must be one of: ${REPORT_REASONS.join(', ')}.`);
  }

  const view = await moderateCommentAfterReport(req.params.commentId, { userId, reason });
  if (!view) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Comment not found.');

  return sendData(res, {
    commentId: view.commentId,
    moderationState: view.moderationState,
    requiresHumanReview: view.requiresHumanReview,
    acknowledged: true,
  }, {
    state: RESPONSE_STATES.READY,
    version: MODERATION_RULESET_VERSION,
    source: SOURCES.RULE,
  });
});

export const getCommentModeration = contractHandler(async (req, res) => {
  const view = await getCommentModerationView(req.params.commentId);
  if (!view) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Comment not found.');

  return sendData(res, view, {
    state: RESPONSE_STATES.READY,
    version: MODERATION_RULESET_VERSION,
    source: SOURCES.RULE,
  });
});

export const moderateComment = contractHandler(async (req, res) => {
  const actorId = resolveUserId(req);
  const { action, notes = null } = req.body ?? {};

  if (!isValidModeratorAction(action)) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED,
      `action must be one of: ${Object.keys(MODERATOR_ACTIONS).join(', ')}.`);
  }

  const result = await applyCommentModeratorAction(req.params.commentId, action, { actorId, notes });
  if (result.notFound) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Comment not found.');
  if (!result.ok) return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.error);

  return sendData(res, result.comment, {
    state: RESPONSE_STATES.READY,
    version: MODERATION_RULESET_VERSION,
    source: SOURCES.RULE,
  });
});
