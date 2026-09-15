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
import { optionalAuth } from '../middleware/optionalAuth.js';

const router = Router();

router.get('/', optionalAuth, getPregnancyOverview);
router.get('/overview', optionalAuth, getPregnancyOverview);
router.get('/today-brief', optionalAuth, getTodayBrief);
router.post('/check-in', optionalAuth, recordPregnancyCheckIn);
router.get('/baseline', optionalAuth, getPregnancyBaseline);
router.post('/is-this-normal', optionalAuth, classifySymptom);
router.get('/is-this-normal', optionalAuth, classifySymptom);
router.post('/memory', optionalAuth, savePregnancyMemory);
router.get('/memories', optionalAuth, getPregnancyMemories);
router.post('/question', optionalAuth, savePregnancyQuestion);
router.get('/questions', optionalAuth, getPregnancyQuestions);

export default router;
