import { Router } from 'express';
import {
  createPost,
  editPost,
  deletePost,
  votePost,
  reportPost,
  listFeed,
  listComments,
  createComment,
  editComment,
  deleteComment,
  voteComment,
  followUser,
  unfollowUser,
  getProfile,
  updateProfile,
  getDashboardPersonalizedFeed,
} from '../controllers/postController.js';
import { optionalAuth } from '../middleware/optionalAuth.js';
import { requireAuth } from '../middleware/requireAuth.js';

const router = Router();

// Feed & Posts
router.get('/dashboard-personalized', requireAuth, getDashboardPersonalizedFeed);
router.get('/feed', optionalAuth, listFeed);
router.post('/', optionalAuth, createPost);
router.put('/:postId', optionalAuth, editPost);
router.delete('/:postId', optionalAuth, deletePost);
router.post('/:postId/vote', optionalAuth, votePost);
router.post('/:postId/report', optionalAuth, reportPost);

// Comments
router.get('/:postId/comments', optionalAuth, listComments);
router.post('/:postId/comments', optionalAuth, createComment);
router.put('/comments/:commentId', optionalAuth, editComment);
router.delete('/comments/:commentId', optionalAuth, deleteComment);
router.post('/comments/:commentId/vote', optionalAuth, voteComment);

// Follows
router.post('/users/:userId/follow', optionalAuth, followUser);
router.post('/users/:userId/unfollow', optionalAuth, unfollowUser);

// Profiles
router.get('/users/:userId/profile', optionalAuth, getProfile);
router.put('/users/profile', optionalAuth, updateProfile);

export default router;

