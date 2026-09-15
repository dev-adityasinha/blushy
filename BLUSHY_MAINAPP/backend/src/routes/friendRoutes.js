import { Router } from 'express';
import {
  acceptFriendRequest,
  listFriends,
  listPendingRequests,
  rejectFriendRequest,
  searchUsers,
  sendFriendRequest,
} from '../controllers/friendController.js';
import { optionalAuth } from '../middleware/optionalAuth.js';

const router = Router();

router.get('/', optionalAuth, listFriends);
router.get('/search', optionalAuth, searchUsers);
router.get('/pending', optionalAuth, listPendingRequests);
router.post('/request/:recipientId', optionalAuth, sendFriendRequest);
router.post('/request/:senderId/accept', optionalAuth, acceptFriendRequest);
router.post('/request/:senderId/reject', optionalAuth, rejectFriendRequest);

export default router;
