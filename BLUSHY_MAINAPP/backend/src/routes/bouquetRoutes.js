import { Router } from 'express';

import { requireAuth } from '../middleware/requireAuth.js';
import {
  listMyBouquets,
  createMyBouquet,
  sendMyBouquet,
  openMyBouquet,
  deleteMyBouquet,
} from '../controllers/bouquetController.js';

/**
 * Digital bouquets (spec section 21). Made, kept, and given.
 */
const router = Router();

router.get('/', requireAuth, listMyBouquets);
router.post('/', requireAuth, createMyBouquet);
router.post('/:bouquetId/send', requireAuth, sendMyBouquet);
router.post('/:bouquetId/open', requireAuth, openMyBouquet);
router.delete('/:bouquetId', requireAuth, deleteMyBouquet);

export default router;
