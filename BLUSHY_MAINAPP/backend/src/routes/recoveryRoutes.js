import { Router } from 'express';

import { requireAuth } from '../middleware/requireAuth.js';
import {
  listRecoverySessions,
  getRecoverySession,
  completeRecoverySession,
} from '../controllers/recoveryController.js';

/**
 * Guided recovery sessions (spec sections 12, 27). Served from the reviewed
 * content pipeline, so an unreviewed session does not appear at all.
 */
const router = Router();

router.get('/sessions', requireAuth, listRecoverySessions);
router.get('/sessions/:sessionId', requireAuth, getRecoverySession);
router.post('/sessions/:sessionId/complete', requireAuth, completeRecoverySession);

export default router;
