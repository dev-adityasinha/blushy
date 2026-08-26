import { Router } from 'express';
import { createPost, listFeed } from '../controllers/postController.js';
import { uploadPostImage } from '../middleware/uploadMiddleware.js';
import { optionalAuth } from '../middleware/optionalAuth.js';

const router = Router();

router.get('/feed', optionalAuth, listFeed);
router.post('/', optionalAuth, uploadPostImage, createPost);

export default router;
