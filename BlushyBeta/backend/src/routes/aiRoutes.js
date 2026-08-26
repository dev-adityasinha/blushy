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
} from '../controllers/aiController.js';
import { getHealthInsights } from '../controllers/aiController.js';
import { optionalAuth } from '../middleware/optionalAuth.js';
import { uploadPartnerAttachment } from '../middleware/uploadMiddleware.js';

const router = Router();

router.post('/chat', optionalAuth, uploadPartnerAttachment, createChatReply);
router.post('/transcribe', optionalAuth, uploadPartnerAttachment, transcribeAudio);
router.post('/voice/session', optionalAuth, createVoiceSession);
router.get('/medical-reports', optionalAuth, getMedicalReports);
router.get('/history', optionalAuth, getChatHistory);
router.delete('/history', optionalAuth, clearChatHistory);
router.get('/onboarding-audit', optionalAuth, getOnboardingAuditTrail);
router.post('/profile-memory', optionalAuth, extractAndStoreProfileMemory);
router.get('/health-insights', optionalAuth, getHealthInsights);
router.get('/partner-suggestions/:connectionId', optionalAuth, getPartnerSuggestions);
router.get('/decode-partner-message/:connectionId', optionalAuth, decodePartnerMessage);

export default router;
