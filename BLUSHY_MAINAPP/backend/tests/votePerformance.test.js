import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

/**
 * Voting must not read the same post twice.
 *
 * A single upvote took 643ms across 16 database calls: it fetched the post to
 * check it existed, fetched the existing vote, wrote the vote, incremented the
 * score, then fetched the same post again to return it — five sequential round
 * trips, two of them for the same document.
 *
 * The two lookups do not depend on each other, and the increment can return
 * the updated document itself. That is 190ms.
 *
 * Source-level: the cost is in the number of round trips, which a functional
 * test against an in-memory database does not reproduce.
 */
test('vote: the post and the existing vote are fetched together', async () => {
  const source = await readFile(
    new URL('../src/repositories/postRepository.js', import.meta.url), 'utf8');

  const fn = source.slice(source.indexOf('async function votePost'));
  const body = fn.slice(0, fn.indexOf('\n}\n'));

  assert.ok(/Promise\.all/.test(body),
    'the post lookup and the vote lookup are independent and should overlap');
});

test('vote: the score increment returns the updated post', async () => {
  const source = await readFile(
    new URL('../src/repositories/postRepository.js', import.meta.url), 'utf8');
  const fn = source.slice(source.indexOf('async function votePost'));
  const body = fn.slice(0, fn.indexOf('\n}\n'));

  assert.ok(/findOneAndUpdate/.test(body),
    'incrementing then re-reading the same row is two round trips for one fact');
});

test('vote: the post is still checked before anything is written', async () => {
  // The existence check is not an optimisation target. Without it, voting on a
  // deleted post leaves a row in post_votes that nothing ever cleans up.
  const source = await readFile(
    new URL('../src/repositories/postRepository.js', import.meta.url), 'utf8');
  const fn = source.slice(source.indexOf('async function votePost'));
  const body = fn.slice(0, fn.indexOf('\n}\n'));

  const guard = body.indexOf('if (!post) return null;');
  const firstWrite = Math.min(
    ...['post_votes\').insertOne', 'post_votes\').updateOne', 'post_votes\').deleteOne']
      .map((m) => { const i = body.indexOf(m); return i === -1 ? Number.MAX_SAFE_INTEGER : i; }),
  );

  assert.ok(guard > -1, 'the existence guard is missing');
  assert.ok(guard < firstWrite, 'the guard must come before any write to post_votes');
});
