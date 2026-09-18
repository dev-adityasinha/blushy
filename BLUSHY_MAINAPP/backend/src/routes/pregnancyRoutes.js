import { Router } from 'express';
import {
  getPregnancyOverview,
  getTodayBrief,
  recordPregnancyCheckIn,
  getPregnancyBaseline,
  classifySymptom,
  savePregnancyMemory,
  getPregnancyMemories,
  savePregnancyQuestion,
  getPregnancyQuestions,
} from '../controllers/pregnancyController.js';
import { requireAuth } from '../middleware/requireAuth.js';

const router = Router();

router.get('/', requireAuth, getPregnancyOverview);
router.get('/overview', requireAuth, getPregnancyOverview);
router.get('/today-brief', requireAuth, getTodayBrief);
router.post('/check-in', requireAuth, recordPregnancyCheckIn);
router.get('/baseline', requireAuth, getPregnancyBaseline);
router.post('/is-this-normal', requireAuth, classifySymptom);
router.get('/is-this-normal', requireAuth, classifySymptom);
router.post('/memory', requireAuth, savePregnancyMemory);
router.get('/memories', requireAuth, getPregnancyMemories);
router.post('/question', requireAuth, savePregnancyQuestion);
router.get('/questions', requireAuth, getPregnancyQuestions);

export default router;
