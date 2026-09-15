import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/requireAuth.js';
import { optionalAuth } from '../middleware/optionalAuth.js';
import {
  browseLibrary,
  getLibraryItem,
  saveProgress,
  toggleBookmark,
  getSaved,
  getCompletedContent,
  getRecommendations,
  adminListContent,
  adminCreateContent,
  adminUpdateContent,
  adminSetStatus,
  adminEmergencyRetire,
  adminReviewQueue,
  adminContentAudit,
} from '../controllers/contentController.js';

/**
 * M Studio / Learn library and clinical content administration
 * (spec §13, §17, §23, §27).
 */
const router = Router();
const requireAdmin = [requireAuth, requireRole('admin')];

router.get('/admin/review-queue', requireAdmin, adminReviewQueue);
router.get('/admin', requireAdmin, adminListContent);
router.post('/admin', requireAdmin, adminCreateContent);
router.patch('/admin/:contentId', requireAdmin, adminUpdateContent);
router.post('/admin/:contentId/status', requireAdmin, adminSetStatus);
router.post('/admin/:contentId/emergency-retire', requireAdmin, adminEmergencyRetire);
router.get('/admin/:contentId/audit', requireAdmin, adminContentAudit);

router.get('/saved', requireAuth, getSaved);
router.get('/completed', requireAuth, getCompletedContent);
router.get('/recommendations', requireAuth, getRecommendations);

router.get('/', optionalAuth, browseLibrary);
router.get('/:contentId', optionalAuth, getLibraryItem);
router.put('/:contentId/progress', requireAuth, saveProgress);
router.put('/:contentId/bookmark', requireAuth, toggleBookmark);

export default router;
