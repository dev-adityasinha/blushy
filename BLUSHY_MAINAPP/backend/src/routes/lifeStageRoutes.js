import { Router } from 'express';
import { requireAuth } from '../middleware/requireAuth.js';
import {
  getCurrentStage,
  getJourneys,
  getBranchQuestions,
  changeStage,
  saveBranchContext,
  exitPregnancy,
  getHistory,
  updateTtcOptIn,
} from '../controllers/lifeStageController.js';

/**
 * Life stage engine routes (spec §3, §4, §23).
 */
const router = Router();

router.get('/journeys', getJourneys);
router.get('/journeys/:stage/questions', getBranchQuestions);

router.get('/', requireAuth, getCurrentStage);
router.post('/transition', requireAuth, changeStage);
router.put('/context', requireAuth, saveBranchContext);
router.post('/pregnancy/end', requireAuth, exitPregnancy);
router.get('/history', requireAuth, getHistory);
router.put('/ttc-opt-in', requireAuth, updateTtcOptIn);

export default router;
