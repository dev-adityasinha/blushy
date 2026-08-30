import {
  listContent,
  getContent,
  createContent,
  updateContent,
  setContentStatus,
  emergencyRetire,
  getReviewQueue,
  getContentAudit,
  countContent,
  CONTENT_STATES,
} from '../repositories/medicalContentRepository.js';
import {
  upsertProgress,
  setBookmark,
  getProgressMap,
  listBookmarks,
  listCompleted,
} from '../repositories/contentProgressRepository.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { normalizeLifeStage } from '../domain/lifeStages.js';
import { recordAnalyticsEvent } from '../repositories/auditRepository.js';
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
 * M Studio / Learn and the medical content service
 * (spec §13 "M Studio / Learn", §17 "Medical Content System",
 * §23 "M STUDIO / LEARN FUNCTIONALITY", §27 admin operations).
 *
 * Reads only ever return approved content. Community content lives in a
 * different collection and never appears here.
 */

const LIBRARY_VERSION = 'content-library-v1.0.0';

function audienceForRole(role) {
  return role === 'man' || role === 'partner' ? 'partner' : 'female_user';
}

/**
 * Library listing. Defaults to the caller's own life stage and audience so
 * Partner Learn automatically receives partner-tagged content.
 */
export const browseLibrary = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  const role = req.user?.role;
  const audience = req.query.audience ?? audienceForRole(role);

  let lifeStage = req.query.lifeStage ?? null;
  if (!lifeStage && userId) {
    const stageState = await getLifeStageState(userId);
    lifeStage = normalizeLifeStage(stageState.lifeStage, null);
  }

  const limit = Math.min(Number(req.query.limit) || 20, 50);
  const skip = Math.max(Number(req.query.skip) || 0, 0);

  const items = await listContent({
    lifeStage: lifeStage ?? null,
    topic: req.query.topic ?? null,
    audience,
    locale: req.query.locale ?? null,
    contentType: req.query.contentType ?? null,
    search: req.query.search ?? null,
    approvedOnly: true,
    limit,
    skip,
  });

  const progress = userId ? await getProgressMap(userId, items.map((item) => item.contentId)) : {};

  const decorated = items.map((item) => ({
    ...item,
    progress: progress[item.contentId] ?? { progressPercent: 0, completed: false, bookmarked: false },
  }));

  return sendData(res, decorated, {
    state: decorated.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: LIBRARY_VERSION,
    source: SOURCES.MEDICAL_REFERENCE,
    meta: { pagination: { limit, skip, hasMore: decorated.length === limit }, audience, lifeStage },
  });
});

export const getLibraryItem = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  const item = await getContent(req.params.contentId, { approvedOnly: true });

  if (!item) {
    return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Content not found or not approved for use.');
  }

  const progress = userId ? await getProgressMap(userId, [item.contentId]) : {};
  if (userId) {
    await upsertProgress(userId, item.contentId, { opened: true });
  }

  return sendData(res, {
    ...item,
    progress: progress[item.contentId] ?? { progressPercent: 0, completed: false, bookmarked: false },
  }, {
    state: RESPONSE_STATES.READY,
    version: item.version,
    source: SOURCES.MEDICAL_REFERENCE,
    lastUpdated: item.updatedAt,
  });
});

export const saveProgress = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { progressPercent, positionSeconds, completed } = req.body ?? {};
  const record = await upsertProgress(userId, req.params.contentId, { progressPercent, positionSeconds, completed });

  if (completed) {
    await recordAnalyticsEvent({
      userId,
      pseudonymousId: null,
      eventName: 'article_completed',
      properties: { contentId: req.params.contentId },
    });
  }

  return sendData(res, record, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export const toggleBookmark = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  if (typeof req.body?.bookmarked !== 'boolean') {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'bookmarked must be a boolean.');
  }

  const record = await setBookmark(userId, req.params.contentId, req.body.bookmarked);
  return sendData(res, record, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

export const getSaved = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const bookmarks = await listBookmarks(userId);
  const items = await Promise.all(bookmarks.map((row) => getContent(row.contentId, { approvedOnly: true })));
  const merged = bookmarks
    .map((row, index) => (items[index] ? { ...items[index], progress: row } : null))
    .filter(Boolean);

  return sendData(res, merged, {
    state: merged.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: LIBRARY_VERSION,
    source: SOURCES.MEDICAL_REFERENCE,
  });
});

