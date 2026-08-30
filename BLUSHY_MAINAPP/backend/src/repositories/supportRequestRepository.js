import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';
import {
  SUPPORT_REQUEST_STATES,
  canTransition,
  isExpired,
  toPartnerView,
} from '../domain/supportRequests.js';

/**
 * Partner support requests (spec §11).
 *
 * Stored against the connection so authorization is a single lookup, and the
 * partner projection never touches the requester's health data.
 */

const COLLECTION = 'partner_support_requests';

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

function mapRow(row) {
  if (!row) return null;
  return {
    requestId: row.request_id,
    connectionId: row.connection_id,
    requesterUserId: row.requester_user_id,
    partnerUserId: row.partner_user_id,
    type: row.type,
    message: row.message,
    state: row.state,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    expiresAt: row.expires_at ? new Date(row.expires_at).toISOString() : null,
    acknowledgedAt: row.acknowledged_at ? new Date(row.acknowledged_at).toISOString() : null,
    completedAt: row.completed_at ? new Date(row.completed_at).toISOString() : null,
    revokedAt: row.revoked_at ? new Date(row.revoked_at).toISOString() : null,
  };
}

/**
 * Lazily marks past-expiry requests as expired on read, so an expired request
 * never appears actionable even without a background job.
 */
async function settleExpiry(rows, now = new Date()) {
  const expiredIds = rows
    .filter((row) =>
      [SUPPORT_REQUEST_STATES.PENDING, SUPPORT_REQUEST_STATES.ACKNOWLEDGED].includes(row.state) &&
      isExpired(mapRow(row), now),
    )
    .map((row) => row.request_id);

  if (expiredIds.length > 0) {
    await db.collection(COLLECTION).updateMany(
      { request_id: { $in: expiredIds } },
      { $set: { state: SUPPORT_REQUEST_STATES.EXPIRED, updated_at: now } },
    );
    for (const row of rows) {
      if (expiredIds.includes(row.request_id)) row.state = SUPPORT_REQUEST_STATES.EXPIRED;
    }
  }

  return rows;
}

export async function createSupportRequest({ connectionId, requesterUserId, partnerUserId, type, message, expiresInHours }) {
  const now = new Date();
  const doc = {
    request_id: randomUUID(),
    connection_id: connectionId,
    requester_user_id: cleanUserId(requesterUserId),
    partner_user_id: cleanUserId(partnerUserId),
    type,
    message,
    state: SUPPORT_REQUEST_STATES.PENDING,
    created_at: now,
    updated_at: now,
    expires_at: new Date(now.getTime() + expiresInHours * 3600000),
    acknowledged_at: null,
    completed_at: null,
    revoked_at: null,
  };

  await db.collection(COLLECTION).insertOne(doc);
  return mapRow(doc);
}

export async function getSupportRequest(requestId) {
  const row = await db.collection(COLLECTION).findOne({ request_id: requestId });
  if (!row) return null;
  await settleExpiry([row]);
  return mapRow(row);
}

/**
 * Lists requests for a connection. `viewerRole` decides the projection: the
 * partner gets the narrow partner view, the requester gets the full record.
 */
export async function listSupportRequests({ connectionId, viewerUserId, viewerRole, states = null, limit = 30 }) {
  const query = { connection_id: connectionId };
  if (Array.isArray(states) && states.length > 0) query.state = { $in: states };

  const rows = await db.collection(COLLECTION)
    .find(query)
    .sort({ created_at: -1 })
    .limit(Math.min(limit, 100))
    .toArray();

  await settleExpiry(rows);

  const uid = cleanUserId(viewerUserId);
  const authorized = rows.filter(
    (row) => row.requester_user_id === uid || row.partner_user_id === uid,
  );

  return authorized.map((row) => (viewerRole === 'partner' ? toPartnerView(mapRow(row)) : mapRow(row)));
}

/**
 * State change with authorization baked in: only the requester may revoke, only
 * the partner may acknowledge or complete.
 */
export async function transitionSupportRequest({ requestId, actorUserId, nextState }) {
  const row = await db.collection(COLLECTION).findOne({ request_id: requestId });
  if (!row) return { ok: false, notFound: true };

  const uid = cleanUserId(actorUserId);
  let actorRole = null;
  if (row.requester_user_id === uid) actorRole = 'requester';
  else if (row.partner_user_id === uid) actorRole = 'partner';

  if (!actorRole) return { ok: false, forbidden: true, errorCode: 'FORBIDDEN' };

  await settleExpiry([row]);

  const check = canTransition(row.state, nextState, actorRole);
  if (!check.allowed) {
    return { ok: false, errorCode: check.errorCode, currentState: row.state };
  }

  const now = new Date();
  const set = { state: nextState, updated_at: now };
  if (nextState === SUPPORT_REQUEST_STATES.ACKNOWLEDGED) set.acknowledged_at = now;
  if (nextState === SUPPORT_REQUEST_STATES.COMPLETED) set.completed_at = now;
  if (nextState === SUPPORT_REQUEST_STATES.REVOKED) set.revoked_at = now;

  await db.collection(COLLECTION).updateOne({ request_id: requestId }, { $set: set });
  const updated = await db.collection(COLLECTION).findOne({ request_id: requestId });
  return { ok: true, request: mapRow(updated), actorRole };
}

/**
 * When a relationship ends, outstanding requests are revoked so the former
 * partner cannot act on them (spec §28).
 */
export async function revokeAllForConnection(connectionId) {
  const result = await db.collection(COLLECTION).updateMany(
    { connection_id: connectionId, state: { $in: [SUPPORT_REQUEST_STATES.PENDING, SUPPORT_REQUEST_STATES.ACKNOWLEDGED] } },
    { $set: { state: SUPPORT_REQUEST_STATES.REVOKED, revoked_at: new Date(), updated_at: new Date() } },
  );
  return result.modifiedCount ?? 0;
}

export async function purgeUserSupportRequests(userId) {
  const uid = cleanUserId(userId);
  const result = await db.collection(COLLECTION).deleteMany({
    $or: [{ requester_user_id: uid }, { partner_user_id: uid }],
  });
  return result.deletedCount ?? 0;
}
