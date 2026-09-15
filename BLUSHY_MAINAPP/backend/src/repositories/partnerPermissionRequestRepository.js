import { randomUUID } from 'node:crypto';

import { db } from '../utils/db.js';

/**
 * A partner asking to be shown something that is currently off.
 *
 * Asking is all this does. It records the request and notifies the person who
 * owns the permissions; it never changes what is shared. Only that person can
 * approve it, and declining is a first-class outcome rather than something
 * that happens by ignoring it.
 */
const COLLECTION = 'partner_permission_requests';

export const REQUEST_STATES = Object.freeze({
  PENDING: 'pending',
  APPROVED: 'approved',
  DECLINED: 'declined',
  WITHDRAWN: 'withdrawn',
});

function mapRow(row) {
  if (!row) return null;

  return {
    requestId: row.request_id,
    connectionId: row.connection_id,
    requesterUserId: row.requester_user_id,
    ownerUserId: row.owner_user_id,
    permissionKey: row.permission_key,
    message: row.message ?? null,
    status: row.status,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    resolvedAt: row.resolved_at ? new Date(row.resolved_at).toISOString() : null,
  };
}

export async function findPendingRequest({ connectionId, permissionKey }) {
  const row = await db.collection(COLLECTION).findOne({
    connection_id: connectionId,
    permission_key: permissionKey,
    status: REQUEST_STATES.PENDING,
  });
  return mapRow(row);
}

export async function createRequest({
  connectionId,
  requesterUserId,
  ownerUserId,
  permissionKey,
  message = null,
}) {
  const doc = {
    request_id: randomUUID(),
    connection_id: connectionId,
    requester_user_id: requesterUserId,
    owner_user_id: ownerUserId,
    permission_key: permissionKey,
    // Trimmed hard: this is a note attached to a request, not a message
    // channel, and it is shown to the other person verbatim.
    message: typeof message === 'string' && message.trim().length > 0
      ? message.trim().slice(0, 280)
      : null,
    status: REQUEST_STATES.PENDING,
    created_at: new Date(),
    resolved_at: null,
  };

  await db.collection(COLLECTION).insertOne(doc);
  return mapRow(doc);
}

export async function getRequest(requestId) {
  return mapRow(await db.collection(COLLECTION).findOne({ request_id: requestId }));
}

export async function listRequests({ connectionId, states = null, limit = 50 }) {
  const query = { connection_id: connectionId };
  if (Array.isArray(states) && states.length > 0) {
    query.status = { $in: states };
  }

  const rows = await db.collection(COLLECTION)
    .find(query)
    .sort({ created_at: -1 })
    .limit(limit)
    .toArray();

  return rows.map(mapRow);
}

/**
 * Resolves a pending request.
 *
 * Guarded on the current state so two taps, or an approve racing a withdraw,
 * cannot both land.
 */
export async function resolveRequest({ requestId, nextState }) {
  const result = await db.collection(COLLECTION).findOneAndUpdate(
    { request_id: requestId, status: REQUEST_STATES.PENDING },
    { $set: { status: nextState, resolved_at: new Date() } },
    { returnDocument: 'after' },
  );

  return mapRow(result);
}

/**
 * Called when a connection ends: nothing may stay pending against a
 * relationship that no longer exists.
 */
export async function withdrawAllForConnection(connectionId) {
  const result = await db.collection(COLLECTION).updateMany(
    { connection_id: connectionId, status: REQUEST_STATES.PENDING },
    { $set: { status: REQUEST_STATES.WITHDRAWN, resolved_at: new Date() } },
  );
  return result.modifiedCount ?? 0;
}

export async function purgeUserPermissionRequests(userId) {
  const result = await db.collection(COLLECTION).deleteMany({
    $or: [{ requester_user_id: userId }, { owner_user_id: userId }],
  });
  return result.deletedCount ?? 0;
}
