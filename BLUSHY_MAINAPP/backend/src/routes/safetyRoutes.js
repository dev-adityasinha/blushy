import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/requireAuth.js';
import { optionalAuth } from '../middleware/optionalAuth.js';
import {
  getSafetyState,
  checkText,
  getEmergencyContacts,
  listInstruments,
  getInstrumentItems,
  submitScreening,
  getScreeningHistory,
  shareScreeningHandoff,
  getMoodCheckInStatus,
  previewDoctorSummary,
  createDoctorSummary,
  getDoctorSummaries,
  getDoctorSummary,
  removeDoctorSummary,
  getRedFlagRules,
} from '../controllers/safetyController.js';

/**
 * Safety, screening and doctor companion routes (spec §15, §16, §18).
 *
 * Emergency resources use optional auth on purpose: safety guidance must still
 * resolve for a signed-out or expired session (spec §25).
 */
const router = Router();

router.get('/emergency-resources', optionalAuth, getEmergencyContacts);
router.get('/state', requireAuth, getSafetyState);
router.post('/check-text', requireAuth, checkText);

router.get('/screening/instruments', requireAuth, listInstruments);
router.get('/screening/instruments/:instrumentId/items', requireAuth, getInstrumentItems);
router.post('/screening/submit', requireAuth, submitScreening);
router.get('/screening/history', requireAuth, getScreeningHistory);
router.post('/screening/:screeningId/handoff', requireAuth, shareScreeningHandoff);
router.get('/screening/mood-check-in', requireAuth, getMoodCheckInStatus);

router.get('/doctor-summary/preview', requireAuth, previewDoctorSummary);
router.post('/doctor-summary', requireAuth, createDoctorSummary);
router.get('/doctor-summary', requireAuth, getDoctorSummaries);
router.get('/doctor-summary/:summaryId', requireAuth, getDoctorSummary);
router.delete('/doctor-summary/:summaryId', requireAuth, removeDoctorSummary);

router.get('/admin/red-flag-rules', requireAuth, requireRole('admin'), getRedFlagRules);

export default router;
