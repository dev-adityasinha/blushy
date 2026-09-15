import { Router } from 'express';

import { requireAuth } from '../middleware/requireAuth.js';
import {
  listMyCapsules,
  createMyCapsule,
  getMyCapsule,
  openMyCapsule,
  deleteMyCapsule,
} from '../controllers/timeCapsuleController.js';

/**
 * Time capsules (spec section 12). Something written now, opened later.
 */
const router = Router();

router.get('/', requireAuth, listMyCapsules);
router.post('/', requireAuth, createMyCapsule);
router.get('/:capsuleId', requireAuth, getMyCapsule);
router.post('/:capsuleId/open', requireAuth, openMyCapsule);
router.delete('/:capsuleId', requireAuth, deleteMyCapsule);

export default router;
