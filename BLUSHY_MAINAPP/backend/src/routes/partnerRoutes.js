import { Router } from 'express';

import {
  createPartnerInviteLink,
  claimPartnerInviteCode,
  getPartnerSharedData,
  getPartnerStatusController,
  invitePartner,
  listIncomingPartnerInvitations,
  listOutgoingPartnerInvitations,
  listPartnerConnections,
  listPartnerMessages,
  listPartnerNotifications,
  markPartnerNotificationsRead,
  markPartnerDataViewed,
  requestPartnerBreakup,
  respondToPartnerConnection,
  respondToPartnerInvitation,
  sendPartnerMessage,
  updatePartnerPermissions,
  toggleSupportAction,
  decodePartnerMessageController,
} from '../controllers/partnerController.js';
import { optionalAuth } from '../middleware/optionalAuth.js';
import { uploadPartnerAttachment } from '../middleware/uploadMiddleware.js';

const router = Router();

router.get('/status', optionalAuth, getPartnerStatusController);
router.post('/invite', optionalAuth, invitePartner);
router.post('/invite/link', optionalAuth, createPartnerInviteLink);
router.post('/invite/claim', optionalAuth, claimPartnerInviteCode);
router.get('/requests/incoming', optionalAuth, listIncomingPartnerInvitations);
router.get('/requests/outgoing', optionalAuth, listOutgoingPartnerInvitations);
router.post('/requests/:invitationId/respond', optionalAuth, respondToPartnerInvitation);
router.post('/connections/:connectionId/respond', optionalAuth, respondToPartnerConnection);
router.get('/connections', optionalAuth, listPartnerConnections);
router.patch('/connections/:connectionId/permissions', optionalAuth, updatePartnerPermissions);
router.get('/connections/:connectionId/shared-data', optionalAuth, getPartnerSharedData);
router.post('/connections/:connectionId/shared-data/view', optionalAuth, markPartnerDataViewed);
router.post('/connections/:connectionId/support-actions/toggle', optionalAuth, toggleSupportAction);
router.post('/connections/:connectionId/decode-message', optionalAuth, decodePartnerMessageController);
router.get('/connections/:connectionId/messages', optionalAuth, listPartnerMessages);
router.post('/connections/:connectionId/messages', optionalAuth, uploadPartnerAttachment, sendPartnerMessage);
router.post('/connections/:connectionId/breakup', optionalAuth, requestPartnerBreakup);
router.get('/notifications', optionalAuth, listPartnerNotifications);
router.post('/notifications/read', optionalAuth, markPartnerNotificationsRead);

export default router;
