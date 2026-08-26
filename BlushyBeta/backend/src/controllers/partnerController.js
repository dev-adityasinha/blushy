import { partnerRepository } from '../repositories/partnerRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { createHttpError } from '../utils/httpError.js';
import { publishToUsers } from '../utils/realtimeHub.js';

async function requireAuthUser(req) {
  const userId = req.user?.userId;
  if (!userId) {
    throw createHttpError(401, 'Authentication required.');
  }

  const user = await userRepository.getUserById(userId);
  if (!user) {
    throw createHttpError(404, 'User not found.');
  }

  return user;
}

function normalizeEmail(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim().toLowerCase();
  if (!normalized || !normalized.includes('@') || !normalized.includes('.')) {
    return null;
  }

  return normalized;
}

function sanitizePermissionPatch(payload) {
  return {
    shareMood: payload?.shareMood,
    shareCycle: payload?.shareCycle,
    shareSleep: payload?.shareSleep,
    shareInsights: payload?.shareInsights,
    shareOnboarding: payload?.shareOnboarding,
    allowAiSuggestionsWoman: payload?.allowAiSuggestionsWoman,
    allowAiSuggestionsMan: payload?.allowAiSuggestionsMan,
    allowDecoderMan: payload?.allowDecoderMan,
  };
}

export async function invitePartner(req, res, next) {
  try {
    const sender = await requireAuthUser(req);
    const partnerEmail = normalizeEmail(req.body?.partnerEmail);

    if (!partnerEmail) {
      throw createHttpError(400, 'Valid partner email is required.');
    }

    if (!sender.email || sender.email.toLowerCase() === partnerEmail) {
      throw createHttpError(400, 'You cannot invite your own email.');
    }

    const receiver = await partnerRepository.getUserByEmail(partnerEmail);
    if (!receiver) {
      throw createHttpError(404, 'No account found for this email. Ask them to signup first.');
    }

    const alreadyConnected = await partnerRepository.hasConnectionBetween(sender.user_id, receiver.userId);
    if (alreadyConnected) {
      throw createHttpError(409, 'You are already connected with this account.');
    }

    const pendingId = await partnerRepository.getPendingInvitationBetween(sender.user_id, receiver.userId);
    if (pendingId) {
      throw createHttpError(409, 'A pending invitation already exists between these accounts.');
    }

    const invitation = await partnerRepository.createInvitation({
      senderUserId: sender.user_id,
      receiverUserId: receiver.userId,
      receiverEmail: receiver.email,
    });

    publishToUsers(
      [sender.user_id, receiver.userId],
      'partner.updated',
      {
        reason: 'invitation-sent',
        invitationId: invitation.invitationId,
      },
    );

    res.status(201).json({
      message: 'Invitation sent successfully.',
      invitation,
    });
  } catch (error) {
    next(error);
  }
}

export async function listIncomingPartnerInvitations(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    const invitations = await partnerRepository.listIncomingInvitations(user.user_id);
    res.status(200).json({ invitations });
  } catch (error) {
    next(error);
  }
}

export async function listOutgoingPartnerInvitations(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    const invitations = await partnerRepository.listOutgoingInvitations(user.user_id);
    res.status(200).json({ invitations });
  } catch (error) {
    next(error);
  }
}

export async function respondToPartnerInvitation(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    const invitationId = String(req.params?.invitationId ?? '').trim();
    const action = String(req.body?.action ?? '').trim().toLowerCase();

    if (!invitationId) {
      throw createHttpError(400, 'Invitation id is required.');
    }

    if (action !== 'accept' && action !== 'reject') {
      throw createHttpError(400, 'Action must be accept or reject.');
    }

    const result = await partnerRepository.respondToInvitation({
      invitationId,
      receiverUserId: user.user_id,
      action,
    });

    if (action === 'accept' && result.connectionId) {
      publishToUsers(
        [result.invitation.senderUserId, result.invitation.receiverUserId],
        'partner.updated',
        {
          reason: 'connection-requested',
          invitationId: result.invitation.invitationId,
          connectionId: result.connectionId,
        },
      );
    }

    if (!result.invitation) {
      throw createHttpError(404, 'Invitation not found.');
    }

    publishToUsers(
      [result.invitation.senderUserId, result.invitation.receiverUserId],
      'partner.updated',
      {
        reason: action === 'accept' ? 'invitation-accepted' : 'invitation-rejected',
        invitationId: result.invitation.invitationId,
        connectionId: result.connectionId,
      },
    );

    res.status(200).json({
      message: action === 'accept' ? 'Invitation accepted.' : 'Invitation rejected.',
      invitation: result.invitation,
      connectionId: result.connectionId,
    });
  } catch (error) {
    if (error?.message === 'FORBIDDEN_INVITATION_RESPONSE') {
      next(createHttpError(403, 'You are not allowed to respond to this invitation.'));
      return;
    }

    next(error);
  }
}

