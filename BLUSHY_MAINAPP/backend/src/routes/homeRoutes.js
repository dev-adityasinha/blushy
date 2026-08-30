import { Router } from 'express';
import { requireAuth } from '../middleware/requireAuth.js';
import {
  getHomeScreen,
  getCycle,
  createPeriodLog,
  deletePeriodLog,
  getPeriodHistory,
  getPatternsCard,
  refreshPatterns,
  dismissPatternInsight,
  submitPatternFeedback,
  viewPatternInsight,
  getCarePlanCard,
  completeCareAction,
  dismissCareAction,
  getPregnancy,
  getPostpartum,
  getFertility,
  getReflectionCard,
  saveReflection,
  getReflectionHistory,
  getConditions,
  saveConditions,
} from '../controllers/homeController.js';

/**
 * Home, cycle, patterns, care plan, branch module and reflection routes
 * (spec §5, §6, §8, §10, §12).
 */
const router = Router();

router.get('/home', requireAuth, getHomeScreen);

router.get('/cycle', requireAuth, getCycle);
router.post('/cycle/periods', requireAuth, createPeriodLog);
router.get('/cycle/periods', requireAuth, getPeriodHistory);
router.delete('/cycle/periods/:entryId', requireAuth, deletePeriodLog);

router.get('/patterns', requireAuth, getPatternsCard);
router.post('/patterns/refresh', requireAuth, refreshPatterns);
router.post('/patterns/:insightId/dismiss', requireAuth, dismissPatternInsight);
router.post('/patterns/:insightId/feedback', requireAuth, submitPatternFeedback);
router.post('/patterns/:insightId/view', requireAuth, viewPatternInsight);

router.get('/care-plan', requireAuth, getCarePlanCard);
router.post('/care-plan/:actionId/complete', requireAuth, completeCareAction);
router.post('/care-plan/:actionId/dismiss', requireAuth, dismissCareAction);

router.get('/conditions', requireAuth, getConditions);
router.put('/conditions', requireAuth, saveConditions);

router.get('/pregnancy', requireAuth, getPregnancy);
router.get('/postpartum', requireAuth, getPostpartum);
router.get('/fertility', requireAuth, getFertility);

router.get('/reflections/current', requireAuth, getReflectionCard);
router.put('/reflections', requireAuth, saveReflection);
router.get('/reflections', requireAuth, getReflectionHistory);

export default router;
