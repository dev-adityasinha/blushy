import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

import {
  SUPPORTED_LANGUAGE_CODES,
  jsonLanguageInstruction,
  languageLabelForCode,
  normaliseLanguageCode,
  proseLanguageInstruction,
} from '../src/utils/language.js';

/**
 * Docsy chat answered in the user's language and the three stage briefs did
 * not, because the language table was private to aiChatService and the briefs
 * had no way to ask for one. These cover the two things that can go wrong now
 * that they can: an English request must be unchanged, and a translated
 * request must not translate the JSON keys the briefs are parsed by.
 */

test('an unknown or missing code falls back to English', () => {
  for (const bad of [undefined, null, '', '   ', 'klingon', 'en-GB', 42, {}]) {
    assert.equal(normaliseLanguageCode(bad), 'en', `for ${JSON.stringify(bad)}`);
  }
  assert.equal(normaliseLanguageCode('  HI  '), 'hi', 'case and padding are tolerated');
});

test('every supported code has a label', () => {
  for (const code of SUPPORTED_LANGUAGE_CODES) {
    const label = languageLabelForCode(code);
    assert.ok(label && label.length > 0, `${code} needs a label`);
  }
  assert.equal(languageLabelForCode('hi'), 'Hindi');
  assert.equal(languageLabelForCode('kn'), 'Kannada');
});

test('English adds nothing to a prompt', () => {
  // The point: an English request must send byte-for-byte the prompt it sent
  // before any of this existed, so it cannot regress.
  assert.equal(jsonLanguageInstruction('en'), '');
  assert.equal(jsonLanguageInstruction(undefined), '');
  assert.equal(proseLanguageInstruction('en'), '');
});

test('a translated brief is told to keep its JSON keys in English', () => {
  // Without this the model translates the keys too. That is not a
  // mistranslation, it is a parse failure: the brief falls back to its generic
  // text and nothing in the logs says why.
  const instruction = jsonLanguageInstruction('hi');
  assert.match(instruction, /Hindi/);
  assert.match(instruction, /keys/i);
  assert.match(instruction, /English/);
});

test('the prose instruction names the language and says nothing about keys', () => {
  const instruction = proseLanguageInstruction('ta');
  assert.match(instruction, /Tamil/);
  assert.doesNotMatch(instruction, /JSON/i);
});

test('the three stage briefs actually ask for a language', async () => {
  // The generators taking a `languageCode` is only half of it; a caller that
  // never passes one leaves them defaulting to English for ever, which is the
  // state this change exists to fix.
  const services = [
    '../src/services/docsyMenopauseService.js',
    '../src/services/docsyPerimenopauseService.js',
    '../src/services/docsyPostpartumService.js',
  ];
  for (const rel of services) {
    const source = await readFile(new URL(rel, import.meta.url), 'utf8');
    assert.match(source, /languageCode/, `${rel} should accept a language`);
    assert.match(
      source,
      /\$\{jsonLanguageInstruction\(languageCode\)\}/,
      `${rel} should put the instruction in its prompt`,
    );
  }

  const callers = [
    '../src/services/menopauseService.js',
    '../src/services/perimenopauseService.js',
    '../src/services/postpartumService.js',
  ];
  for (const rel of callers) {
    const source = await readFile(new URL(rel, import.meta.url), 'utf8');
    assert.match(
      source,
      /languageCode: await resolveUserLanguage\(userId\)/,
      `${rel} should supply the user's language`,
    );
  }
});

test('the language table has exactly one home', async () => {
  // It used to live privately in aiChatService, which is why the briefs could
  // not reach it. A second copy would drift back to the same problem.
  const chat = await readFile(
    new URL('../src/services/aiChatService.js', import.meta.url), 'utf8',
  );
  assert.doesNotMatch(
    chat,
    /function languageLabelForCode/,
    'aiChatService should import the shared table, not redeclare it',
  );
  assert.match(chat, /from '\.\.\/utils\/language\.js'/);
});
