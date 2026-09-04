import test from 'node:test';
import assert from 'node:assert/strict';

import { rankForViewer } from '../src/controllers/postController.js';
import { closeDb, db } from '../src/utils/db.js';

/**
 * The Community tab orders Home by relevance, and leaves every other order
 * alone.
 *
 * The scoring already existed and reached only the home page's personalized
 * sections. The Community tab queried `{ privacy: 'public' }` and showed
 * everyone the same list in date order, so a person in perimenopause opened it
 * onto whatever had been posted most recently by anyone.
 *
 * These pin the boundary as much as the behaviour. `latest` and `trending`
 * promise an order in their own names, and a search is a stated intent --
 * reordering either by life stage would take something away rather than add
 * to it.
 */
const UID = 'test_rank_viewer';

function post(id, tags, daysAgo = 0) {
  return {
    post_id: id,
    tags,
    title: '',
    text: '',
    score: 0,
    created_at: new Date(Date.now() - daysAgo * 86400000).toISOString(),
  };
}

// Newest first, as the query returns them.
const FEED = [
  post('unrelated_new', ['acne'], 0),
  post('stage_old', ['perimenopause'], 5),
  post('symptom_old', ['hot flashes'], 6),
];

const ids = (list) => list.map((p) => p.post_id);

test('Home is ordered by relevance to her', async (t) => {
  await db.collection('users_woman').insertOne({
    user_id: UID,
    role: 'woman',
    life_stage: 'perimenopause',
    onboarding_answers: { life_stage: 'perimenopause' },
  });
  // Symptoms come from what she has logged in the last 30 days, not from what
  // she ticked at onboarding -- see `getUserSignals`. Writing them onto the
  // profile looks right and scores nothing.
  await db.collection('user_daily_logs_woman').insertOne({
    user_id: UID,
    log_date: new Date().toISOString().slice(0, 10),
    symptoms: ['hot flashes'],
  });
  t.after(async () => {
    await db.collection('users_woman').deleteMany({ user_id: UID });
    await db.collection('user_daily_logs_woman').deleteMany({ user_id: UID });
  });

  const ranked = await rankForViewer(FEED, UID, 'home', '');

  // Both relevant posts are older than the unrelated one and still come first.
  assert.deepEqual(ids(ranked).slice(0, 2).sort(), ['stage_old', 'symptom_old']);
  assert.equal(ids(ranked)[2], 'unrelated_new');
});

test('nothing is removed, only moved', async () => {
  const ranked = await rankForViewer(FEED, UID, 'home', '');
  assert.equal(ranked.length, FEED.length);
  assert.deepEqual(ids(ranked).sort(), ids(FEED).sort());
});

test('latest, trending and following keep their own order', async () => {
  for (const type of ['latest', 'trending', 'following']) {
    const ranked = await rankForViewer(FEED, UID, type, '');
    assert.deepEqual(ids(ranked), ids(FEED), `${type} was reordered`);
  }
});

test('a search keeps the order the search produced', async () => {
  const ranked = await rankForViewer(FEED, UID, 'home', 'cramps');
  assert.deepEqual(ids(ranked), ids(FEED));
});

test('someone with nothing on file sees what they saw before', async (t) => {
  const blank = 'test_rank_blank';
  await db.collection('users_woman').insertOne({
    user_id: blank, role: 'woman', onboarding_answers: {},
  });
  t.after(async () => {
    await db.collection('users_woman').deleteMany({ user_id: blank });
  });

  const ranked = await rankForViewer(FEED, blank, 'home', '');
  assert.deepEqual(ids(ranked), ids(FEED));
});

test('a feed that cannot be scored is still a feed', async () => {
  // No such user, so gathering signals finds nothing. The order must survive.
  const ranked = await rankForViewer(FEED, 'test_rank_missing', 'home', '');
  assert.deepEqual(ids(ranked), ids(FEED));
});

test.after(async () => {
  await closeDb();
});
