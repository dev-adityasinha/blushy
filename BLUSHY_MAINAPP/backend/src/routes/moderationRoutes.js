import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/requireAuth.js';
import {
  getModerationConfig,
  evaluatePostModeration,
  reportForModeration,
  getPostModeration,
  blockCommunityUser,
  unblockCommunityUser,
  listBlocked,
  getQueue,
  moderatePost,
  getPostAudit,
  reportCommentForModeration,
  getCommentModeration,
  moderateComment,
} from '../controllers/moderationController.js';

/**
 * Community moderation routes (spec §12, §22, §27).
 *
 * Moderator actions are admin-only; reporting and blocking are available to
 * any authenticated community member.
 */
const router = Router();
const requireModerator = [requireAuth, requireRole('admin')];

router.get('/config', getModerationConfig);

router.get('/blocks', requireAuth, listBlocked);
router.post('/blocks/:userId', requireAuth, blockCommunityUser);
router.delete('/blocks/:userId', requireAuth, unblockCommunityUser);

router.post('/posts/:postId/evaluate', requireAuth, evaluatePostModeration);
router.post('/posts/:postId/report', requireAuth, reportForModeration);
router.get('/posts/:postId', requireAuth, getPostModeration);

router.post('/comments/:commentId/report', requireAuth, reportCommentForModeration);
router.get('/comments/:commentId', requireAuth, getCommentModeration);
router.post('/comments/:commentId/action', requireModerator, moderateComment);

router.get('/queue', requireModerator, getQueue);
router.post('/posts/:postId/action', requireModerator, moderatePost);
router.get('/posts/:postId/audit', requireModerator, getPostAudit);

export default router;
