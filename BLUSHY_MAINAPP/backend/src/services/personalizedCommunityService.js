import { db, findUserDocuments } from '../utils/db.js';
import { calculatePeriodPredictions } from './periodPredictionService.js';

/**
 * Standard list of normalized topics.
 */
const NORMALIZED_TOPICS = [
  'cramps', 'bloating', 'fatigue', 'headache', 'acne', 'mood', 'sleep',
  'pcos', 'endometriosis', 'pmdd', 'ttc', 'puberty', 'pregnancy',
  'postpartum', 'perimenopause', 'menopause', 'nutrition', 'fitness',
  'mindfulness', 'period', 'follicular', 'ovulation', 'luteal', 'energy'
];

/**
 * Deterministic post classifier.
 * Rules in priority order:
 * 1. Stored post_type if valid.
 * 2. Approved tags matching.
 * 3. Text pattern heuristics.
 * 4. Fallback to 'discussion'.
 */
export function classifyPostDeterministic(row) {
  if (row.post_type && ['question', 'story', 'tip', 'discussion'].includes(row.post_type.toLowerCase())) {
    return row.post_type.toLowerCase();
  }

  const tags = Array.isArray(row.tags) ? row.tags.map((t) => String(t).toLowerCase()) : [];
  const textContent = `${row.title || ''} ${row.text || ''}`.toLowerCase().trim();

  // Tag-based classification
  if (tags.some((t) => ['question', 'ask', 'qna', 'help', 'advice-needed', 'inquiry'].includes(t))) {
    return 'question';
  }
  if (tags.some((t) => ['story', 'journey', 'experience', 'my-story', 'personal', 'transformation'].includes(t))) {
    return 'story';
  }
  if (tags.some((t) => ['tip', 'tips', 'hack', 'guide', 'remedy', 'routine', 'advice', 'protocol'].includes(t))) {
    return 'tip';
  }
  if (tags.some((t) => ['trending', 'discussion', 'general', 'circle'].includes(t))) {
    return 'discussion';
  }

  // Text pattern heuristics
  if (
    textContent.endsWith('?') ||
    /^(how|why|what|is|can|does|anyone|should|where|when|which|do|has|have|are)\b/i.test(row.title || '') ||
    /(anyone else|has anyone tried|any advice|what should i do)\b/i.test(textContent)
  ) {
    return 'question';
  }

  if (
    /(my journey|my experience|today i|i tried|when i started|i wanted to share|my first period|my story|i realized)\b/i.test(textContent)
  ) {
    return 'story';
  }

  if (
    /(tip:|tips:|recommend\b|how to |routine for|my advice|helpful remedy|make sure to|best way to)\b/i.test(textContent)
  ) {
    return 'tip';
  }

  return 'discussion';
}

/**
 * Helper to map MongoDB post row to API public response shape.
 */
/**
 * Maps a batch of posts into the shape the feed returns.
 *
 * Each post used to be mapped on its own, and every mapping made three round
 * trips -- the viewer's vote, the author, the comment count -- with the author
 * lookup itself reading two collections. The caller mapped ten at a time
 * through `Promise.all`, so a single request issued about forty concurrent
 * operations against a pool of twenty. One person opening this feed could hold
 * every connection while the rest of the process waited: the time capsule
 * scheduler failed with "Timed out while checking out a connection from
 * connection pool" doing exactly that.
 *
 * The whole batch now costs three queries regardless of how many posts it
 * holds, and they run together rather than per row.
 */
async function mapPersonalizedPostRows(rows, viewerUserId = null) {
  const present = (rows ?? []).filter(Boolean);
  if (present.length === 0) return [];

  const postIds = [...new Set(present.map((r) => r.post_id).filter(Boolean))];
  const authorIds = [...new Set(present.map((r) => r.author_id).filter(Boolean))];

  const [voteDocs, authors, commentCounts] = await Promise.all([
    viewerUserId && postIds.length > 0
      ? db.collection('post_votes')
        .find({ user_id: viewerUserId, target_id: { $in: postIds } })
        .toArray()
      : [],
    authorIds.length > 0
      ? findUserDocuments({ user_id: { $in: authorIds } })
      : [],
    postIds.length > 0
      ? db.collection('comments').aggregate([
        { $match: { post_id: { $in: postIds } } },
        { $group: { _id: '$post_id', count: { $sum: 1 } } },
      ]).toArray()
      : [],
  ]);

  const voteByPost = new Map(voteDocs.map((v) => [v.target_id, v.vote_value]));
  const authorById = new Map(authors.map((a) => [a.user_id, a]));
  // A post with no comments has no group, so the lookup below defaults to 0
  // rather than the count being absent.
  const countByPost = new Map(commentCounts.map((c) => [c._id, c.count]));

  return present.map((row) => ({
    postId: row.post_id,
    authorName:
      authorById.get(row.author_id)?.onboarding_answers?.preferred_name
      ?? 'Anonymous',
    title: row.title ?? '',
    text: row.text ?? '',
    tags: Array.isArray(row.tags) ? row.tags : [],
    postType: classifyPostDeterministic(row),
    score: row.score ?? 0,
    commentCount: countByPost.get(row.post_id) ?? 0,
    userVote: voteByPost.get(row.post_id) ?? 0,
    createdAt: new Date(row.created_at).toISOString(),
  }));
}

