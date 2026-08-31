import test from 'node:test';
import assert from 'node:assert/strict';

import { postRepository as R } from '../src/repositories/postRepository.js';
import { commentRepository as C } from '../src/repositories/commentRepository.js';
import { closeDb, db } from '../src/utils/db.js';

async function users(suffix) {
  const a = `test_com_a_${suffix}`;
  const b = `test_com_b_${suffix}`;
  for (const [uid, name] of [[a, 'Asha'], [b, 'Ravi']]) {
    await db.collection('users_woman').insertOne({
      user_id: uid, role: 'woman', email: `${uid}@t.test`, display_name: name,
      created_at: new Date(), onboarding_answers: { preferred_name: name },
    });
  }
  return { a, b };
}

async function wipe(ids, postId) {
  for (const c of ['users_woman', 'posts', 'comments', 'post_votes', 'post_reports']) {
    try {
      await db.collection(c).deleteMany({
        $or: [{ user_id: { $in: ids } }, { author_id: { $in: ids } }, { post_id: postId ?? '_' }],
      });
    } catch (_) {}
  }
}

test('a vote moves the score by the right amount', async (t) => {
  const { a, b } = await users(`vote_${Date.now()}`);
  const post = await R.createPost({ authorId: a, title: 'T', text: 'x', tags: [] });
  t.after(() => wipe([a, b], post.postId));

  // The trap: switching sides moves a net score by two, not one.
  assert.equal((await R.votePost(post.postId, b, 1)).score, 1);
  assert.equal((await R.votePost(post.postId, b, -1)).score, -1);
  assert.equal((await R.votePost(post.postId, b, 0)).score, 0);

  // And voting the same way twice must not double-count.
  await R.votePost(post.postId, b, 1);
  assert.equal((await R.votePost(post.postId, b, 1)).score, 1);
});

test('comments thread, count and authorise', async (t) => {
  const { a, b } = await users(`cm_${Date.now()}`);
  const post = await R.createPost({ authorId: a, title: 'T', text: 'x', tags: [] });
  t.after(() => wipe([a, b], post.postId));

  const parent = await C.createComment({ postId: post.postId, authorId: b, text: 'try heat' });
  const reply = await C.createComment({
    postId: post.postId, parentId: parent.commentId, authorId: a, text: 'thanks',
  });
  assert.ok(parent.commentId && reply.commentId);

  const feed = await R.listFeed(b, 'home');
  const mine = feed.find((p) => p.postId === post.postId);
  assert.equal(mine?.commentCount, 2, 'the feed count must match the thread');

  // Only the author may delete.
  await assert.rejects(() => C.deleteComment(parent.commentId, a), /unauthori[sz]ed/i);
  assert.ok(await C.deleteComment(reply.commentId, a));
});

test('an anonymous post carries no author', async (t) => {
  const { a, b } = await users(`anon_${Date.now()}`);
  const post = await R.createPost({ authorId: a, title: 'T', text: 'x', tags: [] });
  t.after(() => wipe([a, b], post.postId));

  // Nothing sets this today — the app offers no toggle — which is why it is
  // worth holding: the day someone adds one, the leak must not already exist.
  await db.collection('posts').updateOne(
    { post_id: post.postId }, { $set: { anonymous: true } },
  );

  const seen = await R.getPost(post.postId, b);
  assert.equal(seen.anonymous, true);
  assert.equal(seen.authorName, 'Anonymous', 'her name must not ship');
  assert.equal(seen.authorId, null, 'nor her account id');

  const feed = await R.listFeed(b, 'home');
  const inFeed = feed.find((p) => p.postId === post.postId);
  assert.equal(inFeed?.authorName, 'Anonymous', 'and not through the feed either');
  assert.equal(inFeed?.authorId, null);
});

test('a named post still shows the name', async (t) => {
  const { a, b } = await users(`named_${Date.now()}`);
  const post = await R.createPost({ authorId: a, title: 'T', text: 'x', tags: [] });
  t.after(() => wipe([a, b], post.postId));

  const seen = await R.getPost(post.postId, b);
  assert.equal(seen.authorName, 'Asha');
  assert.equal(seen.authorId, a);
});

test('teardown', async () => {
  await closeDb();
});
