import { listContent, getContent } from '../repositories/medicalContentRepository.js';
import { listEvents, createEvent } from '../repositories/healthEventRepository.js';
import { getLifeStageState } from '../repositories/lifeStageRepository.js';
import { normalizeLifeStage } from '../domain/lifeStages.js';
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
 * Guided recovery sessions (spec sections 12, 27).
 *
 * The Recovery tab advertised named sessions with durations and both cards
 * were `onTap: () {}` -- no player, no content.
 *
 * Sessions are served from the same reviewed content pipeline as everything
 * else, so an unreviewed session simply does not appear. An empty list is a
 * real answer here, not a reason to invent one.
 */

const SESSION_TYPE = 'recovery_session';

/**
 * Parses the stored step list.
 *
 * A session whose steps cannot be read is dropped rather than shown as an
 * empty shell someone can start and sit through in silence.
 */
function parseSession(entry) {
  let steps = [];
  try {
    const parsed = JSON.parse(entry.body ?? '{}');
    if (Array.isArray(parsed.steps)) {
      steps = parsed.steps
        .filter((step) => step && typeof step.instruction === 'string' && Number.isFinite(step.seconds))
        .map((step) => ({
          instruction: String(step.instruction).slice(0, 300),
          seconds: Math.max(1, Math.min(600, Math.round(step.seconds))),
        }));
    }
  } catch (_) {
    return null;
  }

  if (steps.length === 0) return null;

  return {
    sessionId: entry.contentId,
    title: entry.title,
    summary: entry.summary,
    steps,
    totalSeconds: steps.reduce((sum, step) => sum + step.seconds, 0),
    reviewer: entry.reviewer,
    reviewDate: entry.reviewDate,
    source: entry.source,
  };
}

export const listRecoverySessions = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const stageState = await getLifeStageState(userId);
  const lifeStage = normalizeLifeStage(stageState.lifeStage, null);

  const entries = await listContent({
    contentType: SESSION_TYPE,
    audience: 'female_user',
    approvedOnly: true,
    limit: 50,
  });

  const sessions = entries
    .filter((entry) => {
      const stages = entry.lifeStages ?? [];
      // No stages listed means the session suits anyone.
      return stages.length === 0 || !lifeStage || stages.includes(lifeStage);
    })
    .map(parseSession)
    .filter(Boolean);

  // Which ones have been done, so the app can show that without a second call.
  const completions = await listEvents(userId, {
    eventTypes: ['recovery_session_completed'],
    limit: 100,
  }).catch(() => []);

  const completedCounts = {};
  for (const event of completions) {
    const id = event.payload?.sessionId;
    if (id) completedCounts[id] = (completedCounts[id] ?? 0) + 1;
  }

  return sendData(
    res,
    sessions.map((session) => ({
      ...session,
      timesCompleted: completedCounts[session.sessionId] ?? 0,
    })),
    {
      state: sessions.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
      source: SOURCES.MANUAL,
    },
  );
});

export const getRecoverySession = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const entry = await getContent(req.params.sessionId, { approvedOnly: true });
  if (!entry || entry.contentType !== SESSION_TYPE) {
    return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Session not found.');
  }

  const session = parseSession(entry);
  if (!session) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Session not found.');

  return sendData(res, session, { state: RESPONSE_STATES.READY, source: SOURCES.MANUAL });
});

/**
 * Records that a session was completed.
 *
 * Written as a health event so it reaches the timeline the same way any other
 * logged activity does, rather than being counted only on the device.
 */
export const completeRecoverySession = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const entry = await getContent(req.params.sessionId, { approvedOnly: true });
  if (!entry || entry.contentType !== SESSION_TYPE) {
    return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Session not found.');
  }

  const secondsListened = Number(req.body?.secondsListened ?? 0);

  const result = await createEvent(userId, {
    eventType: 'recovery_session_completed',
    payload: {
      sessionId: entry.contentId,
      title: entry.title,
      secondsListened: Number.isFinite(secondsListened) ? Math.max(0, Math.round(secondsListened)) : 0,
    },
    source: 'manual',
    clientEventId: req.body?.clientEventId ?? null,
  });

  if (!result.ok) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.error ?? 'Could not record that.');
  }

  return sendData(res, { recorded: true, sessionId: entry.contentId }, {
    httpStatus: 201,
    state: RESPONSE_STATES.READY,
    source: SOURCES.MANUAL,
  });
});