export async function respondToPartnerConnection(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    const connectionId = String(req.params?.connectionId ?? '').trim();
    const action = String(req.body?.action ?? '').trim().toLowerCase();

    if (!connectionId) {
      throw createHttpError(400, 'Connection id is required.');
    }

    if (action !== 'accept' && action !== 'reject') {
      throw createHttpError(400, 'Action must be accept or reject.');
    }

    const connection = await partnerRepository.respondToConnection({
      connectionId,
      actorUserId: user.user_id,
      action,
    });

    publishToUsers(
      [user.user_id],
      'partner.updated',
      {
        reason: action === 'accept' ? 'connection-accepted' : 'connection-rejected',
        connectionId,
      },
    );

    if (connection) {
      publishToUsers(
        [connection.partnerUserId, user.user_id],
        'partner.updated',
        {
          reason: action === 'accept' ? 'connection-accepted' : 'connection-rejected',
          connectionId,
        },
      );
    }

    res.status(200).json({
      message: action === 'accept' ? 'Connection accepted.' : 'Connection rejected.',
      connection,
    });
  } catch (error) {
    if (error?.message === 'FORBIDDEN_CONNECTION_RESPONSE') {
      next(createHttpError(403, 'You are not allowed to respond to this connection.'));
      return;
    }

    if (error?.message === 'INVALID_CONNECTION_STATE') {
      next(createHttpError(409, 'This connection is not waiting for confirmation.'));
      return;
    }

    next(error);
  }
}

export async function listPartnerConnections(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    const connections = await partnerRepository.listConnectionsForUser(user.user_id);
    res.status(200).json({ connections });
  } catch (error) {
    next(error);
  }
}

export async function updatePartnerPermissions(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    const connectionId = String(req.params?.connectionId ?? '').trim();

    if (!connectionId) {
      throw createHttpError(400, 'Connection id is required.');
    }

    const connection = await partnerRepository.updateConnectionPermissions({
      connectionId,
      actorUserId: user.user_id,
      permissionPatch: sanitizePermissionPatch(req.body),
    });

    if (!connection) {
      throw createHttpError(404, 'Connection not found.');
    }

    publishToUsers(
      [user.user_id, connection.partnerUserId],
      'partner.updated',
      {
        reason: 'permissions-updated',
        connectionId: connection.connectionId,
      },
    );

    res.status(200).json({
      message: 'Permissions updated successfully.',
      connection,
    });
  } catch (error) {
    if (error?.message === 'FORBIDDEN_PERMISSION_UPDATE') {
      next(createHttpError(403, 'Only the permission owner can update access controls.'));
      return;
    }

    next(error);
  }
}

export async function requestPartnerBreakup(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    const connectionId = String(req.params?.connectionId ?? '').trim();

    if (!connectionId) {
      throw createHttpError(400, 'Connection id is required.');
    }

    const current = await partnerRepository.requestBreakup({
      connectionId,
      actorUserId: user.user_id,
    });

    const breakupCompleted = current?.status === 'breakup';

    publishToUsers(
      [user.user_id],
      'partner.updated',
      {
        reason: breakupCompleted ? 'breakup-completed' : 'breakup-requested',
        connectionId,
      },
    );

    publishToUsers(
      [current.partnerUserId, user.user_id],
      'partner.updated',
      {
        reason: breakupCompleted ? 'breakup-completed' : 'breakup-requested',
        connectionId,
      },
    );

    res.status(200).json({
      message: breakupCompleted
        ? 'Breakup completed.'
        : current.status === 'breakup_pending'
            ? 'Breakup request recorded.'
            : 'Breakup requested.',
      connection: current,
    });
  } catch (error) {
    next(error);
  }
}

