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
import { optionalAuth } from '../middleware/optionalAuth.js';

const router = Router();

router.get('/', optionalAuth, getPostpartumOverview);
router.get('/overview', optionalAuth, getPostpartumOverview);
router.get('/today-brief', optionalAuth, getPostpartumTodayBrief);
router.post('/calibrate', optionalAuth, calibratePostpartum);
router.post('/check-in', optionalAuth, recordPostpartumCheckin);
router.post('/checkin', optionalAuth, recordPostpartumCheckin);
router.post('/baby-event', optionalAuth, recordBabyEvent);
router.get('/baby-events', optionalAuth, getBabyEvents);
router.post('/sos', optionalAuth, generateHelpSOS);
router.post('/safety-triage', optionalAuth, evaluateSafetyTriage);

export default router;
