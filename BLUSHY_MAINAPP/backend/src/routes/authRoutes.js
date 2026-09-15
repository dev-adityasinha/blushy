import { Router } from 'express';

import {
	completeEmailSignup,
	confirmEmailSignup,
	getMe,
	getMyDailyMood,
	getMyOnboarding,
	getMySleep,
	getMySleepHistory,
	loginWithEmail,
	loginWithGoogle,
	resetPasswordWithEmail,
	sendPasswordResetCode,
	saveMyDailyMood,
	sendEmailVerification,
	saveMyOnboarding,
	saveMySleep,
	updateMe,
	verifyEmailCode,
	adminTestSmtp,
	saveNutritionAnswers,
	getNutritionAnswers,
	generateNutritionPlan,
	getNutritionPlan,
	getMyJournal,
	saveMyJournal,
	setMyJournalShared,
	setMySiaConversationShared,
	refreshAuthToken,
	saveMyWeight,
	logout,
	deleteMyAccount,
} from '../controllers/authController.js';
import {
  acceptMyConsent,
  getMyConsent,
  getMyConsentHistory,
  withdrawMyConsent,
} from '../controllers/consentController.js';
import { optionalAuth } from '../middleware/optionalAuth.js';
import { requireAuth, requireRole } from '../middleware/requireAuth.js';
import { submitFeedback } from '../controllers/feedbackController.js';
import {
  loginRateLimiter,
  otpRequestRateLimiter,
  otpConfirmRateLimiter,
  passwordResetRateLimiter,
} from '../middleware/rateLimiter.js';

const router = Router();

router.post('/send-email-verification', otpRequestRateLimiter, sendEmailVerification);
router.post('/verify-email-code', otpConfirmRateLimiter, verifyEmailCode);
// An unauthenticated caller could make production send a Blushy-branded
// verification email to any address they named, from the verified Brevo
// sender, at the global IP budget of 600 per five minutes. That is a phishing
// relay wearing our own domain, and it spends the mail quota that real signup
// codes come out of. It is a diagnostic, so it is behind the same admin guard
// as every other admin surface, and behind the OTP budget as well.
router.post('/admin/test-smtp', requireAuth, requireRole('admin'), otpRequestRateLimiter, adminTestSmtp);
router.post('/complete-email-signup', completeEmailSignup);
router.post('/login-email', loginRateLimiter, loginWithEmail);
router.post('/refresh', refreshAuthToken);
router.post('/logout', optionalAuth, logout);
router.post('/google', loginWithGoogle);
router.post('/send-password-reset-code', otpRequestRateLimiter, sendPasswordResetCode);
router.post('/reset-password', passwordResetRateLimiter, resetPasswordWithEmail);
router.get('/confirm-email', confirmEmailSignup);
router.get('/me', optionalAuth, getMe);
router.patch('/me', optionalAuth, updateMe);
router.get('/me/onboarding', optionalAuth, getMyOnboarding);
router.put('/me/onboarding', optionalAuth, saveMyOnboarding);
router.get('/me/daily-mood', optionalAuth, getMyDailyMood);
router.put('/me/daily-mood', optionalAuth, saveMyDailyMood);
router.put('/me/weight', optionalAuth, saveMyWeight);
router.get('/me/sleep', optionalAuth, getMySleep);
router.put('/me/sleep', optionalAuth, saveMySleep);
router.get('/me/sleep/history', optionalAuth, getMySleepHistory);
router.get('/me/journal', optionalAuth, getMyJournal);
router.put('/me/journal', optionalAuth, saveMyJournal);
// Per-entry sharing. The partner permission says a partner may receive journal
// entries; these say which ones actually go.
router.put('/me/journal/:entryDate/share', optionalAuth, setMyJournalShared);
router.put('/me/sia-conversations/:conversationId/share', optionalAuth, setMySiaConversationShared);
router.post('/me/nutrition/answers', optionalAuth, saveNutritionAnswers);
router.get('/me/nutrition/answers', optionalAuth, getNutritionAnswers);
router.post('/me/nutrition/generate-plan', optionalAuth, generateNutritionPlan);
router.get('/me/nutrition/plan', optionalAuth, getNutritionPlan);
router.post('/me/feedback', optionalAuth, submitFeedback);
// Consent. requireAuth throughout: a consent record that cannot name whose
// consent it is proves nothing, which is the whole reason these exist.
router.get('/me/consent', requireAuth, getMyConsent);
router.post('/me/consent', requireAuth, acceptMyConsent);
router.post('/me/consent/withdraw', requireAuth, withdrawMyConsent);
router.get('/me/consent/history', requireAuth, getMyConsentHistory);
// Permanent account deletion. requireAuth, not optionalAuth: an
// unauthenticated caller must be refused, never silently treated as nobody.
router.delete('/me', requireAuth, deleteMyAccount);

export default router;