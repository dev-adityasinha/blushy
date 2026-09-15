import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/requireAuth.js';
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
const requireAdmin = [requireAuth, requireRole('admin')];

// Admin routes for user management
router.get('/users', requireAdmin, getAllUsers);
router.get('/users/:userId', requireAdmin, getUserById);
router.get('/users/:userId/moods', requireAdmin, getUserMoods);
router.get('/users/:userId/sleep', requireAdmin, getUserSleep);
router.get('/users/:userId/partner', requireAdmin, getUserPartner);
router.get('/users/:userId/ai-chat-summary', requireAdmin, getUserAIChatSummary);
router.get('/users/:userId/feedback', requireAdmin, getUserFeedback);
router.get('/users/:userId/journal', requireAdmin, getUserJournal);

export default router;