/**
 * Calculate deterministic relevance score for a post given user signals.
 */
function calculateRelevanceScore(post, userSignals) {
  let score = 0;
  const postTags = (post.tags || []).map((t) => String(t).toLowerCase());
  const postText = `${post.title || ''} ${post.text || ''}`.toLowerCase();

  // 1. Symptom matching (+8)
  for (const symptom of userSignals.symptoms) {
    const sLower = symptom.toLowerCase();
    if (postTags.includes(sLower) || postText.includes(sLower)) {
      score += 8;
      break;
    }
  }

  // 2. Life stage matching (+8)
  if (userSignals.lifeStage) {
    const stageLower = userSignals.lifeStage.toLowerCase();
    if (postTags.includes(stageLower) || postText.includes(stageLower)) {
      score += 8;
    } else if (stageLower.includes('cycle') && (postTags.includes('cycle') || postText.includes('cycle'))) {
      score += 6;
    }
  }

  // 3. Cycle phase matching (+6)
  if (userSignals.cyclePhase) {
    const phaseLower = userSignals.cyclePhase.toLowerCase();
    if (postTags.includes(phaseLower) || postText.includes(phaseLower)) {
      score += 6;
    }
  }

  // 4. Followed communities matching (+5)
  for (const followedCategory of userSignals.followedCategories) {
    const fLower = followedCategory.toLowerCase();
    if (postTags.includes(fLower) || postText.includes(fLower)) {
      score += 5;
      break;
    }
  }

  // 5. Upvoted topics matching (+4)
  for (const topic of userSignals.upvotedTopics) {
    const tLower = topic.toLowerCase();
    if (postTags.includes(tLower)) {
      score += 4;
      break;
    }
  }

  // 6. Recency bonus (+0 to +3)
  const ageMs = Date.now() - new Date(post.created_at).getTime();
  const ageHours = ageMs / (1000 * 60 * 60);
  if (ageHours < 24) {
    score += 3;
  } else if (ageHours < 24 * 7) {
    score += 2;
  } else if (ageHours < 24 * 30) {
    score += 1;
  }

  // 7. Public engagement bonus (+0 to +3)
  const postScore = Number(post.score) || 0;
  if (postScore > 0) {
    score += Math.min(3, Math.floor(postScore / 5));
  }

  return score;
}

/**
 * Gathers user signals strictly scoped to the authenticated user ID.
 */
async function getUserSignals(userId) {
  const isMan = await db.collection('users_man').findOne({ user_id: userId });
  const userColl = isMan ? 'users_man' : 'users_woman';
  const dailyColl = isMan ? 'user_daily_logs_man' : 'user_daily_logs_woman';
  const memoryColl = isMan ? 'profile_memory_man' : 'profile_memory_woman';

  const user = await db.collection(userColl).findOne({ user_id: userId });
  const lifeStage = user?.onboarding_answers?.life_stage || user?.stage || null;

  // Tracked symptoms from recent daily logs (last 30 days)
  const recentLogs = await db.collection(dailyColl)
    .find({ user_id: userId })
    .sort({ log_date: -1 })
    .limit(30)
    .toArray();

  const symptoms = Array.from(
    new Set(recentLogs.flatMap((l) => (Array.isArray(l.symptoms) ? l.symptoms : [])))
  );

  // Confirmed structured Docsy memories
  const memoryDoc = await db.collection(memoryColl).findOne({ user_id: userId });
  const siaTopics = Array.isArray(memoryDoc?.extracted_symptoms) ? memoryDoc.extracted_symptoms : [];
  for (const st of siaTopics) {
    if (!symptoms.includes(st)) {
      symptoms.push(st);
    }
  }

  // Canonical cycle phase
  let cyclePhase = null;
  if (!isMan) {
    try {
      const pred = await calculatePeriodPredictions(userId);
      cyclePhase = pred?.currentPhase || null;
    } catch (_) {}
  }

  // Followed communities
  const communityFollows = await db.collection('community_followers')
    .find({ user_id: userId })
    .toArray();
  const followedCommunityIds = communityFollows.map((f) => f.community_id);
  const communities = await db.collection('communities')
    .find({ community_id: { $in: followedCommunityIds } })
    .toArray();
  const followedCategories = communities.map((c) => c.category || c.name);

  // Upvoted posts and their tags
  const votes = await db.collection('post_votes')
    .find({ user_id: userId, vote_value: 1 })
    .sort({ created_at: -1 })
    .limit(20)
    .toArray();
  const upvotedPostIds = votes.map((v) => v.target_id);
  const upvotedPosts = await db.collection('posts')
    .find({ post_id: { $in: upvotedPostIds } })
    .toArray();
  const upvotedTopics = Array.from(
    new Set(upvotedPosts.flatMap((p) => (Array.isArray(p.tags) ? p.tags : [])))
  );

  const hasPersonalSignals = Boolean(
    lifeStage || symptoms.length > 0 || cyclePhase || followedCategories.length > 0 || upvotedTopics.length > 0
  );

  return {
    userId,
    lifeStage,
    cyclePhase,
    symptoms,
    followedCategories,
    upvotedTopics,
    hasPersonalSignals,
  };
}

