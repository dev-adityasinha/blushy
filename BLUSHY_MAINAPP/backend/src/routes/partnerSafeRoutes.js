import { Router } from 'express';
import { requireAuth } from '../middleware/requireAuth.js';
import {
  getPermissionMatrix,
  getMySharingState,
  patchPermissions,
  getPermissionHistory,
  createPermissionRequest,
  listPermissionRequestsController,
  respondToPermissionRequestController,
  withdrawPermissionRequestController,
  getSharedGardenController,
  growSharedGardenController,
  getPartnerHomeScreen,
  getPartnerContext,
  getUsSurface,
  getSupportRequestTypes,
  createRequest,
  listRequests,
  updateRequestState,
  revokeConnectionRequests,
} from '../controllers/partnerSafeController.js';

/**
 * Partner-safe routes (spec §9, §10, §11, §19, §20, §21).
 *
 * Authorization is mandatory everywhere: partner surfaces must never rely on
 * the frontend hiding data (spec §28).
 */
const router = Router();

router.get('/permission-matrix', getPermissionMatrix);
router.get('/support-request-types', getSupportRequestTypes);

router.get('/connections/:connectionId/sharing', requireAuth, getMySharingState);
router.patch('/connections/:connectionId/sharing', requireAuth, patchPermissions);
router.get('/connections/:connectionId/sharing/history', requireAuth, getPermissionHistory);

// A partner asking to be shown something that is currently off. Asking never
// shares anything; only the owner's approval does.
router.post('/connections/:connectionId/sharing/requests', requireAuth, createPermissionRequest);
router.get('/connections/:connectionId/sharing/requests', requireAuth, listPermissionRequestsController);
router.post('/sharing/requests/:requestId/respond', requireAuth, respondToPermissionRequestController);
router.post('/sharing/requests/:requestId/withdraw', requireAuth, withdrawPermissionRequestController);

// The garden belongs to the connection: whatever one partner does, the other
// sees. It used to live in one phone's local storage.
router.get('/connections/:connectionId/garden', requireAuth, getSharedGardenController);
router.post('/connections/:connectionId/garden/grow', requireAuth, growSharedGardenController);

router.get('/connections/:connectionId/home', requireAuth, getPartnerHomeScreen);
router.get('/connections/:connectionId/context', requireAuth, getPartnerContext);
router.get('/connections/:connectionId/us', requireAuth, getUsSurface);

router.get('/connections/:connectionId/support-requests', requireAuth, listRequests);
router.post('/connections/:connectionId/support-requests', requireAuth, createRequest);
router.post('/connections/:connectionId/support-requests/revoke-all', requireAuth, revokeConnectionRequests);
router.patch('/support-requests/:requestId', requireAuth, updateRequestState);

export default router;