export async function listPartnerMessages(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    const connectionId = String(req.params?.connectionId ?? '').trim();

    if (!connectionId) {
      throw createHttpError(400, 'Connection id is required.');
    }

    const messages = await partnerRepository.listMessagesForConnection(connectionId, user.user_id);
    if (!messages) {
      throw createHttpError(404, 'Connection not found.');
    }

    res.status(200).json({ messages });
  } catch (error) {
    next(error);
  }
}
export async function sendPartnerMessage(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    const connectionId = String(req.params?.connectionId ?? '').trim();
    const message = String(req.body?.message ?? '').trim();

    if (!connectionId) {
      throw createHttpError(400, 'Connection id is required.');
    }

    if (!message && !req.file) {
      throw createHttpError(400, 'Message or file attachment is required.');
    }

    let audioUrl = null;
    let audioDuration = null;
    let fileUrl = null;
    let fileName = null;
    let fileType = null;
    let imageUrl = null;

    if (req.file) {
      const relativeUrl = `/uploads/partner_chat/${req.file.filename}`;
      const mimetype = req.file.mimetype || '';
      const isAudio = mimetype.startsWith('audio/') ||
                      mimetype === 'video/webm' ||
                      /\.(webm|mp3|wav|m4a|ogg)$/i.test(req.file.originalname || '');
      if (isAudio) {
        audioUrl = relativeUrl;
        audioDuration = Number(req.body.duration || 0);
      } else if (mimetype.startsWith('image/')) {
        imageUrl = relativeUrl;
      } else {
        fileUrl = relativeUrl;
        fileName = req.file.originalname;
        fileType = mimetype;
      }
    }

    const sent = await partnerRepository.sendMessageToConnection({
      connectionId,
      senderUserId: user.user_id,
      message,
      audioUrl,
      audioDuration,
      fileUrl,
      fileName,
      fileType,
      imageUrl,
    });

    if (!sent) {
      throw createHttpError(404, 'Connection not found.');
    }

    const connection = await partnerRepository.getConnectionForUser(connectionId, user.user_id);
    if (connection) {
      const sender = await userRepository.getUserById(user.user_id);
      const senderName = sender?.display_name || sender?.email || 'Partner';
      publishToUsers(
        [connection.partnerUserId, user.user_id],
        'partner.updated',
        {
          reason: 'message-sent',
          connectionId,
          senderUserId: user.user_id,
          senderName,
          messageText: typeof message === 'string' && message.trim() ? message.trim() : 'Sent a voice/media file',
        },
      );
    }

    res.status(201).json({ message: sent });
  } catch (error) {
    if (error?.message === 'CONNECTION_NOT_ACTIVE') {
      next(createHttpError(409, 'You can only chat after both sides accept.'));
      return;
    }

    if (error?.message === 'EMPTY_PARTNER_MESSAGE') {
      next(createHttpError(400, 'Message cannot be empty.'));
      return;
    }

    next(error);
  }
}

export async function getPartnerSharedData(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    const connectionId = String(req.params?.connectionId ?? '').trim();

    if (!connectionId) {
      throw createHttpError(400, 'Connection id is required.');
    }

    const data = await partnerRepository.getSharedData({
      connectionId,
      viewerUserId: user.user_id,
    });

    if (!data) {
      throw createHttpError(404, 'Connection not found or not active.');
    }

    res.status(200).json({ data });
  } catch (error) {
    next(error);
  }
}

export async function markPartnerDataViewed(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    const connectionId = String(req.params?.connectionId ?? '').trim();
    const dataType = String(req.body?.dataType ?? '').trim().toLowerCase();
    const validTypes = new Set(['mood', 'cycle', 'sleep', 'insights', 'onboarding']);

    if (!connectionId) {
      throw createHttpError(400, 'Connection id is required.');
    }

    if (!validTypes.has(dataType)) {
      throw createHttpError(400, 'Valid data type is required.');
    }

    await partnerRepository.markDataViewed({
      connectionId,
      viewerUserId: user.user_id,
      dataType,
    });

    res.status(200).json({ message: 'Marked as viewed.' });
  } catch (error) {
    next(error);
  }
}

export async function listPartnerNotifications(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    const notifications = await partnerRepository.listNotificationsForUser(user.user_id);
    res.status(200).json({ notifications });
  } catch (error) {
    next(error);
  }
}

export async function markPartnerNotificationsRead(req, res, next) {
  try {
    const user = await requireAuthUser(req);
    await partnerRepository.markNotificationsReadForUser(user.user_id);
    res.status(200).json({ message: 'Notifications marked as read.' });
  } catch (error) {
    next(error);
  }
}

export async function getPartnerStatusController(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(200).json({ status: 'unconnected', connections: [] });
    }
    const connections = await partnerRepository.listConnectionsForUser(userId);
    res.status(200).json({
      status: connections.length > 0 ? 'connected' : 'unconnected',
      connections,
    });
  } catch (error) {
    next(error);
  }
}
