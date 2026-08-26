import { Router } from 'express';
import {
  listConversations,
  listMessages,
  sendMessage,
} from '../controllers/directMessageController.js';
import { uploadDirectMessageImage } from '../middleware/uploadMiddleware.js';
import { optionalAuth } from '../middleware/optionalAuth.js';

const router = Router();

router.get('/conversations', optionalAuth, listConversations);
router.get('/:friendId/messages', optionalAuth, listMessages);
router.post('/:recipientId/messages', optionalAuth, uploadDirectMessageImage, sendMessage);

export default router;
