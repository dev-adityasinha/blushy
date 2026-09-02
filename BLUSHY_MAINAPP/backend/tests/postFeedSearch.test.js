import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

/**
 * Searching the feed on the server.
 *
 * The client could only filter the page it already held, so anything past the
 * first page was unfindable, while people search hit the server and was not.
 */
const repo = readFileSync(
  new URL('../src/repositories/postRepository.js', import.meta.url), 'utf8');
const controller = readFileSync(
  new URL('../src/controllers/postController.js', import.meta.url), 'utf8');

test('the search term is matched literally, not as a pattern', () => {
  // A stray ( or * would otherwise throw or quietly mean something else.
  assert.match(repo, /function escapeForRegex/);
  assert.match(repo, /escapeForRegex\(term\)/);
});

test('it searches the fields the box advertises', () => {
  const start = repo.indexOf('const anyField = [');
  const block = repo.slice(start, repo.indexOf('];', start));
  for (const field of ['title', 'text', 'tags']) {
    assert.ok(block.includes(`{ ${field}: pattern }`), `${field} not searched`);
  }
});

test('author search uses the name people actually see', () => {
  // buildPostView renders onboarding_answers.preferred_name; matching only
  // display_name would have found nothing for most accounts.
  assert.match(repo, /'onboarding_answers\.preferred_name': pattern/);
});

test('an anonymous post cannot be found by its author name', () => {
  const start = repo.indexOf('if (matchingAuthorIds.length > 0)');
  const block = repo.slice(start, start + 260);
  assert.match(block, /anonymous: \{ \$ne: true \}/,
    'that would undo the anonymity the rest of the file protects');
});

test('the endpoint accepts a bounded search term', () => {
  assert.match(controller, /const \{ type, search \} = req\.query/);
  assert.match(controller, /search\.slice\(0, 120\)/);
});
