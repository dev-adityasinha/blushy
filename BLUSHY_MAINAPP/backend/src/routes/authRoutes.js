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
	refreshAuthToken,
	saveMyWeight,
	logout,
} from '../controllers/authController.js';
import { optionalAuth } from '../middleware/optionalAuth.js';
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
router.post('/admin/test-smtp', adminTestSmtp);
router.post('/complete-email-signup', completeEmailSignup);
router.post('/login-email', loginRateLimiter, loginWithEmail);
router.post('/refresh', refreshAuthToken);
router.post('/logout', optionalAuth, logout);
router.post('/google', loginWithGoogle);
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
router.post('/me/nutrition/answers', optionalAuth, saveNutritionAnswers);
router.get('/me/nutrition/answers', optionalAuth, getNutritionAnswers);
router.post('/me/nutrition/generate-plan', optionalAuth, generateNutritionPlan);
router.get('/me/nutrition/plan', optionalAuth, getNutritionPlan);
router.post('/me/feedback', optionalAuth, submitFeedback);

export default router;