export const getCompletedContent = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const rows = await listCompleted(userId);
  return sendData(res, rows, {
    state: rows.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.MANUAL,
  });
});

/**
 * Recommendations. Deterministic: current life stage, then unread items,
 * ranked by recency. No AI ranking is applied to clinical content.
 */
export const getRecommendations = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const stageState = await getLifeStageState(userId);
  const lifeStage = normalizeLifeStage(stageState.lifeStage, null);
  const audience = audienceForRole(req.user?.role);

  const candidates = await listContent({ lifeStage, audience, approvedOnly: true, limit: 30 });
  const progress = await getProgressMap(userId, candidates.map((item) => item.contentId));

  const unread = candidates.filter((item) => !progress[item.contentId]?.completed).slice(0, 8);

  return sendData(res, unread, {
    state: unread.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: LIBRARY_VERSION,
    source: SOURCES.MEDICAL_REFERENCE,
    meta: { lifeStage, audience, rankingMethod: 'life_stage_then_unread' },
  });
});

/* ------------------------------------------------------------------ *
 * Admin: clinical content management (spec §17, §27)
 * ------------------------------------------------------------------ */

export const adminListContent = contractHandler(async (req, res) => {
  const items = await listContent({
    status: req.query.status ?? null,
    approvedOnly: false,
    audience: req.query.audience ?? null,
    lifeStage: req.query.lifeStage ?? null,
    search: req.query.search ?? null,
    limit: Math.min(Number(req.query.limit) || 50, 100),
    skip: Math.max(Number(req.query.skip) || 0, 0),
  });

  const total = await countContent({ status: req.query.status ?? null });

  return sendData(res, items, {
    state: items.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: LIBRARY_VERSION,
    source: SOURCES.MEDICAL_REFERENCE,
    meta: { total },
  });
});

export const adminCreateContent = contractHandler(async (req, res) => {
  const actorId = resolveUserId(req);
  const { title, body } = req.body ?? {};
  if (!title || !body) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'title and body are required.');
  }

  const content = await createContent(req.body, actorId);
  return sendData(res, content, { httpStatus: 201, state: RESPONSE_STATES.READY, version: content.version, source: SOURCES.MEDICAL_REFERENCE });
});

export const adminUpdateContent = contractHandler(async (req, res) => {
  const actorId = resolveUserId(req);
  const content = await updateContent(req.params.contentId, req.body ?? {}, actorId);
  if (!content) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Content not found.');

  return sendData(res, content, { state: RESPONSE_STATES.READY, version: content.version, source: SOURCES.MEDICAL_REFERENCE });
});

export const adminSetStatus = contractHandler(async (req, res) => {
  const actorId = resolveUserId(req);
  const { status, reviewer = null, reviewDate = null } = req.body ?? {};

  const result = await setContentStatus(req.params.contentId, status, actorId, { reviewer, reviewDate });
  if (result.notFound) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Content not found.');
  if (!result.ok) return sendError(res, 409, ERROR_CODES.CONFLICT, result.error);

  return sendData(res, result.content, { state: RESPONSE_STATES.READY, version: result.content.version, source: SOURCES.MEDICAL_REFERENCE });
});

export const adminEmergencyRetire = contractHandler(async (req, res) => {
  const actorId = resolveUserId(req);
  const result = await emergencyRetire(req.params.contentId, actorId, req.body?.reason ?? null);
  if (result.notFound) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Content not found.');

  return sendData(res, result.content, { state: RESPONSE_STATES.READY, source: SOURCES.MEDICAL_REFERENCE });
});

export const adminReviewQueue = contractHandler(async (_req, res) => {
  const queue = await getReviewQueue();
  const total = queue.awaitingReview.length + queue.reviewOverdue.length;

  return sendData(res, queue, {
    state: total > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: LIBRARY_VERSION,
    source: SOURCES.MEDICAL_REFERENCE,
    meta: { awaitingCount: queue.awaitingReview.length, overdueCount: queue.reviewOverdue.length },
  });
});

export const adminContentAudit = contractHandler(async (req, res) => {
  const audit = await getContentAudit(req.params.contentId);
  return sendData(res, audit, {
    state: audit.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    source: SOURCES.MEDICAL_REFERENCE,
  });
});

export { CONTENT_STATES };
