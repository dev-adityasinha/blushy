import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

/**
 * The "my posts" feed.
 *
 * `type=mine` lists the viewer's own posts. Two things about it are easy to
 * get wrong and are pinned here: it must not apply the public-only filter
 * (your private posts are yours to see, and a list that dropped them would
 * look like they had been lost), and it must never answer for a request with
 * no user, because "mine" means nothing without one.
 */
async function listFeedBody() {
  const source = await readFile(
    new URL('../src/repositories/postRepository.js', import.meta.url), 'utf8');
  const fromFn = source.slice(source.indexOf('async function listFeed'));
  return fromFn.slice(0, fromFn.indexOf('\n}\n'));
}

test('feed: type=mine lists the posts the viewer wrote', async () => {
  const body = await listFeedBody();
  const mine = body.slice(body.indexOf("type === 'mine'"));
  assert.ok(mine.length > 0, "listFeed must handle type === 'mine'");

  const branch = mine.slice(0, mine.indexOf('\n  }\n'));
  assert.ok(/author_id:\s*userId/.test(branch),
    'mine must filter on the viewer being the author');
});

test('feed: type=mine includes private posts, because they are the viewer\'s own', async () => {
  const body = await listFeedBody();
  const mine = body.slice(body.indexOf("type === 'mine'"));
  const branch = mine.slice(0, mine.indexOf('\n  }\n'));
  assert.ok(!/privacy/.test(branch),
    "the mine branch must not narrow to privacy: 'public'");
});

test('feed: type=mine answers nothing for a request with no user', async () => {
  const body = await listFeedBody();
  const mine = body.slice(body.indexOf("type === 'mine'"));
  const branch = mine.slice(0, mine.indexOf('\n  }\n'));
  assert.ok(/if \(!userId\) return \[\];/.test(branch),
    'without a viewer there is no "mine"');
});

test('feed: the controller documents mine as a feed type', async () => {
  const source = await readFile(
    new URL('../src/controllers/postController.js', import.meta.url), 'utf8');
  assert.ok(/req\.query;\s*\/\/.*\bmine\b/.test(source),
    'listFeed\'s accepted types should list mine beside the others');
});
