import { Router } from 'express';

import { getFeatureClickStats, trackFeatureClick, getUserActivityStats } from '../controllers/featureController.js';
import { optionalAuth } from '../middleware/optionalAuth.js';

const router = Router();

router.post('/:featureKey/click', optionalAuth, trackFeatureClick);
router.get('/stats', optionalAuth, getFeatureClickStats);
router.get('/activity-report', optionalAuth, getUserActivityStats);

export default router;
