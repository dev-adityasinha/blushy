import { randomUUID } from 'node:crypto';
import { db, findUserDocument, findUserDocuments } from '../utils/db.js';

// Ceiling on how much of the feed one request will read. Not pagination --
// the caller still filters afterwards, so a page can come back shorter -- but
// it stops the query growing with the size of the whole table.
const FEED_FETCH_LIMIT = 200;

/**
 * @param commentCount pass a precomputed count when mapping many posts, so a
 *   feed does not run one count query per row.
 */
/**
 * Builds the view for one post from data already in hand.
 *
 * Separated from the fetching so a feed can gather votes and authors for every
 * post in two queries instead of two per post. Rendering 20 posts used to cost
 * 116 round trips and 2.4 seconds; nothing here touches the database.
 */
function buildPostView(row, { userVote = 0, author = null, commentCount = 0 } = {}) {
  if (!row) return null;

  // An anonymous post carries no author out of this function.
  //
  // The flag was returned to clients while `authorId` and `authorName` were
  // sent alongside it regardless, so anything marked anonymous would still have
  // shipped the poster's name and account id to every reader. Nothing sets the
  // flag today -- the app offers no such toggle -- which is exactly why this is
  // worth closing now: the day someone adds one, the leak is already written.
  const anonymous = row.anonymous === true;
  const display_name = anonymous
    ? 'Anonymous'
    : (author?.onboarding_answers?.preferred_name ?? 'Anonymous');

  return {
    postId: row.post_id,
    authorId: anonymous ? null : row.author_id,
    authorName: display_name,
    audience: row.audience ?? 'female_user',
    anonymous,
    moderationState: row.moderation_state ?? 'visible',
    moderationNotice: row.moderation_notice ?? null,
    sensitiveTopics: row.sensitive_topics ?? [],
    title: row.title ?? '',
    text: row.text ?? '',
    tags: row.tags ?? [],
    score: row.score ?? 0,
    // Counts soft-deleted comments too, because listComments still returns
    // them to keep reply threads intact -- so this matches what the reader
    // actually sees when they open the post.
    commentCount,
    privacy: row.privacy ?? 'public',
    userVote,
    createdAt: new Date(row.created_at).toISOString(),
    updatedAt: new Date(row.updated_at).toISOString(),
  };
}

/**
 * Single-post version: fetches the two extras itself.
 *
 * Correct for one post; using it in a loop is what made the feed slow, so the
 * feed batches instead (see listFeed).
 */
async function mapPostRow(row, viewerUserId = null, commentCount = null) {
  if (!row) return null;

  const [voteDoc, author, count] = await Promise.all([
    viewerUserId
      ? db.collection('post_votes').findOne({ user_id: viewerUserId, target_id: row.post_id })
      : Promise.resolve(null),
    findUserDocument({ user_id: row.author_id }),
    commentCount ?? db.collection('comments').countDocuments({ post_id: row.post_id }),
  ]);

  return buildPostView(row, {
    userVote: voteDoc?.vote_value ?? 0,
    author,
    commentCount: count ?? 0,
  });
}

async function createPost({ authorId, title, text, tags = [], privacy = 'public' }) {
  const postId = randomUUID();
  const now = new Date();

  const doc = {
    post_id: postId,
    author_id: authorId,
    title: title || '',
    text: text || '',
    tags: tags || [],
    score: 0,
    privacy: privacy === 'private' ? 'private' : 'public',
    reports: [],
    created_at: now,
    updated_at: now,
  };

  await db.collection('posts').insertOne(doc);
  return mapPostRow(doc, authorId);
}

async function getPost(postId, viewerUserId = null) {
  const post = await db.collection('posts').findOne({ post_id: postId });
  if (!post) return null;
  return mapPostRow(post, viewerUserId);
}

async function editPost(postId, authorId, { title, text, tags }) {
  const post = await db.collection('posts').findOne({ post_id: postId });
  if (!post) return null;
  if (post.author_id !== authorId) {
    throw new Error('Unauthorized to edit this post');
  }

  const updateDoc = {
    updated_at: new Date(),
  };
  if (title !== undefined) updateDoc.title = title;
  if (text !== undefined) updateDoc.text = text;
  if (tags !== undefined) updateDoc.tags = tags;

  await db.collection('posts').updateOne(
    { post_id: postId },
    { $set: updateDoc }
  );

  const updated = await db.collection('posts').findOne({ post_id: postId });
  return mapPostRow(updated, authorId);
}

async function deletePost(postId, authorId) {
  const post = await db.collection('posts').findOne({ post_id: postId });
  if (!post) return false;
  if (post.author_id !== authorId) {
    throw new Error('Unauthorized to delete this post');
  }

  await db.collection('posts').deleteOne({ post_id: postId });
  await db.collection('comments').deleteMany({ post_id: postId });
  await db.collection('post_votes').deleteMany({ target_id: postId });
  return true;
}

