import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

/**
 * Dr. Docsy's replies should read as a person wrote them.
 *
 * The prompt used to invite emoji and was itself written with em dashes, which
 * is the surest way to get them back: the model mirrors the punctuation of its
 * own instructions.
 */
const source = readFileSync(
  new URL('../src/services/aiChatService.js', import.meta.url),
  'utf8',
);

test('the prompt does not model the punctuation it bans', () => {
  assert.equal(source.includes('\u2014'), false, 'em dash in the prompt');
  assert.equal(source.includes('\u2013'), false, 'en dash in the prompt');
});

test('the prompt carries no emoji for the model to copy', () => {
  const emoji = /[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]/u;
  const offenders = source
    .split('\n')
    .map((line, i) => [i + 1, line])
    .filter(([, line]) => emoji.test(line));
  assert.deepEqual(offenders, []);
});

test('emoji and dashes are ruled out explicitly', () => {
  assert.match(source, /Never use emoji/);
  assert.match(source, /Never use an em dash or an en dash/);
});

test('emoji are not invited anywhere', () => {
  assert.equal(/Emoji are welcome/.test(source), false);
});
