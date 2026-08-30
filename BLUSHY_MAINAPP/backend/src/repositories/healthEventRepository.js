import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';
import { validateEvent, describeEvent, EVENT_SCHEMA_VERSION } from '../domain/healthEvents.js';

/**
 * Health event store (spec §21 "Data Model Rules", "DATA SHOULD BE EVENT
 * BASED").
 *
 * One collection, keyed by user_id, holding every logged health event with its
 * source and schema version. Derived surfaces are always recalculated from
 * these rows - nothing stores only the final number shown on a card.
 *
 * Deletes are soft (`deleted_at`) so dependent insights can be invalidated and
 * an audit trail survives, while reads exclude them by default.
 */

const COLLECTION = 'health_events';

function mapRow(row) {
  if (!row) return null;
  return {
    eventId: row.event_id,
    userId: row.user_id,
    eventType: row.event_type,
    timestamp: row.timestamp instanceof Date ? row.timestamp.toISOString() : row.timestamp,
    source: row.source,
    schemaVersion: row.schema_version,
    payload: row.payload ?? {},
    userConfirmed: row.user_confirmed !== false,
    clientEventId: row.client_event_id ?? null,
    displayText: describeEvent({ eventType: row.event_type, payload: row.payload ?? {} }),
    deletedAt: row.deleted_at ? new Date(row.deleted_at).toISOString() : null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

/**
 * Creates an event. `clientEventId` makes the write idempotent so an offline
 * queue replaying the same log does not create duplicates (spec §25, §29).
 */
export async function createEvent(userId, input) {
  const uid = cleanUserId(userId);
  const validation = validateEvent(input);
  if (!validation.ok) {
    return { ok: false, field: validation.field, error: validation.error };
  }

  const event = validation.event;
  const now = new Date();

  if (event.clientEventId) {
    const existing = await db.collection(COLLECTION).findOne({
      user_id: uid,
      client_event_id: event.clientEventId,
    });
    if (existing) {
      return { ok: true, event: mapRow(existing), deduplicated: true };
    }
  }

  const doc = {
    event_id: randomUUID(),
    user_id: uid,
    event_type: event.eventType,
    timestamp: new Date(event.timestamp),
    source: event.source,
    schema_version: event.schemaVersion,
    payload: event.payload,
    user_confirmed: event.userConfirmed,
    client_event_id: event.clientEventId,
    deleted_at: null,
    created_at: now,
    updated_at: now,
  };

  await db.collection(COLLECTION).insertOne(doc);
  return { ok: true, event: mapRow(doc), deduplicated: false };
}

export async function getEventById(userId, eventId) {
  const row = await db.collection(COLLECTION).findOne({ user_id: cleanUserId(userId), event_id: eventId });
  return mapRow(row);
}

/**
 * @param {object} filter
 * @param {string[]} filter.eventTypes
 * @param {string} filter.from ISO date-time
 * @param {string} filter.to   ISO date-time
 * @param {boolean} filter.includeDeleted
 * @param {number} filter.limit
 * @param {number} filter.skip
 */
export async function listEvents(userId, filter = {}) {
  const query = { user_id: cleanUserId(userId) };

  if (!filter.includeDeleted) {
    query.deleted_at = null;
  }
  if (Array.isArray(filter.eventTypes) && filter.eventTypes.length > 0) {
    query.event_type = { $in: filter.eventTypes };
  }
  if (filter.from || filter.to) {
    query.timestamp = {};
    if (filter.from) query.timestamp.$gte = new Date(filter.from);
    if (filter.to) query.timestamp.$lte = new Date(filter.to);
  }
  if (filter.source) {
    query.source = filter.source;
  }

  const limit = Math.min(Math.max(Number(filter.limit) || 200, 1), 500);
  const skip = Math.max(Number(filter.skip) || 0, 0);

  const rows = await db.collection(COLLECTION)
    .find(query)
    .sort({ timestamp: -1, _id: -1 })
    .skip(skip)
    .limit(limit)
    .toArray();

  return rows.map(mapRow);
}

export async function countEvents(userId, filter = {}) {
  const query = { user_id: cleanUserId(userId) };
  if (!filter.includeDeleted) query.deleted_at = null;
  if (Array.isArray(filter.eventTypes) && filter.eventTypes.length > 0) {
    query.event_type = { $in: filter.eventTypes };
  }
  if (filter.from || filter.to) {
    query.timestamp = {};
    if (filter.from) query.timestamp.$gte = new Date(filter.from);
    if (filter.to) query.timestamp.$lte = new Date(filter.to);
  }
  return db.collection(COLLECTION).countDocuments(query);
}

/**
 * Edits an event. Re-validates the whole event so an edit can never bypass the
 * rules a create had to satisfy.
 */
export async function updateEvent(userId, eventId, input) {
  const uid = cleanUserId(userId);
  const existing = await db.collection(COLLECTION).findOne({ user_id: uid, event_id: eventId, deleted_at: null });
  if (!existing) {
    return { ok: false, notFound: true };
  }

  const validation = validateEvent({
    eventType: existing.event_type,
    payload: input.payload ?? existing.payload,
    timestamp: input.timestamp ?? existing.timestamp,
    source: input.source ?? existing.source,
    clientEventId: existing.client_event_id,
  });

  if (!validation.ok) {
    return { ok: false, field: validation.field, error: validation.error };
  }

  const event = validation.event;
  const now = new Date();

  await db.collection(COLLECTION).updateOne(
    { user_id: uid, event_id: eventId },
    {
      $set: {
        timestamp: new Date(event.timestamp),
        source: event.source,
        payload: event.payload,
        user_confirmed: event.userConfirmed,
        schema_version: EVENT_SCHEMA_VERSION,
        updated_at: now,
      },
    },
  );

  const updated = await db.collection(COLLECTION).findOne({ user_id: uid, event_id: eventId });
  return { ok: true, event: mapRow(updated), previous: mapRow(existing) };
}

/**
 * Soft delete. Returns the deleted event so the caller can invalidate anything
 * derived from it.
 */
export async function deleteEvent(userId, eventId) {
  const uid = cleanUserId(userId);
  const existing = await db.collection(COLLECTION).findOne({ user_id: uid, event_id: eventId, deleted_at: null });
  if (!existing) return { ok: false, notFound: true };

  await db.collection(COLLECTION).updateOne(
    { user_id: uid, event_id: eventId },
    { $set: { deleted_at: new Date(), updated_at: new Date() } },
  );

  return { ok: true, event: mapRow({ ...existing, deleted_at: new Date() }) };
}

/**
 * Hard delete for account deletion / data erasure requests (spec §21, §28).
 */
export async function purgeUserEvents(userId) {
  const result = await db.collection(COLLECTION).deleteMany({ user_id: cleanUserId(userId) });
  return result.deletedCount ?? 0;
}

export async function exportUserEvents(userId) {
  const rows = await db.collection(COLLECTION)
    .find({ user_id: cleanUserId(userId) })
    .sort({ timestamp: 1 })
    .toArray();
  return rows.map(mapRow);
}

/**
 * Latest event of a given type, used by Home read models for "current state"
 * cards. Never returns a deleted event.
 */
export async function getLatestEvent(userId, eventType) {
  const row = await db.collection(COLLECTION)
    .find({ user_id: cleanUserId(userId), event_type: eventType, deleted_at: null })
    .sort({ timestamp: -1 })
    .limit(1)
    .next();
  return mapRow(row);
}
