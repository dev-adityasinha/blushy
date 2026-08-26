import { Router } from 'express';
import { optionalAuth } from '../middleware/optionalAuth.js';
import {
	getAllUsers,
	getUserById,
	getUserMoods,
	getUserSleep,
	getUserPartner,
	getUserAIChatSummary,
	getUserFeedback,
	getUserJournal,
} from '../controllers/adminController.js';

const router = Router();

// Admin routes for user management
router.get('/users', optionalAuth, getAllUsers);
router.get('/users/:userId', optionalAuth, getUserById);
router.get('/users/:userId/moods', optionalAuth, getUserMoods);
router.get('/users/:userId/sleep', optionalAuth, getUserSleep);
router.get('/users/:userId/partner', optionalAuth, getUserPartner);
router.get('/users/:userId/ai-chat-summary', optionalAuth, getUserAIChatSummary);
router.get('/users/:userId/feedback', optionalAuth, getUserFeedback);
router.get('/users/:userId/journal', optionalAuth, getUserJournal);

export default router;
