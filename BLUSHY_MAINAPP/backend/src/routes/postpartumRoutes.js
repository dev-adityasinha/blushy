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
  checkPostpartumSafety,
} from '../controllers/postpartumController.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { optionalAuth } from '../middleware/optionalAuth.js';

const router = Router();

router.get('/', optionalAuth, getPostpartumOverview);
router.get('/overview', optionalAuth, getPostpartumOverview);
router.get('/today-brief', optionalAuth, getPostpartumTodayBrief);
router.post('/calibrate', requireAuth, calibratePostpartum);
router.post('/check-in', requireAuth, recordPostpartumCheckin);
router.post('/checkin', requireAuth, recordPostpartumCheckin);
router.post('/baby-event', requireAuth, recordBabyEvent);
router.get('/baby-events', requireAuth, getBabyEvents);
router.post('/sos', optionalAuth, generateHelpSOS);
router.post('/safety-triage', optionalAuth, evaluateSafetyTriage);
router.post('/safety-check', optionalAuth, checkPostpartumSafety);
router.get('/safety-check', optionalAuth, checkPostpartumSafety);

export default router;
