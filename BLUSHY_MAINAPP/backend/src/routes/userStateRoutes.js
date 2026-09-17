import { Router } from 'express';

import {
  getUserState,
  putUserState,
  deleteUserState,
} from '../controllers/userStateController.js';
import { requireAuth } from '../middleware/requireAuth.js';

const router = Router();

// Her own documents, so every route is authenticated and scoped to the token.
// The key never selects a user; `req.user.userId` does.
router.get('/', requireAuth, getUserState);
router.put('/:key', requireAuth, putUserState);
router.delete('/:key', requireAuth, deleteUserState);

export default router;