/**
 * Main Service: Generates personalized dashboard community feed.
 * Direct indexed MongoDB queries with bounded limits (zero backend cache) for multi-worker safety.
 */
export async function getDashboardPersonalizedFeed(userId) {
  // 1. Gather authenticated user signals
  const userSignals = await getUserSignals(userId);

  // 2. Query public, non-deleted candidate posts (bounded to 100 recent/active posts)
  const candidatePosts = await db.collection('posts')
    .find({ privacy: 'public' })
    .sort({ score: -1, created_at: -1 })
    .limit(100)
    .toArray();

  if (candidatePosts.length === 0) {
    return {
      isPersonalized: false,
      fallbackLabel: 'Popular in the community',
      generatedAt: new Date().toISOString(),
      personalizationVersion: 'v1',
      questions: [],
      stories: [],
      tips: [],
      trending: [],
    };
  }

  // 3. Score each post deterministically
  const scoredPosts = candidatePosts.map((post) => {
    const postType = classifyPostDeterministic(post);
    const relevanceScore = userSignals.hasPersonalSignals
      ? calculateRelevanceScore(post, userSignals)
      : 0;
    return {
      post,
      postType,
      relevanceScore,
    };
  });

  // Check if any post had meaningful personalized relevance (> 0)
  const hasMatchedPersonalContent = userSignals.hasPersonalSignals &&
    scoredPosts.some((p) => p.relevanceScore > 0);

  const isPersonalized = hasMatchedPersonalContent;
  const fallbackLabel = isPersonalized ? null : 'Popular in the community';

  // 4. Sorting logic:
  // For Questions, Stories, Tips: sorted by relevanceScore DESC, then score DESC, then created_at DESC
  const personalSort = (a, b) => {
    if (b.relevanceScore !== a.relevanceScore) {
      return b.relevanceScore - a.relevanceScore;
    }
    if ((b.post.score || 0) !== (a.post.score || 0)) {
      return (b.post.score || 0) - (a.post.score || 0);
    }
    return new Date(b.post.created_at) - new Date(a.post.created_at);
  };

  // For Trending tab: public engagement (score) combined with user relevance
  // Formula: combinedEngagement = (score * 2) + relevanceScore
  const trendingSort = (a, b) => {
    const scoreA = ((a.post.score || 0) * 2) + (a.relevanceScore || 0);
    const scoreB = ((b.post.score || 0) * 2) + (b.relevanceScore || 0);
    if (scoreB !== scoreA) {
      return scoreB - scoreA;
    }
    return new Date(b.post.created_at) - new Date(a.post.created_at);
  };

  const questionCandidates = scoredPosts.filter((p) => p.postType === 'question').sort(personalSort);
  const storyCandidates = scoredPosts.filter((p) => p.postType === 'story').sort(personalSort);
  const tipCandidates = scoredPosts.filter((p) => p.postType === 'tip').sort(personalSort);
  const trendingCandidates = [...scoredPosts].sort(trendingSort);

  // If specific post type has no candidates, backfill gracefully from discussion/general candidate pool
  const discussionCandidates = scoredPosts.filter((p) => p.postType === 'discussion').sort(personalSort);

  const fillPool = (primary, limit = 10) => {
    const list = [...primary];
    if (list.length < 3) {
      for (const disc of discussionCandidates) {
        if (!list.some((item) => item.post.post_id === disc.post.post_id)) {
          list.push(disc);
        }
        if (list.length >= limit) break;
      }
    }
    return list.slice(0, limit);
  };

  const finalQuestions = fillPool(questionCandidates, 10);
  const finalStories = fillPool(storyCandidates, 10);
  const finalTips = fillPool(tipCandidates, 10);
  const finalTrending = trendingCandidates.slice(0, 10);

  // Map to public serialized items
  // Four batches rather than forty individual mappings, and the four run
  // together because each is now a handful of queries instead of a swarm.
  const [questions, stories, tips, trending] = await Promise.all([
    mapPersonalizedPostRows(finalQuestions.map((p) => p.post), userId),
    mapPersonalizedPostRows(finalStories.map((p) => p.post), userId),
    mapPersonalizedPostRows(finalTips.map((p) => p.post), userId),
    mapPersonalizedPostRows(finalTrending.map((p) => p.post), userId),
  ]);

  return {
    isPersonalized,
    fallbackLabel,
    generatedAt: new Date().toISOString(),
    personalizationVersion: 'v1',
    questions,
    stories,
    tips,
    trending,
  };
}

export const personalizedCommunityService = {
  getDashboardPersonalizedFeed,
  classifyPostDeterministic,
};
