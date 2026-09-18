/**
 * postpartumRoutes.js
 * Express router for Postpartum Command Center.
 */

import { Router } from 'express';
import {
  getPostpartumOverview,
  getPostpartumTodayBrief,
  calibratePostpartum,
  recordPostpartumCheckin,
  recordBabyEvent,
  getBabyEvents,
  generateHelpSOS,
  evaluateSafetyTriage,
} from '../controllers/postpartumController.js';
import { requireAuth } from '../middleware/requireAuth.js';

const router = Router();

router.get('/', requireAuth, getPostpartumOverview);
router.get('/overview', requireAuth, getPostpartumOverview);
router.get('/today-brief', requireAuth, getPostpartumTodayBrief);
router.post('/calibrate', requireAuth, calibratePostpartum);
router.post('/check-in', requireAuth, recordPostpartumCheckin);
router.post('/checkin', requireAuth, recordPostpartumCheckin);
router.post('/baby-event', requireAuth, recordBabyEvent);
router.get('/baby-events', requireAuth, getBabyEvents);
router.post('/sos', requireAuth, generateHelpSOS);
router.post('/safety-triage', requireAuth, evaluateSafetyTriage);

export default router;
