import {
  createEvent,
  listEvents,
  updateEvent,
  deleteEvent,
  getEventById,
  countEvents,
} from '../repositories/healthEventRepository.js';
import { EVENT_TYPE_KEYS, EVENT_SOURCES, EVENT_TYPES, getInvalidationTargets } from '../domain/healthEvents.js';
import { handleEventsDeleted } from '../services/insightService.js';
import { buildTimeline } from '../services/timelineService.js';
import { cancelForEntity } from '../repositories/notificationRepository.js';
import { evaluateUserSafety, buildSafetyFlow } from '../services/safetyService.js';
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
 * Health event API (spec §6 "Logging System", §7 "CHECK IN CARDS",
 * §11 "TIMELINES", §25 "Offline & Sync").
 *
 * Every check-in card on the frontend posts here. The response returns the
 * canonical saved record so the frontend can replace its optimistic state
 * (spec §7 steps 4-5), and writes are idempotent via `clientEventId`.
 */

const EVENTS_VERSION = 'events-v1.0.0';

export const getEventSchema = contractHandler(async (req, res) => {
  const schema = EVENT_TYPE_KEYS.map((key) => ({
    eventType: key,
    invalidates: EVENT_TYPES[key].invalidates,
  }));

  return sendData(res, { eventTypes: schema, sources: EVENT_SOURCES }, {
    state: RESPONSE_STATES.READY,
    version: EVENTS_VERSION,
    source: SOURCES.RULE,
  });
});

export const logEvent = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const { eventType, payload, timestamp, source, clientEventId } = req.body ?? {};

  const result = await createEvent(userId, {
    eventType,
    payload,
    timestamp,
    source: source ?? 'manual',
    // Idempotency key from the offline queue (spec §29 "Idempotency for
    // create/log endpoints").
    clientEventId: clientEventId ?? req.get('idempotency-key') ?? null,
  });

  if (!result.ok) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.error, { field: result.field });
  }

  // Symptom, pain and mood writes are re-checked against the red flag rules
  // straight away (spec §15).
  let safety = null;
  if (['symptom_logged', 'pain_logged', 'mood_logged'].includes(eventType)) {
    const evaluation = await evaluateUserSafety(userId, { surface: 'event_log' });
    if (evaluation.triggered) {
      const flow = await buildSafetyFlow(evaluation);
      safety = flow.data;
    }
  }

  if (eventType === 'period_logged') {
    await recordAnalyticsEvent({ userId, pseudonymousId: null, eventName: 'period_logged', properties: { source: result.event.source } });
  }

  return sendData(res, {
    event: result.event,
    deduplicated: result.deduplicated,
    invalidates: getInvalidationTargets(eventType),
    safety,
  }, {
    httpStatus: result.deduplicated ? 200 : 201,
    state: RESPONSE_STATES.READY,
    version: EVENTS_VERSION,
    source: result.event.source,
    lastUpdated: result.event.updatedAt,
  });
});

export const getEvents = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const eventTypes = typeof req.query.eventTypes === 'string'
    ? req.query.eventTypes.split(',').map((t) => t.trim()).filter(Boolean)
    : null;

  const limit = Math.min(Number(req.query.limit) || 100, 500);
  const skip = Math.max(Number(req.query.skip) || 0, 0);

  const events = await listEvents(userId, {
    eventTypes,
    from: req.query.from ?? null,
    to: req.query.to ?? null,
    limit,
    skip,
  });

  const total = await countEvents(userId, { eventTypes, from: req.query.from ?? null, to: req.query.to ?? null });

  return sendData(res, events, {
    state: events.length > 0 ? RESPONSE_STATES.READY : RESPONSE_STATES.EMPTY,
    version: EVENTS_VERSION,
    source: SOURCES.MANUAL,
    meta: { pagination: { limit, skip, total, hasMore: skip + events.length < total } },
  });
});

