import { randomUUID } from 'node:crypto';

import { db, withTransaction, findUserDocument } from '../utils/db.js';
import { isUserOnline, publishToUsers } from '../utils/realtimeHub.js';
import { dailyMoodRepository } from './dailyMoodRepository.js';
import { moodFromEvents, sleepFromEvents } from './checkinEventFallback.js';
import { sleepRepository } from './sleepRepository.js';
import { userRepository } from './userRepository.js';
import { getPeriodEntries } from './periodRepository.js';
import { env } from '../utils/env.js';
import { logger } from '../utils/logger.js';
import {
  ACTIVITY_STATES,
  SHARED_ACTIVITIES,
  isKnownActivity,
  canTransition,
  buildActivityList,
} from '../domain/sharedActivities.js';
import { buildPartnerCareSuggestions, buildPartnerSharedDataPayload, buildCycleInfo } from '../services/partnerSuggestionService.js';
import { getDynamicPartnerNeeds } from '../services/partnerNeedsService.js';

const DEFAULT_PERMISSIONS = {
  shareMood: false,
  shareCycle: false,
  shareSleep: false,
  shareInsights: false,
  shareOnboarding: false,
  allowAiSuggestionsWoman: false,
  allowAiSuggestionsMan: false,
  allowDecoderMan: false,
};

const OPEN_CONNECTION_STATUSES = new Set([
  'pending_sender_acceptance',
  'active',
  'breakup_pending',
]);

const PERMISSION_KEYS = Object.keys(DEFAULT_PERMISSIONS);

function normalizeEmail(email) {
  if (typeof email !== 'string') {
    return null;
  }

  const normalized = email.trim().toLowerCase();
  return normalized.length > 0 ? normalized : null;
}

function sanitizePermissions(patch) {
  const next = {};
  for (const key of PERMISSION_KEYS) {
    if (patch && patch[key] !== undefined) {
      next[key] = Boolean(patch[key]);
    }
  }

  return next;
}