async function votePost(postId, userId, value) {
  // value can be 1, -1, or 0 (clear vote)
  const voteVal = Number(value);
  if (![1, 0, -1].includes(voteVal)) {
    throw new Error('Invalid vote value');
  }

  // The post lookup and the existing-vote lookup do not depend on each other,
  // so they go out together. The post is still checked before anything is
  // written: voting on a deleted post would otherwise leave an orphan row in
  // post_votes that nothing ever cleans up.
  const [post, existingVote] = await Promise.all([
    db.collection('posts').findOne({ post_id: postId }, { projection: { _id: 1 } }),
    db.collection('post_votes').findOne({ user_id: userId, target_id: postId }),
  ]);
  if (!post) return null;

  let scoreDiff = 0;
  if (existingVote) {
    scoreDiff -= existingVote.vote_value;
    if (voteVal === 0) {
      await db.collection('post_votes').deleteOne({
        user_id: userId,
        target_id: postId,
      });
    } else {
      await db.collection('post_votes').updateOne(
        { user_id: userId, target_id: postId },
        { $set: { vote_value: voteVal, updated_at: new Date() } }
      );
      scoreDiff += voteVal;
    }
  } else if (voteVal !== 0) {
    await db.collection('post_votes').insertOne({
      user_id: userId,
      target_id: postId,
      vote_value: voteVal,
      created_at: new Date(),
      updated_at: new Date(),
    });
    scoreDiff += voteVal;
  }

  // One round trip for the increment and the read-back, rather than an
  // updateOne followed by a findOne of the row just written.
  const updated = scoreDiff !== 0
    ? await db.collection('posts').findOneAndUpdate(
        { post_id: postId },
        { $inc: { score: scoreDiff } },
        { returnDocument: 'after' },
      )
    : await db.collection('posts').findOne({ post_id: postId });

  if (!updated) return null;
  return mapPostRow(updated, userId);
}

async function reportPost(postId, userId, reason) {
  const post = await db.collection('posts').findOne({ post_id: postId });
  if (!post) return false;

  await db.collection('posts').updateOne(
    { post_id: postId },
    {
      $push: {
        reports: {
          user_id: userId,
          reason: reason || 'Unspecified',
          created_at: new Date(),
        }
      }
    }
  );
  return true;
}

async function listFeed(userId, type = 'home') {
  let query = { privacy: 'public' };

  // If feed is following, filter by followed user IDs
  if (type === 'following') {
    const follows = await db.collection('user_follows').find({ follower_id: userId }).toArray();
    const followedIds = follows.map(f => f.following_id);
    query = { author_id: { $in: followedIds }, privacy: 'public' };
  }

  let sortOption = { created_at: -1 };
  if (type === 'trending' || type === 'popular') {
    sortOption = { score: -1, created_at: -1 };
  }

  // Bounded. This used to fetch every public post in the database and then
  // build a view for each; the cost grew with the whole table rather than with
  // what anyone would actually read. The cap is above a screenful because the
  // caller filters afterwards for audience, blocks and moderation.
  const posts = await db.collection('posts')
    .find(query)
    .sort(sortOption)
    .limit(FEED_FETCH_LIMIT)
    .toArray();

  if (posts.length === 0) return [];

  const postIds = posts.map((p) => p.post_id);
  const authorIds = [...new Set(posts.map((p) => p.author_id).filter(Boolean))];

  // Three grouped reads for the whole page. The comment counts were already
  // batched this way; votes and authors were not, so a 20 post feed cost 116
  // round trips and 2.4 seconds -- roughly five queries per post, repeated.
  const [grouped, votes, authors] = await Promise.all([
    db.collection('comments').aggregate([
      { $match: { post_id: { $in: postIds } } },
      { $group: { _id: '$post_id', total: { $sum: 1 } } },
    ]).toArray(),
    userId
      ? db.collection('post_votes')
          .find({ user_id: userId, target_id: { $in: postIds } })
          .toArray()
      : Promise.resolve([]),
    authorIds.length ? findUserDocuments({ user_id: { $in: authorIds } }) : Promise.resolve([]),
  ]);

  const countByPost = new Map(grouped.map((g) => [g._id, g.total]));
  const voteByPost = new Map(votes.map((v) => [v.target_id, v.vote_value]));
  const authorById = new Map(authors.map((a) => [a.user_id, a]));

  return posts.map((p) => buildPostView(p, {
    userVote: voteByPost.get(p.post_id) ?? 0,
    author: authorById.get(p.author_id) ?? null,
    commentCount: countByPost.get(p.post_id) ?? 0,
  }));
}

export const postRepository = {
  createPost,
  getPost,
  editPost,
  deletePost,
  votePost,
  reportPost,
  listFeed,
};

