import { postRepository } from '../repositories/postRepository.js';
import { commentRepository } from '../repositories/commentRepository.js';
import { followRepository } from '../repositories/followRepository.js';
import { profileRepository } from '../repositories/profileRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import {
  personalizedCommunityService,
  getUserSignals,
  calculateRelevanceScore,
} from '../services/personalizedCommunityService.js';
import { createHttpError } from '../utils/httpError.js';
import {
  moderateNewPost,
  moderateAfterReport,
  filterForViewer,
  moderateNewComment,
  filterCommentsForViewer,
} from '../services/moderationService.js';

async function requireAuthUserAsync(req) {
  const userId = req.user?.userId;
  if (!userId) {
    throw createHttpError(401, 'Authentication required.');
  }

  // Already read and checked by the auth middleware; only existence matters
  // here and that has been established.
  if (req.user?.verifiedAgainstDb) {
    return { userId };
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

    // Sets the audience and anonymity defaults and runs the moderation rules
    // before the post can appear in any feed (spec §12).
    const moderation = await moderateNewPost(post.postId ?? post.post_id, {
      title,
      text,
      role: auth.role ?? req.user?.role,
    });

    res.status(201).json({
      post,
      moderation: {
        state: moderation.state,
        notice: moderation.notice,
        requiresHumanReview: moderation.requiresHumanReview,
        sensitiveTopics: moderation.sensitiveTopics,
      },
    });
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

    // Reports raise the stakes but never remove a post on their own; this
    // may route it to a human queue (spec §12).
    const moderation = success ? await moderateAfterReport(postId) : null;

    res.status(200).json({
      success,
      moderation: moderation
        ? { state: moderation.moderationState, requiresHumanReview: moderation.requiresHumanReview }
        : null,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * Orders the Home feed by how much each post has to do with this person.
 *
 * The scoring already existed and was wired only to the home page's
 * personalized sections: life stage and symptoms weigh +8 each, cycle phase
 * +6, followed communities +5, previously upvoted topics +4, with small
 * bonuses for recency and engagement. The Community tab meanwhile queried
 * `{ privacy: 'public' }` and showed everyone the same list in date order.
 *
 * This ranks rather than filters. Nothing is hidden -- on a community this
 * young, filtering by stage could leave someone with an empty tab, which reads
 * as broken rather than as curated. Relevant posts move up; the rest follow.
 *
 * Left alone deliberately:
 *  - `latest` and `trending` promise an order in their own names, and a person
 *    choosing them is asking for that order rather than for ours.
 *  - a search, where the query is the intent and reordering it by life stage
 *    would bury the thing that was actually searched for.
 *  - anyone with no signals yet, who gets exactly what they got before.
 */
export async function rankForViewer(posts, userId, type, search) {
  const feedType = type || 'home';
  const searching = typeof search === 'string' && search.trim().length > 0;
  if (feedType !== 'home' || searching || posts.length < 2) return posts;

  let signals;
  try {
    signals = await getUserSignals(userId);
  } catch (error) {
    // Ranking is an improvement on an order that already works, so a failure
    // to read the signals must not cost anyone their feed.
    //
    // Logged rather than swallowed: while this was being written the catch
    // hid a missing import, and the feed simply stopped being ranked with
    // nothing anywhere to say so.
    console.warn(`listFeed: ranking skipped for ${userId}: ${error?.message ?? error}`);
    return posts;
  }
  if (!signals?.hasPersonalSignals) return posts;

  // Decorated with the index so equal scores keep the order they arrived in,
  // which is the date order the query produced.
  return posts
    .map((post, index) => ({
      post,
      index,
      relevance: calculateRelevanceScore(post, signals),
    }))
    .sort((a, b) => b.relevance - a.relevance || a.index - b.index)
    .map((entry) => entry.post);
}

export async function listFeed(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const { type, search } = req.query; // latest, trending, following, home, mine
    const posts = await postRepository.listFeed(auth.userId, type || 'home', {
      // Bounded so a pasted essay cannot become the query.
      search: typeof search === 'string' ? search.slice(0, 120) : '',
    });

    // Audience separation, blocks and moderation state are enforced here, not
    // by the client hiding things (spec §28).
    const visible = await filterForViewer(posts, {
      viewerUserId: auth.userId,
      viewerRole: auth.role ?? req.user?.role,
    });

    res.status(200).json({ posts: await rankForViewer(visible, auth.userId, type, search) });
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

    // Held and blocked comments are filtered server side (spec §28).
    const visible = await filterCommentsForViewer(comments, { viewerUserId: auth.userId });

    res.status(200).json({ comments: visible });
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

    // A treatment claim is no safer in a reply, so comments go through the
    // same rules as posts (spec §12).
    const moderation = await moderateNewComment(comment.commentId, { text: text.trim() });

    res.status(201).json({
      comment,
      moderation: {
        state: moderation.state,
        notice: moderation.notice,
        requiresHumanReview: moderation.requiresHumanReview,
        sensitiveTopics: moderation.sensitiveTopics,
      },
    });
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


