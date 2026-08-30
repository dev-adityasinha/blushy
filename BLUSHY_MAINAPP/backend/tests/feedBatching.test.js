import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

/**
 * The feed must not query per post.
 *
 * Building 20 posts cost 116 database round trips and 2.4 seconds: a vote
 * lookup and an author lookup for every row, in a sequential loop. The author
 * lookup was itself two round trips, because it probed the men's collection
 * and missed before trying the women's.
 *
 * Batched into three grouped reads it is 5 calls and 83ms. This is asserted
 * against the source because the cost only becomes visible with enough posts
 * to notice, and the repository is small enough today that a timing test would
 * pass either way.
 */
test('feed: posts are not fetched one query at a time', async () => {
  const source = await readFile(
    new URL('../src/repositories/postRepository.js', import.meta.url), 'utf8');

  const listFeed = source.slice(source.indexOf('async function listFeed'));
  const body = listFeed.slice(0, listFeed.indexOf('\n}\n'));

  // An await on the database inside a loop over posts is the shape to avoid.
  const loops = body.match(/for\s*\(.*of\s+posts[\s\S]{0,400}?await\s+db\./g) ?? [];
  assert.deepEqual(loops, [],
    'listFeed queries inside a loop over posts; gather votes and authors for the whole page instead');

  assert.ok(/\$in:\s*postIds/.test(body), 'votes and counts should be gathered for all post ids at once');
  assert.ok(/findUserDocuments/.test(body), 'authors should be fetched in one batch, not per post');
});

test('feed: the query is bounded', async () => {
  // It read every public post in the database and built a view for each, so
  // the cost grew with the table rather than with what anyone would read.
  const source = await readFile(
    new URL('../src/repositories/postRepository.js', import.meta.url), 'utf8');
  const listFeed = source.slice(source.indexOf('async function listFeed'));
  const body = listFeed.slice(0, listFeed.indexOf('\n}\n'));

  assert.ok(/\.limit\(/.test(body), 'listFeed must cap how many posts it reads');
});

test('user lookup: both collections are probed together', async () => {
  // A user can be in either collection. Checking them one after the other made
  // every woman's record cost two round trips, under nearly every request.
  const source = await readFile(new URL('../src/utils/db.js', import.meta.url), 'utf8');
  const fn = source.slice(source.indexOf('export async function findUserDocument'));
  const body = fn.slice(0, fn.indexOf('\n}\n'));

  assert.ok(/Promise\.all/.test(body),
    'findUserDocument should probe users_man and users_woman concurrently');
});
