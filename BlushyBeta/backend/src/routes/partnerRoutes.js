import { Router } from 'express';

import {
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
} from '../controllers/partnerController.js';
import { optionalAuth } from '../middleware/optionalAuth.js';
import { uploadPartnerAttachment } from '../middleware/uploadMiddleware.js';

const router = Router();

router.get('/status', optionalAuth, getPartnerStatusController);
router.post('/invite', optionalAuth, invitePartner);
router.get('/requests/incoming', optionalAuth, listIncomingPartnerInvitations);
router.get('/requests/outgoing', optionalAuth, listOutgoingPartnerInvitations);
router.post('/requests/:invitationId/respond', optionalAuth, respondToPartnerInvitation);
router.post('/connections/:connectionId/respond', optionalAuth, respondToPartnerConnection);
router.get('/connections', optionalAuth, listPartnerConnections);
router.patch('/connections/:connectionId/permissions', optionalAuth, updatePartnerPermissions);
router.get('/connections/:connectionId/shared-data', optionalAuth, getPartnerSharedData);
router.post('/connections/:connectionId/shared-data/view', optionalAuth, markPartnerDataViewed);
router.get('/connections/:connectionId/messages', optionalAuth, listPartnerMessages);
router.post('/connections/:connectionId/messages', optionalAuth, uploadPartnerAttachment, sendPartnerMessage);
router.post('/connections/:connectionId/breakup', optionalAuth, requestPartnerBreakup);
router.get('/notifications', optionalAuth, listPartnerNotifications);
router.post('/notifications/read', optionalAuth, markPartnerNotificationsRead);

export default router;
