import { Router } from 'express';
import {
  getPregnancyOverview,
  getTodayBrief,
  recordPregnancyCheckIn,
  getPregnancyBaseline,
  classifySymptom,
  checkFoodSafety,
  savePregnancyMemory,
  getPregnancyMemories,
  savePregnancyQuestion,
  getPregnancyQuestions,
} from '../controllers/pregnancyController.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { optionalAuth } from '../middleware/optionalAuth.js';

const router = Router();

router.get('/', requireAuth, getPregnancyOverview);
router.get('/overview', requireAuth, getPregnancyOverview);
router.get('/today-brief', optionalAuth, getTodayBrief);
router.post('/check-in', requireAuth, recordPregnancyCheckIn);
router.get('/baseline', requireAuth, getPregnancyBaseline);
router.post('/is-this-normal', optionalAuth, classifySymptom);
router.get('/is-this-normal', optionalAuth, classifySymptom);
router.post('/safety-check', optionalAuth, checkFoodSafety);
router.get('/safety-check', optionalAuth, checkFoodSafety);
router.post('/memory', requireAuth, savePregnancyMemory);
router.get('/memories', requireAuth, getPregnancyMemories);
router.post('/question', requireAuth, savePregnancyQuestion);
router.get('/questions', requireAuth, getPregnancyQuestions);

export default router;
