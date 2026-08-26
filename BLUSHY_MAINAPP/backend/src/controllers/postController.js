import { postRepository } from '../repositories/postRepository.js';
import { commentRepository } from '../repositories/commentRepository.js';
import { followRepository } from '../repositories/followRepository.js';
import { profileRepository } from '../repositories/profileRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { personalizedCommunityService } from '../services/personalizedCommunityService.js';
import { createHttpError } from '../utils/httpError.js';

async function requireAuthUserAsync(req) {
  const userId = req.user?.userId;
  if (!userId) {
    throw createHttpError(401, 'Authentication required.');
  }

  const user = await userRepository.getUserById(userId);
  if (!user) {
    throw createHttpError(404, 'User not found.');
  }

  return { userId };
}

export async function createPost(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const title = typeof req.body?.title === 'string' ? req.body.title.trim() : '';
    const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
    const tags = Array.isArray(req.body?.tags) ? req.body.tags : [];
    const privacy = typeof req.body?.privacy === 'string' ? req.body.privacy.trim().toLowerCase() : 'public';

    if (title.length === 0 && text.length === 0) {
      throw createHttpError(400, 'Post title or content cannot be empty.');
    }

    const post = await postRepository.createPost({
      authorId: auth.userId,
      title,
      text,
      tags,
      privacy: privacy === 'private' ? 'private' : 'public',
    });

    res.status(201).json({ post });
  } catch (error) {
    next(error);
  }
}

export async function editPost(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { postId } = req.params;
    const title = req.body?.title;
    const text = req.body?.text;
    const tags = req.body?.tags;

    const post = await postRepository.editPost(postId, auth.userId, { title, text, tags });
    res.status(200).json({ post });
  } catch (error) {
    next(error);
  }
}

export async function deletePost(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { postId } = req.params;

    const success = await postRepository.deletePost(postId, auth.userId);
    res.status(200).json({ success });
  } catch (error) {
    next(error);
  }
}

export async function votePost(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { postId } = req.params;
    const { vote } = req.body; // 1, 0, -1

    const post = await postRepository.votePost(postId, auth.userId, vote);
    res.status(200).json({ post });
  } catch (error) {
    next(error);
  }
}

export async function reportPost(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { postId } = req.params;
    const { reason } = req.body;

    const success = await postRepository.reportPost(postId, auth.userId, reason);
    res.status(200).json({ success });
  } catch (error) {
    next(error);
  }
}

export async function listFeed(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { type } = req.query; // latest, trending, following, home
    const posts = await postRepository.listFeed(auth.userId, type || 'home');
    res.status(200).json({ posts });
  } catch (error) {
    next(error);
  }
}

// COMMENTS CONTROLLERS
export async function listComments(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { postId } = req.params;
    const { sort } = req.query; // top, new, controversial

    const comments = await commentRepository.listComments(postId, auth.userId, sort || 'top');
    res.status(200).json({ comments });
  } catch (error) {
    next(error);
  }
}

export async function createComment(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { postId } = req.params;
    const { text, parentId } = req.body;

    if (typeof text !== 'string' || text.trim().length === 0) {
      throw createHttpError(400, 'Comment text cannot be empty.');
    }

    const comment = await commentRepository.createComment({
      postId,
      parentId: parentId || null,
      authorId: auth.userId,
      text: text.trim(),
    });

    res.status(201).json({ comment });
  } catch (error) {
    next(error);
  }
}

export async function editComment(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { commentId } = req.params;
    const { text } = req.body;

    if (typeof text !== 'string' || text.trim().length === 0) {
      throw createHttpError(400, 'Comment text cannot be empty.');
    }

    const comment = await commentRepository.editComment(commentId, auth.userId, text.trim());
    res.status(200).json({ comment });
  } catch (error) {
    next(error);
  }
}

export async function deleteComment(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { commentId } = req.params;

    const success = await commentRepository.deleteComment(commentId, auth.userId);
    res.status(200).json({ success });
  } catch (error) {
    next(error);
  }
}

export async function voteComment(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { commentId } = req.params;
    const { vote } = req.body; // 1, 0, -1

    const comment = await commentRepository.voteComment(commentId, auth.userId, vote);
    res.status(200).json({ comment });
  } catch (error) {
    next(error);
  }
}

// FOLLOWING CONTROLLERS
export async function followUser(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { userId } = req.params;

    await followRepository.followUser(auth.userId, userId);
    res.status(200).json({ success: true });
  } catch (error) {
    next(error);
  }
}

export async function unfollowUser(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { userId } = req.params;

    await followRepository.unfollowUser(auth.userId, userId);
    res.status(200).json({ success: true });
  } catch (error) {
    next(error);
  }
}

// PROFILES CONTROLLERS
export async function getProfile(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { userId } = req.params;

    const profile = await profileRepository.getUserProfile(userId, auth.userId);
    if (!profile) {
      throw createHttpError(404, 'User profile not found.');
    }
    
    res.status(200).json({ profile });
  } catch (error) {
    next(error);
  }
}

export async function updateProfile(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { bio } = req.body;
    const profile = await profileRepository.updateUserProfile(auth.userId, { bio });
    res.status(200).json({ profile });
  } catch (error) {
    next(error);
  }
}

export async function getDashboardPersonalizedFeed(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const data = await personalizedCommunityService.getDashboardPersonalizedFeed(auth.userId);
    res.status(200).json({
      status: 'success',
      data,
    });
  } catch (error) {
    next(error);
  }
}


