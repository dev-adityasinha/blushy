import { Router } from 'express';

import {
  clearChatHistory,
  createChatReply,
  decodePartnerMessage,
  extractAndStoreProfileMemory,
  getChatHistory,
  getOnboardingAuditTrail,
  getPartnerSuggestions,
  getMedicalReports,
  transcribeAudio,
  createVoiceSession,
  getDailyDiscoverTopicsAndCards,
  getTodayMemorySummary,
  getHealthInsights,
} from '../controllers/aiController.js';
import { optionalAuth } from '../middleware/optionalAuth.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { uploadPartnerAttachment } from '../middleware/uploadMiddleware.js';

const router = Router();

// Private authenticated AI & health endpoints
router.post('/chat', requireAuth, uploadPartnerAttachment, createChatReply);
router.post('/transcribe', requireAuth, uploadPartnerAttachment, transcribeAudio);
router.post('/voice/session', requireAuth, createVoiceSession);
router.get('/medical-reports', requireAuth, getMedicalReports);
router.get('/history', requireAuth, getChatHistory);
router.delete('/history', requireAuth, clearChatHistory);
router.get('/onboarding-audit', requireAuth, getOnboardingAuditTrail);
router.post('/profile-memory', requireAuth, extractAndStoreProfileMemory);
router.get('/health-insights', requireAuth, getHealthInsights);
router.get('/memory-summary', requireAuth, getTodayMemorySummary);
router.get('/partner-suggestions/:connectionId', requireAuth, getPartnerSuggestions);
router.get('/decode-partner-message/:connectionId', requireAuth, decodePartnerMessage);

// Public / Guest-safe educational feed with optional personalization for authenticated accounts
router.get('/discover', optionalAuth, getDailyDiscoverTopicsAndCards);

export default router;
