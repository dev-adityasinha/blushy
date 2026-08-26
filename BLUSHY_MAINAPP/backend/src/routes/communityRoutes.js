import { Router } from 'express';

import {
  createCommunity,
  deleteCommunity,
  followCommunity,
  listCommunities,
  listMessages,
  sendMessage,
  unfollowCommunity,
  listPendingRequests,
  approveRequest,
  rejectRequest,
  listGroupMembers,
  promoteMember,
  updateDetails,
} from '../controllers/communityController.js';
import { uploadCommunityImage } from '../middleware/uploadMiddleware.js';
import { optionalAuth } from '../middleware/optionalAuth.js';

const router = Router();

router.get('/', optionalAuth, listCommunities);
router.post('/', optionalAuth, createCommunity);
router.delete('/:communityId', optionalAuth, deleteCommunity);
router.post('/:communityId/follow', optionalAuth, followCommunity);
router.post('/:communityId/unfollow', optionalAuth, unfollowCommunity);
router.get('/:communityId/messages', optionalAuth, listMessages);
router.post('/:communityId/messages', optionalAuth, uploadCommunityImage, sendMessage);
router.get('/:communityId/requests', optionalAuth, listPendingRequests);
router.post('/:communityId/requests/:userId/approve', optionalAuth, approveRequest);
router.post('/:communityId/requests/:userId/reject', optionalAuth, rejectRequest);
router.get('/:communityId/members', optionalAuth, listGroupMembers);
router.post('/:communityId/members/:userId/promote', optionalAuth, promoteMember);
router.patch('/:communityId/details', optionalAuth, uploadCommunityImage, updateDetails);

export default router;