function mapInvitationRow(row) {
  if (!row) {
    return null;
  }

  return {
    invitationId: row.invitation_id,
    senderUserId: row.sender_user_id,
    senderEmail: row.sender_email ?? null,
    senderRole: row.sender_role ?? null,
    receiverUserId: row.receiver_user_id,
    receiverEmail: row.receiver_email,
    receiverRole: row.receiver_role ?? null,
    inviteToken: row.invite_token,
    status: row.status,
    respondedAt: row.responded_at ? new Date(row.responded_at).toISOString() : null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

function mapConnectionRow(row, viewerUserId) {
  if (!row) {
    return null;
  }

  const viewerIsUserA = row.user_a_id === viewerUserId;

  return {
    connectionId: row.connection_id,
    invitationId: row.invitation_id ?? null,
    userAId: row.user_a_id,
    userBId: row.user_b_id,
    status: row.status ?? 'active',
    senderAcceptedAt: row.sender_accepted_at ? new Date(row.sender_accepted_at).toISOString() : null,
    receiverAcceptedAt: row.receiver_accepted_at ? new Date(row.receiver_accepted_at).toISOString() : null,
    breakupRequestedByUserId: row.breakup_requested_by_user_id ?? null,
    breakupRequestedAt: row.breakup_requested_at ? new Date(row.breakup_requested_at).toISOString() : null,
    endedAt: row.ended_at ? new Date(row.ended_at).toISOString() : null,
    permissionOwnerUserId: row.permission_owner_user_id,
    permissions: {
      ...DEFAULT_PERMISSIONS,
      ...(row.permissions ?? {}),
    },
    partnerUserId: viewerIsUserA ? row.user_b_id : row.user_a_id,
    partnerEmail: viewerIsUserA ? row.user_b_email : row.user_a_email,
    partnerRole: viewerIsUserA ? row.user_b_role : row.user_a_role,
    viewerIsSender: viewerIsUserA,
    canManagePermissions: row.permission_owner_user_id === viewerUserId,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

function mapMessageRow(row) {
  if (!row) {
    return null;
  }

  return {
    messageId: row.message_id,
    connectionId: row.connection_id,
    senderUserId: row.sender_user_id,
    senderEmail: row.sender_email ?? null,
    senderRole: row.sender?.role ?? null,
    message: row.message,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    partnerMood: row.partnerMood ?? null,
    audioUrl: row.audio_url ?? null,
    audioDuration: row.audio_duration ?? null,
    fileUrl: row.file_url ?? null,
    fileName: row.file_name ?? null,
    fileType: row.file_type ?? null,
    imageUrl: row.image_url ?? null,
    decodedText: row.decoded_text ?? null,
    cyclePhase: row.cycle_phase ?? null,
    currentCycleDay: row.current_cycle_day ?? null,
    isDelivered: Boolean(row.is_delivered),
    isRead: Boolean(row.is_read),
  };
}

/**
 * Resolves the two roles from the user records when the caller does not have
 * them.
 *
 * Invitations store only the two user ids -- no roles -- so every call that
 * passed `invitation.senderRole` was passing `undefined`. Every branch of
 * resolvePermissionOwner then fell through to "the sender", which made the
 * person who sent the invite the owner of the permissions regardless of role.
 * A man inviting a woman ended up owning her sharing panel, and she got 403
 * trying to read or change it, so she could never share anything at all.
 */
async function resolvePermissionOwnerFromUsers({ senderUserId, receiverUserId }) {
  const [sender, receiver] = await Promise.all([
    findUserDocument({ user_id: senderUserId }),
    findUserDocument({ user_id: receiverUserId }),
  ]);

  return resolvePermissionOwner({
    senderUserId,
    senderRole: sender?.role,
    receiverUserId,
    receiverRole: receiver?.role,
  });
}

function resolvePermissionOwner({ senderUserId, senderRole, receiverUserId, receiverRole }) {
  if (senderRole === 'woman' && receiverRole === 'man') {
    return senderUserId;
  }

  if (senderRole === 'man' && receiverRole === 'woman') {
    return receiverUserId;
  }

  if (senderRole === 'woman' && receiverRole === 'woman') {
    return senderUserId;
  }

  return senderUserId;
}

async function getUserByEmail(email) {
  const normalized = normalizeEmail(email);
  if (!normalized) {
    return null;
  }

  const user = await findUserDocument({ email: normalized });

  return user
    ? {
        userId: user.user_id,
        email: user.email,
        role: user.role,
      }
    : null;
}

async function hasConnectionBetween(userAId, userBId) {
  const result = await db.collection('partner_connections').findOne({
    $or: [
      { user_a_id: userAId, user_b_id: userBId },
      { user_a_id: userBId, user_b_id: userAId }
    ],
    status: { $in: Array.from(OPEN_CONNECTION_STATUSES) }
  });

  return Boolean(result);
}

async function hasOpenRelationshipForUser(userId) {
  const result = await db.collection('partner_connections').findOne({
    $or: [
      { user_a_id: userId },
      { user_b_id: userId }
    ],
    status: { $in: Array.from(OPEN_CONNECTION_STATUSES) }
  });

  return Boolean(result);
}

async function hasPendingInvitationFrom(senderUserId) {
  const result = await db.collection('partner_invitations').findOne({
    sender_user_id: senderUserId,
    status: 'pending'
  });

  return Boolean(result);
}

async function createInvitation({ senderUserId, receiverUserId, receiverEmail }) {
  const invitationId = randomUUID();
  const inviteToken = randomUUID();

  const doc = {
    invitation_id: invitationId,
    sender_user_id: senderUserId,
    receiver_user_id: receiverUserId,
    receiver_email: receiverEmail,
    invite_token: inviteToken,
    status: 'pending',
    responded_at: null,
    created_at: new Date(),
    updated_at: new Date(),
  };

  await db.collection('partner_invitations').insertOne(doc);
  return mapInvitationRow(doc);
}

async function getPendingInvitationBetween(userAId, userBId) {
  const result = await db.collection('partner_invitations').findOne({
    status: 'pending',
    $or: [
      { sender_user_id: userAId, receiver_user_id: userBId },
      { sender_user_id: userBId, receiver_user_id: userAId }
    ]
  });

  return result?.invitation_id ?? null;
}

async function listIncomingInvitations(receiverUserId) {
  const invitations = await db.collection('partner_invitations').aggregate([
    { $match: { receiver_user_id: receiverUserId, status: 'pending' } },
    {
      $lookup: {
        from: 'users',
        localField: 'sender_user_id',
        foreignField: 'user_id',
        as: 'sender'
      }
    },
    {
      $lookup: {
        from: 'users',
        localField: 'receiver_user_id',
        foreignField: 'user_id',
        as: 'receiver'
      }
    },
    { $unwind: { path: '$sender', preserveNullAndEmptyArrays: true } },
    { $unwind: { path: '$receiver', preserveNullAndEmptyArrays: true } },
    { $sort: { created_at: -1 } }
  ]).toArray();

  return invitations.map(row => mapInvitationRow({
    ...row,
    sender_email: row.sender?.email,
    sender_role: row.sender?.role,
    receiver_role: row.receiver?.role
  }));
}

async function listOutgoingInvitations(senderUserId) {
  const invitations = await db.collection('partner_invitations').aggregate([
    { $match: { sender_user_id: senderUserId, status: 'pending' } },
    {
      $lookup: {
        from: 'users',
        localField: 'sender_user_id',
        foreignField: 'user_id',
        as: 'sender'
      }
    },
    {
      $lookup: {
        from: 'users',
        localField: 'receiver_user_id',
        foreignField: 'user_id',
        as: 'receiver'
      }
    },
    { $unwind: { path: '$sender', preserveNullAndEmptyArrays: true } },
    { $unwind: { path: '$receiver', preserveNullAndEmptyArrays: true } },
    { $sort: { created_at: -1 } }
  ]).toArray();

  return invitations.map(row => mapInvitationRow({
    ...row,
    sender_email: row.sender?.email,
    sender_role: row.sender?.role,
    receiver_role: row.receiver?.role
  }));
}

async function getInvitationById(invitationId) {
  const invitations = await db.collection('partner_invitations').aggregate([
    { $match: { invitation_id: invitationId } },
    {
      $lookup: {
        from: 'users',
        localField: 'sender_user_id',
        foreignField: 'user_id',
        as: 'sender'
      }
    },
    {
      $lookup: {
        from: 'users',
        localField: 'receiver_user_id',
        foreignField: 'user_id',
        as: 'receiver'
      }
    },
    { $unwind: { path: '$sender', preserveNullAndEmptyArrays: true } },
    { $unwind: { path: '$receiver', preserveNullAndEmptyArrays: true } },
    { $limit: 1 }
  ]).toArray();

  return invitations[0] ? mapInvitationRow({
    ...invitations[0],
    sender_email: invitations[0].sender?.email,
    sender_role: invitations[0].sender?.role,
    receiver_role: invitations[0].receiver?.role
  }) : null;
}

async function createConnectionForInvitation(invitation) {
  const existing = await db.collection('partner_connections').findOne({
    $or: [
      { user_a_id: invitation.senderUserId, user_b_id: invitation.receiverUserId },
      { user_a_id: invitation.receiverUserId, user_b_id: invitation.senderUserId }
    ]
  });

  if (existing?.connection_id) {
    return existing.connection_id;
  }

  const permissionOwnerUserId = await resolvePermissionOwnerFromUsers({
    senderUserId: invitation.senderUserId,
    receiverUserId: invitation.receiverUserId,
  });

  const connectionId = randomUUID();
  const doc = {
    connection_id: connectionId,
    invitation_id: invitation.invitationId,
    user_a_id: invitation.senderUserId,
    user_b_id: invitation.receiverUserId,
    permission_owner_user_id: permissionOwnerUserId,
    permissions: DEFAULT_PERMISSIONS,
    status: 'active',
    receiver_accepted_at: new Date(),
    sender_accepted_at: new Date(),
    created_at: new Date(),
    updated_at: new Date(),
  };

  await db.collection('partner_connections').insertOne(doc);
  return connectionId;
}

async function respondToInvitation({ invitationId, receiverUserId, action }) {
  return withTransaction(async (client) => {
    const invitations = await client.collection('partner_invitations').aggregate([
      { $match: { invitation_id: invitationId } },
      {
        $lookup: {
          from: 'users',
          localField: 'sender_user_id',
          foreignField: 'user_id',
          as: 'sender'
        }
      },
      {
        $lookup: {
          from: 'users',
          localField: 'receiver_user_id',
          foreignField: 'user_id',
          as: 'receiver'
        }
      },
      { $unwind: { path: '$sender', preserveNullAndEmptyArrays: true } },
      { $unwind: { path: '$receiver', preserveNullAndEmptyArrays: true } },
      { $limit: 1 }
    ]).toArray();

    const invitationDoc = invitations[0];
    if (!invitationDoc) {
      return { invitation: null, connectionId: null };
    }

    const invitation = mapInvitationRow({
      ...invitationDoc,
      sender_email: invitationDoc.sender?.email,
      sender_role: invitationDoc.sender?.role,
      receiver_role: invitationDoc.receiver?.role
    });

    if (invitation.receiverUserId !== receiverUserId) {
      throw new Error('FORBIDDEN_INVITATION_RESPONSE');
    }

    if (invitation.status !== 'pending') {
      throw new Error('INVALID_INVITATION_STATE');
    }

    const nextStatus = action === 'accept' ? 'accepted' : 'rejected';
    const now = new Date();

    await client.collection('partner_invitations').updateOne(
      { invitation_id: invitationId },
      {
        $set: {
          status: nextStatus,
          responded_at: now,
          updated_at: now
        }
      }
    );

    const updatedInvitation = mapInvitationRow({
      ...invitationDoc,
      status: nextStatus,
      responded_at: now,
      updated_at: now,
      sender_email: invitationDoc.sender?.email,
      sender_role: invitationDoc.sender?.role,
      receiver_role: invitationDoc.receiver?.role,
    });

    if (nextStatus !== 'accepted') {
      return { invitation: updatedInvitation, connectionId: null };
    }

    const existingConnection = await client.collection('partner_connections').findOne({
      $or: [
        { user_a_id: invitation.senderUserId, user_b_id: invitation.receiverUserId },
        { user_a_id: invitation.receiverUserId, user_b_id: invitation.senderUserId }
      ]
    });

    let connectionId = existingConnection?.connection_id ?? null;

    if (!connectionId) {
      const permissionOwnerUserId = await resolvePermissionOwnerFromUsers({
        senderUserId: invitation.senderUserId,
        receiverUserId: invitation.receiverUserId,
      });

      connectionId = randomUUID();
      await client.collection('partner_connections').insertOne({
        connection_id: connectionId,
        invitation_id: invitation.invitationId,
        user_a_id: invitation.senderUserId,
        user_b_id: invitation.receiverUserId,
        permission_owner_user_id: permissionOwnerUserId,
        permissions: DEFAULT_PERMISSIONS,
        status: 'active',
        receiver_accepted_at: now,
        sender_accepted_at: now,
        created_at: now,
        updated_at: now
      });
    } else {
      await client.collection('partner_connections').updateOne(
        { connection_id: connectionId },
        {
          $set: {
            status: 'active',
            receiver_accepted_at: now,
            sender_accepted_at: now,
            updated_at: now
          }
        }
      );
    }

    return { invitation: updatedInvitation, connectionId };
  });
}

async function respondToConnection({ connectionId, actorUserId, action }) {
  return withTransaction(async (client) => {
    const current = await getConnectionForUser(connectionId, actorUserId, client);
    if (!current) {
      return null;
    }

    const isSender = current.userAId === actorUserId;

    if (action === 'accept') {
      if (!isSender) {
        throw new Error('FORBIDDEN_CONNECTION_RESPONSE');
      }

      if (current.status === 'active') {
        return current;
      }

      if (current.status !== 'pending_sender_acceptance') {
        throw new Error('INVALID_CONNECTION_STATE');
      }

      await client.collection('partner_connections').updateOne(
        { connection_id: connectionId },
        {
          $set: {
            status: 'active',
            sender_accepted_at: new Date(),
            breakup_requested_by_user_id: null,
            breakup_requested_at: null,
            ended_at: null,
            updated_at: new Date()
          }
        }
      );

      return getConnectionForUser(connectionId, actorUserId, client);
    }

    if (action === 'reject') {
      if (!isSender) {
        throw new Error('FORBIDDEN_CONNECTION_RESPONSE');
      }

      const connection = await client.collection('partner_connections').findOne({ connection_id: connectionId });
      if (connection && connection.invitation_id) {
        await client.collection('partner_invitations').updateOne(
          { invitation_id: connection.invitation_id },
          {
            $set: {
              status: 'cancelled',
              updated_at: new Date()
            }
          }
        );
      }

      await client.collection('partner_connections').deleteOne({ connection_id: connectionId });
      return null;
    }

    throw new Error('INVALID_CONNECTION_ACTION');
  });
}

async function requestBreakup({ connectionId, actorUserId }) {
  return withTransaction(async (client) => {
    const current = await getConnectionForUser(connectionId, actorUserId, client);
    if (!current) {
      return null;
    }

    if (!OPEN_CONNECTION_STATUSES.has(current.status)) {
      return current;
    }

    if (current.status === 'breakup_pending' && current.breakupRequestedByUserId && current.breakupRequestedByUserId !== actorUserId) {
      await client.collection('partner_connections').updateOne(
        { connection_id: connectionId },
        {
          $set: {
            status: 'breakup',
            breakup_requested_at: new Date(),
            ended_at: new Date(),
            updated_at: new Date()
          }
        }
      );
      return getConnectionForUser(connectionId, actorUserId, client);
    }

    if (current.breakupRequestedByUserId === actorUserId) {
      return current;
    }

    await client.collection('partner_connections').updateOne(
      { connection_id: connectionId },
      {
        $set: {
          status: 'breakup_pending',
          breakup_requested_by_user_id: actorUserId,
          breakup_requested_at: new Date(),
          updated_at: new Date()
        }
      }
    );

    return getConnectionForUser(connectionId, actorUserId, client);
  });
}

async function listConnectionsForUser(userId) {
  const connections = await db.collection('partner_connections').aggregate([
    {
      $match: {
        $or: [{ user_a_id: userId }, { user_b_id: userId }],
        status: { $ne: 'ended' }
      }
    },
    {
      $lookup: {
        from: 'users',
        localField: 'user_a_id',
        foreignField: 'user_id',
        as: 'user_a'
      }
    },
    {
      $lookup: {
        from: 'users',
        localField: 'user_b_id',
        foreignField: 'user_id',
        as: 'user_b'
      }
    },
    { $unwind: { path: '$user_a', preserveNullAndEmptyArrays: true } },
    { $unwind: { path: '$user_b', preserveNullAndEmptyArrays: true } },
    { $sort: { updated_at: -1 } }
  ]).toArray();

  return connections.map((row) => mapConnectionRow({
    ...row,
    user_a_email: row.user_a?.email,
    user_a_role: row.user_a?.role,
    user_b_email: row.user_b?.email,
    user_b_role: row.user_b?.role
  }, userId));
}

async function getConnectionForUser(connectionId, userId, client = db) {
  const connections = await client.collection('partner_connections').aggregate([
    {
      $match: {
        connection_id: connectionId,
        $or: [{ user_a_id: userId }, { user_b_id: userId }],
        status: { $ne: 'ended' }
      }
    },
    {
      $lookup: {
        from: 'users',
        localField: 'user_a_id',
        foreignField: 'user_id',
        as: 'user_a'
      }
    },
    {
      $lookup: {
        from: 'users',
        localField: 'user_b_id',
        foreignField: 'user_id',
        as: 'user_b'
      }
    },
    { $unwind: { path: '$user_a', preserveNullAndEmptyArrays: true } },
    { $unwind: { path: '$user_b', preserveNullAndEmptyArrays: true } },
    { $limit: 1 }
  ]).toArray();

  return connections[0] ? mapConnectionRow({
    ...connections[0],
    user_a_email: connections[0].user_a?.email,
    user_a_role: connections[0].user_a?.role,
    user_b_email: connections[0].user_b?.email,
    user_b_role: connections[0].user_b?.role
  }, userId) : null;
}

async function updateConnectionPermissions({ connectionId, actorUserId, permissionPatch }) {
  const current = await getConnectionForUser(connectionId, actorUserId);
  if (!current) {
    return null;
  }

  const user = await userRepository.getUserById(actorUserId);
  const actorRole = user?.role ?? 'woman';

  const cleanPatch = sanitizePermissions(permissionPatch);
  const nextPermissions = {
    ...DEFAULT_PERMISSIONS,
    ...current.permissions,
    ...cleanPatch,
  };

  const currentPermissions = {
    ...DEFAULT_PERMISSIONS,
    ...current.permissions,
  };

  const changedKeys = Object.keys(nextPermissions).filter(
    (key) => nextPermissions[key] !== currentPermissions[key]
  );

  for (const key of changedKeys) {
    if (key === 'allowAiSuggestionsWoman') {
      if (actorRole !== 'woman') {
        const error = new Error('FORBIDDEN_PERMISSION_UPDATE');
        throw error;
      }
    } else if (key === 'allowAiSuggestionsMan' || key === 'allowDecoderMan') {
      if (actorRole !== 'man') {
        const error = new Error('FORBIDDEN_PERMISSION_UPDATE');
        throw error;
      }
    } else {
      if (!current.canManagePermissions) {
        const error = new Error('FORBIDDEN_PERMISSION_UPDATE');
        throw error;
      }
    }
  }

  const result = await db.collection('partner_connections').updateOne(
    { connection_id: connectionId },
    {
      $set: {
        permissions: nextPermissions,
        updated_at: new Date()
      }
    }
  );

  if (result.matchedCount === 0) {
    return null;
  }

  return getConnectionForUser(connectionId, actorUserId);
}
function formatDateOnly(value) {
  if (!value) return '';
  if (value instanceof Date) {
    const y = value.getFullYear();
    const m = String(value.getMonth() + 1).padStart(2, '0');
    const d = String(value.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  if (typeof value === 'string') {
    if (value.length >= 10) return value.slice(0, 10);
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      const y = parsed.getFullYear();
      const m = String(parsed.getMonth() + 1).padStart(2, '0');
      const d = String(parsed.getDate()).padStart(2, '0');
      return `${y}-${m}-${d}`;
    }
  }
  return '';
}

async function decodeMessageHelper({ message, cycleInfo, recentHistory }) {
  const cycleDesc = cycleInfo
    ? `on Day ${cycleInfo.currentCycleDay} of her menstrual cycle (${cycleInfo.phase} phase)`
    : `in an unknown phase of her menstrual cycle`;

  // Same provider as the rest of the app; this previously pointed at
  // OpenRouter with an xAI model while everything else used Groq.
  const aiChatApiKey = env.aiChatApiKey;
  const aiChatApiUrl = env.aiChatApiUrl;
  const aiChatModel = env.aiChatModel;

  if (!aiChatApiKey) {
    return `She sent: "${message}". Try responding with warmth and understanding.`;
  }

  try {
    const response = await fetch(aiChatApiUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${aiChatApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: aiChatModel,
        messages: [
          {
            role: 'system',
            content: `You are Docsy, acting as a close, casual, and supportive "third wheel" friend to the male user ("bro"). Explain his girlfriend's message subtext in a very human, conversational way (not like a clinical AI), and give a direct tip on how he should reply.
Analyze the recent conversation style/tone (e.g. flirting, playful roasting, bantering, serious, funny) and ensure your tone and suggestions match this style (e.g., if they are roasting, keep the tip roasting/playful; if they are flirting, keep the tip romantic/playful).
The girlfriend is currently ${cycleDesc}.
Keep it short, simple, cool, and conversational.

Recent Chat History:
${recentHistory}

Format exactly like this (two lines):
Docsy: [casual friendly explanation matching the conversation tone, e.g. "Chill bro, she's just playfully teasing you."]
Tip: [casual, actionable reply advice matching the conversation tone, e.g. "Laugh it off and suggest buying a toy car instead."]

Latest Partner Message to Decode: "${message}"`,
          }
        ],
        max_tokens: 80,
      }),
    });

    if (response.ok) {
      const payload = await response.json();
      const choices = Array.isArray(payload?.choices) ? payload.choices : [];
      for (const choice of choices) {
        const content = choice?.message?.content;
        if (typeof content === 'string' && content.trim()) {
          return content.trim();
        }
      }
    }
  } catch (err) {
    console.error('Error calling Grok in decodeMessageHelper:', err);
  }

  return `She sent: "${message}". Try responding with warmth and understanding.`;
}

async function listMessagesForConnection(connectionId, userId) {
  const connection = await getConnectionForUser(connectionId, userId);
  if (!connection) {
    return null;
  }

  const partnerUserId = connection.partnerUserId;
  if (partnerUserId) {
    const updateRes = await db.collection('partner_chat_messages').updateMany(
      { connection_id: connectionId, sender_user_id: partnerUserId, is_read: false },
      { $set: { is_delivered: true, is_read: true } }
    );
    if (updateRes.modifiedCount > 0) {
      publishToUsers([partnerUserId], 'partner.updated', {
        reason: 'messages-read',
        connectionId,
        readByUserId: userId,
      });
    }
  }

  const partnerProfile = await userRepository.getUserById(partnerUserId);
  const partnerRole = partnerProfile ? (partnerProfile.role ?? 'woman') : 'woman';

  const partnerMoodCollName = partnerRole === 'man' ? 'user_daily_moods_man' : 'user_daily_moods_woman';
  const partnerMoods = await db.collection(partnerMoodCollName).find({ user_id: partnerUserId }).toArray();
  const moodMap = new Map();
  for (const m of partnerMoods) {
    if (m.entry_date) {
      const dateStr = formatDateOnly(m.entry_date);
      moodMap.set(dateStr, m);
    }
  }

  const cycleStartDate = partnerProfile?.cycleStartDate ?? null;

  const messages = await db.collection('partner_chat_messages').aggregate([
    { $match: { connection_id: connectionId } },
    {
      $lookup: {
        from: 'users',
        localField: 'sender_user_id',
        foreignField: 'user_id',
        as: 'sender'
      }
    },
    { $unwind: { path: '$sender', preserveNullAndEmptyArrays: true } },
    { $sort: { created_at: 1 } }
  ]).toArray();

  const viewerProfile = await userRepository.getUserById(userId);
  const viewerRole = viewerProfile ? (viewerProfile.role ?? 'woman') : 'woman';
  const showDecoderToViewer = viewerRole === 'man' && connection.permissions?.allowDecoderMan;

  const undecodedIndices = [];
  if (showDecoderToViewer) {
    for (let i = messages.length - 1; i >= 0; i--) {
      const row = messages[i];
      const senderRole = row.sender?.role ?? 'woman';
      const isPartnerMessage = senderRole === 'woman';
      if (isPartnerMessage && !row.decoded_text && row.message) {
        undecodedIndices.push(i);
      }
    }
  }
  const indicesToDecodeSet = new Set(undecodedIndices.slice(0, 2));

  const mappedMessages = [];
  for (let i = 0; i < messages.length; i++) {
    const row = messages[i];
    
    const senderRole = row.sender?.role ?? 'woman';
    const isPartnerMessage = senderRole === 'woman';

    let cycleInfo = null;
    if (cycleStartDate && connection.permissions?.shareCycle) {
      const start = new Date(cycleStartDate);
      if (!Number.isNaN(start.getTime())) {
        const msgDate = new Date(row.created_at || new Date());
        const diffMs = msgDate.getTime() - start.getTime();
        const diffDays = Math.floor(diffMs / 86400000);
        const currentCycleDay = ((diffDays % 28) + 28) % 28 + 1;
        let phase = 'Cycle phase';
        if (currentCycleDay <= 5) {
          phase = 'Period phase';
        } else if (currentCycleDay <= 13) {
          phase = 'Follicular phase';
        } else if (currentCycleDay <= 16) {
          phase = 'Ovulation phase';
        } else {
          phase = 'Luteal phase';
        }
        cycleInfo = {
          currentCycleDay,
          phase
        };
      }
    }

    let moodInfo = null;
    if (connection.permissions?.shareMood) {
      const msgDate = new Date(row.created_at || new Date());
      const dateStr = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Asia/Kolkata',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
      }).format(msgDate);
      
      const m = moodMap.get(dateStr);
      if (m) {
        moodInfo = {
          mood: m.mood,
          energyLevel: m.energy_level ?? null,
          stressLevel: m.stress_level ?? null,
          notes: m.notes ?? '',
        };
      }
    }

    const partnerMood = (moodInfo || cycleInfo) ? {
      mood: moodInfo?.mood ?? null,
      energyLevel: moodInfo?.energyLevel ?? null,
      stressLevel: moodInfo?.stressLevel ?? null,
      notes: moodInfo?.notes ?? null,
      cyclePhase: cycleInfo?.phase ?? null,
      currentCycleDay: cycleInfo?.currentCycleDay ?? null,
    } : null;

    let decodedText = row.decoded_text ?? null;
    let cyclePhase = (cycleInfo ? cycleInfo.phase : null) ?? row.cycle_phase ?? null;
    let currentCycleDay = (cycleInfo ? cycleInfo.currentCycleDay : null) ?? row.current_cycle_day ?? null;

    if (indicesToDecodeSet.has(i)) {
      const recentHistory = messages
        .slice(Math.max(0, i - 5), i)
        .map((m) => `${m.sender?.role === 'man' ? 'User (Man)' : 'Partner (Woman)'}: ${m.message}`)
        .join('\n');

      try {
        decodedText = await decodeMessageHelper({
          message: row.message,
          cycleInfo: cycleInfo,
          recentHistory
        });
        cyclePhase = cycleInfo ? cycleInfo.phase : 'Unknown';
        currentCycleDay = cycleInfo ? cycleInfo.currentCycleDay : null;

        await db.collection('partner_chat_messages').updateOne(
          { message_id: row.message_id },
          {
            $set: {
              decoded_text: decodedText,
              cycle_phase: cyclePhase,
              current_cycle_day: currentCycleDay,
            }
          }
        );
      } catch (err) {
        console.error('Lazy decoding error for message:', row.message_id, err);
      }
    }

    const mapped = mapMessageRow({
      ...row,
      sender_email: row.sender?.email,
      partnerMood,
      decoded_text: decodedText,
      cycle_phase: cyclePhase,
      current_cycle_day: currentCycleDay,
    });
    mappedMessages.push(mapped);
  }

  return mappedMessages;
}

async function sendMessageToConnection({
  connectionId,
  senderUserId,
  message,
  audioUrl,
  audioDuration,
  fileUrl,
  fileName,
  fileType,
  imageUrl,
}) {
  // No transaction. A single document insert is already atomic, and the only
  // other write here is the notification, which is derived from the message
  // rather than part of it. Wrapping the two together meant a failed
  // notification rolled back a message the sender had been told was sent --
  // and cost 4-5x a bare insert to do it: measured at 209-1076ms against
  // 46-129ms, with the variance being what "message is slow" felt like.
  const client = db;
  {
    const connection = await client.collection('partner_connections').findOne({
      connection_id: connectionId,
      $or: [{ user_a_id: senderUserId }, { user_b_id: senderUserId }]
    });

    if (!connection) {
      return null;
    }

    if (connection.status !== 'active') {
      throw new Error('CONNECTION_NOT_ACTIVE');
    }

    const text = typeof message === 'string' ? message.trim() : '';
    const hasMedia = audioUrl || fileUrl || imageUrl;
    if (!text && !hasMedia) {
      throw new Error('EMPTY_PARTNER_MESSAGE');
    }

    const recipientUserId = connection.user_a_id === senderUserId ? connection.user_b_id : connection.user_a_id;
    const isOnline = recipientUserId ? isUserOnline(recipientUserId) : false;

    const doc = {
      message_id: randomUUID(),
      connection_id: connectionId,
      sender_user_id: senderUserId,
      message: text,
      created_at: new Date(),
      audio_url: audioUrl || null,
      audio_duration: audioDuration || null,
      file_url: fileUrl || null,
      file_name: fileName || null,
      file_type: fileType || null,
      image_url: imageUrl || null,
      is_delivered: isOnline,
      is_read: false,
    };

    await client.collection('partner_chat_messages').insertOne(doc);

    // The notification is derived from the message, not part of it. Inside the
    // transaction a failure here rolled back a message the sender had already
    // been told was sent -- the wrong way round, since the message is the thing
    // that must survive and the badge can be rebuilt from it.
    //
    // The two reads it needs are independent of each other, so they overlap.
    if (recipientUserId) {
      try {
      const [sender, unreadCount] = await Promise.all([
        client.collection('users').findOne({ user_id: senderUserId }),
        client.collection('partner_chat_messages').countDocuments({
          connection_id: connectionId,
          sender_user_id: senderUserId,
          is_read: false,
        }),
      ]);
      const senderName = sender?.display_name || sender?.email || 'Partner';

      const notificationTitle = unreadCount > 1
        ? `${senderName} sent ${unreadCount} messages 💌`
        : `${senderName} sent a message 💌`;
      const notificationBody = text ? (text.length > 50 ? text.slice(0, 50) + '...' : text) : 'Sent a voice/media file';

      await client.collection('partner_notifications').updateOne(
        {
          connection_id: connectionId,
          recipient_user_id: recipientUserId,
          data_type: 'partner-message',
        },
        {
          $set: {
            notification_id: randomUUID(),
            connection_id: connectionId,
            recipient_user_id: recipientUserId,
            user_id: recipientUserId,
            type: 'partner-message',
            data_type: 'partner-message',
            title: notificationTitle,
            body: notificationBody,
            count: unreadCount,
            unread_count: unreadCount,
            created_at: new Date(),
            is_seen: false,
            is_read: false,
          },
        },
        { upsert: true }
      );
      } catch (error) {
        // The message is already stored. A badge that failed to update is a
        // smaller problem than telling the sender it did not send, and the
        // count is rebuilt from the messages on the next one.
        logger.warn('Partner message stored, but its notification failed', {
          connectionId,
          message: error?.message,
        });
      }
    }

    return mapMessageRow(doc);
  }
}

async function deleteConnectionHistory(connectionId) {
  await db.collection('partner_chat_messages').deleteMany({ connection_id: connectionId });
  await db.collection('partner_connections').deleteOne({ connection_id: connectionId });
}

async function getSharedData({ connectionId, viewerUserId }) {
  const connection = await getConnectionForUser(connectionId, viewerUserId);
  if (!connection || connection.status !== 'active') {
    return null;
  }

  const partnerUserId = connection.partnerUserId;
  const permissions = connection.permissions ?? DEFAULT_PERMISSIONS;
  const [partnerUser, viewerOnboarding] = await Promise.all([
    userRepository.getUserById(partnerUserId),
    userRepository.getOnboardingAnswers(viewerUserId),
  ]);

  const data = {
    mood: null,
    cycle: null,
    sleep: null,
  };

  const partnerRole = partnerUser?.role || 'woman';
  const isPartnerWoman = partnerRole === 'woman';
  const onboardingAnswers = partnerUser?.onboardingAnswers ?? {};
  const effectiveCycleStart = partnerUser?.cycleStartDate ||
    onboardingAnswers?.period_last_start_date ||
    onboardingAnswers?.cycle_last_period_start ||
    onboardingAnswers?.period_last_month_1_start ||
    null;

  if (permissions.shareMood) {
    const today = new Date().toISOString().slice(0, 10);
    data.mood = await dailyMoodRepository.getDailyMood(partnerUserId, today);
    // Nothing in the app writes `user_daily_moods` -- the check-in records
    // health events -- so without this the partner saw null however faithfully
    // she checked in.
    if (!data.mood) data.mood = await moodFromEvents(partnerUserId, today);
  }

  let periodEntries = [];
  if (isPartnerWoman && permissions.shareCycle) {
    data.cycle = effectiveCycleStart;
    // Gated by the same permission as the cycle itself. Only the derived
    // period length reaches the partner -- the entries themselves never do.
    try {
      periodEntries = await getPeriodEntries(partnerUserId, 20);
    } catch (err) {
      console.error('Error fetching period entries for cycle info:', err);
    }
  }

  if (permissions.shareSleep) {
    const today = new Date().toISOString().slice(0, 10);
    data.sleep = await sleepRepository.getSleepByDate(partnerUserId, today);
    if (!data.sleep) data.sleep = await sleepFromEvents(partnerUserId, today);
  }

  const cycleInfo = (isPartnerWoman && permissions.shareCycle && data.cycle)
    ? buildCycleInfo(data.cycle, partnerUser?.onboardingAnswers ?? {}, new Date(), periodEntries)
    : null;

  const hasAnyData = (permissions.shareMood && data.mood) || 
                     (permissions.shareSleep && data.sleep) || 
                     (permissions.shareCycle && cycleInfo);

  const suggestions = hasAnyData
    ? buildPartnerCareSuggestions({
        latestMood: permissions.shareMood ? data.mood : null,
        latestSleep: permissions.shareSleep ? data.sleep : null,
        cycleInfo: permissions.shareCycle ? cycleInfo : null,
        viewerOnboardingAnswers: viewerOnboarding?.onboardingAnswers ?? {},
      })
    : [];

  // `getUserById` returns a mapped row, and the mapped key is `displayName`.
  // Reading `display_name` off it was always undefined, so this fell through to
  // the email local-part -- and her account identifier appeared in copy the
  // partner reads: "probe_sw_1788192975908 doesn't need anything right now".
  //
  // The email fallback is gone with it. An address is not a name, and it is not
  // something to surface to another person.
  const partnerName = partnerUser?.displayName
    || partnerUser?.display_name
    || onboardingAnswers?.preferred_name
    || (isPartnerWoman ? 'She' : 'He');

  let dynamicNeeds = null;
  try {
    dynamicNeeds = await getDynamicPartnerNeeds({
      partnerUserId,
      partnerRole,
      cycleInfo,
      partnerName,
    });
  } catch (err) {
    console.error('Error getting dynamic partner needs:', err);
  }

  const connectedAt = connection.senderAcceptedAt || connection.receiverAcceptedAt || connection.createdAt || null;
  const todayDateStr = new Date().toISOString().slice(0, 10);
  let completedActionIds = [];
  try {
    completedActionIds = await getCompletedSupportActions({ connectionId, dateStr: todayDateStr });
  } catch (err) {
    console.error('Error fetching completed support actions:', err);
  }

  return buildPartnerSharedDataPayload({
    connectionId,
    partnerUserId,
    partnerUser,
    permissions,
    mood: data.mood,
    sleep: data.sleep,
    cycleStartDate: data.cycle,
    periodEntries,
    suggestions,
    dynamicNeeds,
    connectedAt,
    completedActionIds,
  });
}

async function markDataViewed({ connectionId, viewerUserId, dataType }) {
  const now = new Date();
  await db.collection('partner_data_views').updateOne(
    { connection_id: connectionId, viewer_user_id: viewerUserId, data_type: dataType },
    {
      $set: {
        viewed_at: now,
        updated_at: now
      },
      $setOnInsert: {
        view_id: randomUUID(),
        created_at: now
      }
    },
    { upsert: true }
  );

  await db.collection('partner_notifications').updateMany(
    { connection_id: connectionId, recipient_user_id: viewerUserId, data_type: dataType },
    {
      $set: {
        is_seen: true,
        seen_at: now
      }
    }
  );
}

async function createNotification({ connectionId, recipientUserId, dataType }) {
  const existing = await db.collection('partner_notifications').findOne({
    connection_id: connectionId,
    recipient_user_id: recipientUserId,
    data_type: dataType
  });

  if (existing) {
    if (!existing.is_seen) {
      return { notificationId: existing.notification_id, created: false };
    }

    await db.collection('partner_notifications').updateOne(
      { notification_id: existing.notification_id },
      {
        $set: {
          is_seen: false,
          seen_at: null,
          created_at: new Date()
        }
      }
    );

    return { notificationId: existing.notification_id, created: true };
  }

  const notificationId = randomUUID();
  await db.collection('partner_notifications').insertOne({
    notification_id: notificationId,
    connection_id: connectionId,
    recipient_user_id: recipientUserId,
    data_type: dataType,
    is_seen: false,
    created_at: new Date()
  });

  return { notificationId, created: true };
}

async function listNotificationsForUser(recipientUserId) {
  const notifications = await db.collection('partner_notifications').aggregate([
    {
      $match: {
        $or: [
          { recipient_user_id: recipientUserId, is_seen: false },
          { recipient_user_id: recipientUserId, is_read: false },
          { user_id: recipientUserId, is_seen: false },
          { user_id: recipientUserId, is_read: false }
        ]
      }
    },
    {
      $lookup: {
        from: 'partner_connections',
        localField: 'connection_id',
        foreignField: 'connection_id',
        as: 'connection'
      }
    },
    { $unwind: { path: '$connection', preserveNullAndEmptyArrays: true } },
    { $sort: { created_at: -1 } }
  ]).toArray();

  return notifications.map((row) => {
    const connection = row.connection || {};
    const viewerIsUserA = connection.user_a_id === recipientUserId;
    const type = row.type || row.data_type || 'partner-message';
    let title = row.title;
    let body = row.body;

    if (!title) {
      title = type === 'mood'
        ? 'Partner mood updated'
        : type === 'sleep'
        ? 'Partner sleep updated'
        : type === 'cycle'
        ? 'Partner cycle updated'
        : type === 'insights'
        ? 'Partner insights updated'
        : type === 'partner-message'
        ? 'New message from partner 💌'
        : 'Partner update';
    }

    if (!body) {
      body = type === 'mood'
        ? 'Your partner shared a new mood update.'
        : type === 'sleep'
        ? 'Your partner shared a new sleep update.'
        : type === 'cycle'
        ? 'Your partner shared a new cycle update.'
        : type === 'insights'
        ? 'Your partner shared refreshed insights.'
        : type === 'partner-message'
        ? 'You received a new message from your partner.'
        : 'Your partner shared an update.';
    }

    return {
      id: row.notification_id || randomUUID(),
      connectionId: row.connection_id,
      type,
      title,
      body,
      count: Number(row.count || row.unread_count) || 1,
      unreadCount: Number(row.count || row.unread_count) || 1,
      isRead: row.is_seen === true || row.is_read === true,
      createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
      seenAt: row.seen_at ? new Date(row.seen_at).toISOString() : null,
      partnerUserId: viewerIsUserA ? connection.user_b_id : connection.user_a_id,
      permissions: { ...DEFAULT_PERMISSIONS, ...(connection.permissions ?? {}) },
    };
  });
}

async function markNotificationsReadForUser(recipientUserId) {
  const now = new Date();
  await db.collection('partner_notifications').updateMany(
    {
      $or: [
        { recipient_user_id: recipientUserId },
        { user_id: recipientUserId }
      ]
    },
    {
      $set: {
        is_seen: true,
        is_read: true,
        seen_at: now
      }
    }
  );

  const userConnections = await db.collection('partner_connections').find({
    $or: [{ user_a_id: recipientUserId }, { user_b_id: recipientUserId }]
  }).toArray();

  for (const conn of userConnections) {
    const partnerId = conn.user_a_id === recipientUserId ? conn.user_b_id : conn.user_a_id;
    if (partnerId) {
      await db.collection('partner_chat_messages').updateMany(
        { connection_id: conn.connection_id, sender_user_id: partnerId, is_read: false },
        { $set: { is_read: true } }
      );
    }
  }
}

async function getActiveConnectionForUser(userId) {
  const connections = await db.collection('partner_connections').aggregate([
    {
      $match: {
        $or: [{ user_a_id: userId }, { user_b_id: userId }],
        status: 'active'
      }
    },
    {
      $lookup: {
        from: 'users',
        localField: 'user_a_id',
        foreignField: 'user_id',
        as: 'user_a'
      }
    },
    {
      $lookup: {
        from: 'users',
        localField: 'user_b_id',
        foreignField: 'user_id',
        as: 'user_b'
      }
    },
    { $unwind: { path: '$user_a', preserveNullAndEmptyArrays: true } },
    { $unwind: { path: '$user_b', preserveNullAndEmptyArrays: true } },
    { $sort: { updated_at: -1 } },
    { $limit: 1 }
  ]).toArray();

  return connections[0] ? mapConnectionRow({
    ...connections[0],
    user_a_email: connections[0].user_a?.email,
    user_a_role: connections[0].user_a?.role,
    user_b_email: connections[0].user_b?.email,
    user_b_role: connections[0].user_b?.role
  }, userId) : null;
}

async function getCompletedSupportActions({ connectionId, dateStr }) {
  const dateKey = dateStr || new Date().toISOString().slice(0, 10);
  const doc = await db.collection('partner_completed_actions').findOne({
    connection_id: connectionId,
    date_key: dateKey,
  });
  return doc?.completed_action_ids || [];
}


/* ------------------------------------------------------------------ *
 * Shared activities (spec §10, §16)
 * ------------------------------------------------------------------ */

const SHARED_ACTIVITY_COLLECTION = 'partner_shared_activities';

function mapActivityRow(row) {
  return {
    status: row.status,
    startedByUserId: row.started_by_user_id ?? null,
    completedByUserId: row.completed_by_user_id ?? null,
    startedAt: row.started_at ? new Date(row.started_at).toISOString() : null,
    completedAt: row.completed_at ? new Date(row.completed_at).toISOString() : null,
    completionCount: row.completion_count ?? 0,
  };
}

/**
 * Every activity for a connection, merged with the catalogue.
 *
 * Membership is checked first: activity state is shared relationship data and
 * must not be readable by anyone who simply knows a connection id.
 */
async function listSharedActivities({ connectionId, userId }) {
  const connection = await getConnectionForUser(connectionId, userId);
  if (!connection) return null;

  const rows = await db.collection(SHARED_ACTIVITY_COLLECTION)
    .find({ connection_id: connectionId })
    .toArray();

  const stateByKey = {};
  for (const row of rows) {
    stateByKey[row.activity_key] = mapActivityRow(row);
  }
  return buildActivityList(stateByKey);
}

/**
 * Moves one activity to a new state. Returns null when the caller is not part
 * of the connection, and `{ ok: false }` when the transition is not legal.
 */
async function setSharedActivityStatus({ connectionId, userId, activityKey, status }) {
  const connection = await getConnectionForUser(connectionId, userId);
  if (!connection) return null;

  if (!isKnownActivity(activityKey)) {
    return { ok: false, reason: 'unknown_activity' };
  }

  const existing = await db.collection(SHARED_ACTIVITY_COLLECTION).findOne({
    connection_id: connectionId,
    activity_key: activityKey,
  });
  const from = existing?.status ?? ACTIVITY_STATES.NOT_STARTED;
  const repeatable = SHARED_ACTIVITIES[activityKey].repeatable;

  if (!canTransition(from, status, { repeatable })) {
    return { ok: false, reason: 'invalid_transition', from, to: status };
  }

  const now = new Date();
  const set = { status, updated_at: now };
  const inc = {};

  if (status === ACTIVITY_STATES.IN_PROGRESS) {
    set.started_by_user_id = userId;
    set.started_at = now;
    set.completed_by_user_id = null;
    set.completed_at = null;
  } else if (status === ACTIVITY_STATES.COMPLETED) {
    set.completed_by_user_id = userId;
    set.completed_at = now;
    inc.completion_count = 1;
  } else {
    set.started_by_user_id = null;
    set.started_at = null;
    set.completed_by_user_id = null;
    set.completed_at = null;
  }

  const update = {
    $set: set,
    $setOnInsert: {
      connection_id: connectionId,
      activity_key: activityKey,
      created_at: now,
    },
  };
  if (Object.keys(inc).length > 0) update.$inc = inc;

  await db.collection(SHARED_ACTIVITY_COLLECTION).updateOne(
    { connection_id: connectionId, activity_key: activityKey },
    update,
    { upsert: true },
  );

  return { ok: true, activities: await listSharedActivities({ connectionId, userId }) };
}

async function toggleCompletedSupportAction({ connectionId, userId, actionId, completed, dateStr }) {
  const dateKey = dateStr || new Date().toISOString().slice(0, 10);
  const now = new Date();

  if (completed) {
    await db.collection('partner_completed_actions').updateOne(
      { connection_id: connectionId, date_key: dateKey },
      {
        $addToSet: { completed_action_ids: actionId },
        $set: { updated_at: now, user_id: userId },
        $setOnInsert: { created_at: now, connection_id: connectionId, date_key: dateKey }
      },
      { upsert: true }
    );
  } else {
    await db.collection('partner_completed_actions').updateOne(
      { connection_id: connectionId, date_key: dateKey },
      {
        $pull: { completed_action_ids: actionId },
        $set: { updated_at: now, user_id: userId }
      }
    );
  }

  const updatedDoc = await db.collection('partner_completed_actions').findOne({
    connection_id: connectionId,
    date_key: dateKey,
  });

  return updatedDoc?.completed_action_ids || [];
}

async function checkDistributedRateLimit({ key, limit, windowSeconds }) {
  const collection = db.collection('partner_rate_limit_events');
  const now = new Date();
  const cutoff = new Date(now.getTime() - windowSeconds * 1000);

  const count = await collection.countDocuments({
    key,
    created_at: { $gte: cutoff }
  });

  if (count >= limit) {
    return false;
  }

  await collection.insertOne({
    key,
    created_at: now
  });

  return true;
}

async function createShareableInvite({ senderUserId, tokenHash, expiresAt }) {
  const invitationId = randomUUID();
  const doc = {
    invitation_id: invitationId,
    sender_user_id: senderUserId,
    receiver_user_id: null,
    receiver_email: null,
    invite_token: randomUUID(),
    invite_token_hash: tokenHash,
    status: 'pending',
    responded_at: null,
    expires_at: expiresAt || new Date(Date.now() + 48 * 60 * 60 * 1000),
    created_at: new Date(),
    updated_at: new Date(),
  };

  await db.collection('partner_invitations').insertOne(doc);
  return mapInvitationRow(doc);
}

async function claimInviteTokenHash({ claimerUserId, tokenHash }) {
  const now = new Date();
  const invitationDoc = await db.collection('partner_invitations').findOne({
    invite_token_hash: tokenHash,
    status: 'pending',
    expires_at: { $gt: now }
  });

  if (!invitationDoc) {
    return { error: 'INVALID_OR_EXPIRED_TOKEN' };
  }

  if (invitationDoc.sender_user_id === claimerUserId) {
    return { error: 'CANNOT_CLAIM_OWN_INVITE' };
  }

  const alreadyConnected = await hasConnectionBetween(invitationDoc.sender_user_id, claimerUserId);
  if (alreadyConnected) {
    return { error: 'ALREADY_CONNECTED' };
  }

  const claimerUser = await findUserDocument({ user_id: claimerUserId });
  const senderUser = await findUserDocument({ user_id: invitationDoc.sender_user_id });

  if (!claimerUser || !senderUser) {
    return { error: 'USER_NOT_FOUND' };
  }

  const updateResult = await db.collection('partner_invitations').updateOne(
    {
      invitation_id: invitationDoc.invitation_id,
      status: 'pending'
    },
    {
      $set: {
        receiver_user_id: claimerUserId,
        receiver_email: claimerUser.email,
        status: 'accepted',
        responded_at: now,
        updated_at: now
      }
    }
  );

  if (updateResult.modifiedCount === 0) {
    return { error: 'ALREADY_CLAIMED' };
  }

  const permissionOwnerUserId = resolvePermissionOwner({
    senderUserId: senderUser.user_id,
    senderRole: senderUser.role,
    receiverUserId: claimerUser.user_id,
    receiverRole: claimerUser.role,
  });

  const connectionId = randomUUID();
  const connectionDoc = {
    connection_id: connectionId,
    invitation_id: invitationDoc.invitation_id,
    user_a_id: senderUser.user_id,
    user_b_id: claimerUser.user_id,
    permission_owner_user_id: permissionOwnerUserId,
    permissions: {
      shareMood: true,
      shareCycle: true,
      shareSleep: true,
      shareInsights: true,
      shareOnboarding: true,
      allowAiSuggestionsWoman: true,
      allowAiSuggestionsMan: true,
      allowDecoderMan: true,
    },
    status: 'active',
    sender_accepted_at: now,
    receiver_accepted_at: now,
    breakup_requested_by_user_id: null,
    breakup_requested_at: null,
    ended_at: null,
    created_at: now,
    updated_at: now,
  };

  await db.collection('partner_connections').insertOne(connectionDoc);

  await createNotification({
    connectionId,
    recipientUserId: senderUser.user_id,
    dataType: 'invitation',
  });

  return {
    connection: connectionDoc,
    partner: {
      userId: senderUser.user_id,
      email: senderUser.email,
      displayName: senderUser.display_name || senderUser.email?.split('@')[0],
      role: senderUser.role
    }
  };
}

export const partnerRepository = {
  getUserByEmail,
  hasConnectionBetween,
  hasOpenRelationshipForUser,
  hasPendingInvitationFrom,
  createInvitation,
  createShareableInvite,
  claimInviteTokenHash,
  checkDistributedRateLimit,
  getPendingInvitationBetween,
  listIncomingInvitations,
  listOutgoingInvitations,
  getInvitationById,
  createConnectionForInvitation,
  respondToInvitation,
  respondToConnection,
  requestBreakup,
  listConnectionsForUser,
  getConnectionForUser,
  updateConnectionPermissions,
  listMessagesForConnection,
  sendMessageToConnection,
  deleteConnectionHistory,
  getSharedData,
  markDataViewed,
  createNotification,
  listNotificationsForUser,
  markNotificationsReadForUser,
  getActiveConnectionForUser,
  getCompletedSupportActions,
  toggleCompletedSupportAction,
  listSharedActivities,
  setSharedActivityStatus,
};