export const getEvent = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const event = await getEventById(userId, req.params.eventId);
  if (!event) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Event not found.');

  return sendData(res, event, { state: RESPONSE_STATES.READY, version: EVENTS_VERSION, source: event.source });
});

export const editEvent = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await updateEvent(userId, req.params.eventId, {
    payload: req.body?.payload,
    timestamp: req.body?.timestamp,
    source: req.body?.source,
  });

  if (result.notFound) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Event not found.');
  if (!result.ok) return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, result.error, { field: result.field });

  // An edit changes the evidence, so dependent insights are recalculated
  // (spec §6 "Deleted source logs must invalidate or recalculate dependent
  // insights" - the same applies to edits).
  const recalculation = await handleEventsDeleted(userId, [result.event.eventId]);

  return sendData(res, { event: result.event, recalculation }, {
    state: RESPONSE_STATES.READY,
    version: EVENTS_VERSION,
    source: result.event.source,
    lastUpdated: result.event.updatedAt,
  });
});

export const removeEvent = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const result = await deleteEvent(userId, req.params.eventId);
  if (!result.ok) return sendError(res, 404, ERROR_CODES.NOT_FOUND, 'Event not found.');

  const recalculation = await handleEventsDeleted(userId, [result.event.eventId]);
  // Any reminder that pointed at this event is cancelled (spec §19).
  const cancelledNotifications = await cancelForEntity(userId, 'health_event', result.event.eventId, 'source_event_deleted');

  return sendData(res, {
    deletedEventId: result.event.eventId,
    invalidates: getInvalidationTargets(result.event.eventType),
    recalculation,
    cancelledNotifications,
  }, {
    state: RESPONSE_STATES.READY,
    version: EVENTS_VERSION,
    source: SOURCES.MANUAL,
  });
});

export const getTimeline = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const eventTypes = typeof req.query.eventTypes === 'string'
    ? req.query.eventTypes.split(',').map((t) => t.trim()).filter(Boolean)
    : null;

  const timeline = await buildTimeline(userId, {
    from: req.query.from ?? null,
    to: req.query.to ?? null,
    eventTypes,
    limit: Math.min(Number(req.query.limit) || 50, 200),
    skip: Math.max(Number(req.query.skip) || 0, 0),
  });

  return sendData(res, timeline.data, {
    state: timeline.state,
    version: timeline.version,
    source: SOURCES.MANUAL,
  });
});

/**
 * Batch endpoint for the offline queue (spec §25 "Queue writes and sync when
 * online. Idempotent writes prevent duplicates").
 */
export const syncEvents = contractHandler(async (req, res) => {
  const userId = resolveUserId(req);
  if (!userId) return sendError(res, 401, ERROR_CODES.UNAUTHENTICATED, 'Authentication required.');

  const batch = Array.isArray(req.body?.events) ? req.body.events : null;
  if (!batch) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'events must be an array.');
  }
  if (batch.length > 100) {
    return sendError(res, 400, ERROR_CODES.VALIDATION_FAILED, 'A sync batch may contain at most 100 events.');
  }

  const accepted = [];
  const rejected = [];

  for (const item of batch) {
    const result = await createEvent(userId, {
      eventType: item?.eventType,
      payload: item?.payload,
      timestamp: item?.timestamp,
      source: item?.source ?? 'manual',
      clientEventId: item?.clientEventId ?? null,
    });

    if (result.ok) {
      accepted.push({ clientEventId: item?.clientEventId ?? null, event: result.event, deduplicated: result.deduplicated });
    } else {
      rejected.push({ clientEventId: item?.clientEventId ?? null, error: result.error, field: result.field });
    }
  }

  return sendData(res, { accepted, rejected, acceptedCount: accepted.length, rejectedCount: rejected.length }, {
    state: RESPONSE_STATES.READY,
    version: EVENTS_VERSION,
    source: SOURCES.MANUAL,
  });
});
