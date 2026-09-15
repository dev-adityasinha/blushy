import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

/**
 * Docsy's replies are short and shaped.
 *
 * The chat prompt asks for concision in general terms; that was not enough
 * to stop wall-of-text answers. A rule with a number and a shape is pinned
 * here, and pinned *beside* the concision rule so it cannot drift into the
 * context section -- which carries what the user chose to share and must
 * not be edited by a formatting change.
 */
async function prompt() {
  return readFile(new URL('../src/controllers/aiController.js', import.meta.url), 'utf8');
}

test('the chat prompt caps a reply and asks for points', async () => {
  const src = await prompt();
  const at = src.indexOf('LENGTH AND SHAPE OF A REPLY');
  assert.ok(at > -1, 'the length rule must be in the prompt');
  const rule = src.slice(at, at + 400);
  assert.match(rule, /under about 120 words/, 'a number, not "be brief"');
  assert.match(rule, /blank line between points/, 'points, with air between them');
  assert.match(rule, /Never a single long paragraph/);
});

test('the length rule sits with the concision rule, not in the context', async () => {
  const src = await prompt();
  const rule = src.indexOf('LENGTH AND SHAPE OF A REPLY');
  const concise = src.indexOf('7. BE CONCISE');
  const reassure = src.indexOf('8. BE REASSURING WITHOUT FALSE REASSURANCE');
  assert.ok(concise < rule && rule < reassure,
    'the rule belongs inside section 7, between concision and reassurance');
  const context = src.indexOf('User Research Context:');
  assert.ok(context > rule, 'the context block after it is untouched by it');
});
