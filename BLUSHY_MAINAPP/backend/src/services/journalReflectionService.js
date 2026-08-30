import { journalRepository } from '../repositories/journalRepository.js';

/**
 * Reflections drawn from what the user actually wrote in their journal.
 *
 * This replaced a fixed lookup table keyed only on life stage. It read no
 * journal at all, yet was shown as "AI Reflection" -- and one branch claimed
 * "Your reflection logs indicate balanced energy" while reading nothing. It
 * also asserted hormone levels ("Estrogen is naturally rising"), which spec 14
 * forbids without validated lab or device data, which Blushy does not ingest.
 *
 * Everything here is derived from the entries themselves and is deliberately
 * deterministic: a reflection on someone's own writing should not disappear
 * because a model was unreachable, and it must never assert a physiological
 * state nobody measured.
 */

export const JOURNAL_REFLECTION_VERSION = 'journal-reflection-v1.0.0';

/**
 * Themes are surfaced only as "you wrote about X", never as a diagnosis or a
 * cause. The word list is intentionally plain vocabulary, not symptom coding.
 */
const THEME_WORDS = Object.freeze([
  ['sleep', ['sleep', 'slept', 'tired', 'exhausted', 'rest', 'nap', 'insomnia']],
  ['work', ['work', 'job', 'meeting', 'deadline', 'office', 'boss', 'shift']],
  ['family', ['family', 'mum', 'mom', 'dad', 'sister', 'brother', 'parents']],
  ['your partner', ['partner', 'husband', 'boyfriend', 'wife', 'girlfriend']],
  ['friends', ['friend', 'friends']],
  ['movement', ['walk', 'walked', 'run', 'ran', 'gym', 'yoga', 'exercise', 'swim']],
  ['food', ['ate', 'eating', 'food', 'meal', 'dinner', 'lunch', 'breakfast', 'cook']],
  ['stress', ['stress', 'stressed', 'anxious', 'anxiety', 'worried', 'overwhelmed']],
  ['rest and quiet', ['quiet', 'calm', 'peaceful', 'slow', 'relax']],
]);

function countWords(text) {
  return String(text ?? '')
    .split(/\s+/)
    .filter((word) => word.length > 0).length;
}

function collectText(entries) {
  return (entries ?? [])
    .map((entry) => `${entry?.title ?? ''} ${entry?.body ?? ''}`)
    .join(' ');
}

function detectThemes(text) {
  const lower = text.toLowerCase();
  const found = [];
  for (const [label, words] of THEME_WORDS) {
    if (words.some((word) => lower.includes(word))) {
      found.push(label);
    }
  }
  return found;
}

function listPhrase(items) {
  if (items.length === 0) return '';
  if (items.length === 1) return items[0];
  if (items.length === 2) return `${items[0]} and ${items[1]}`;
  return `${items.slice(0, -1).join(', ')} and ${items.at(-1)}`;
}

/**
 * Builds the reflection text.
 *
 * Every sentence is a statement about the writing itself -- how much, how
 * often, what it mentions. Nothing here interprets a mood, infers a cause, or
 * describes the body.
 */
export function buildJournalReflection(days) {
  const withEntries = (days ?? []).filter((day) => (day.entries ?? []).length > 0);

  if (withEntries.length === 0) {
    return null;
  }

  const allEntries = withEntries.flatMap((day) => day.entries ?? []);
  const text = collectText(allEntries);
  const words = countWords(text);
  const themes = detectThemes(text);

  const sentences = [];

  const dayCount = withEntries.length;
  const entryCount = allEntries.length;

  if (dayCount === 1) {
    sentences.push(
      entryCount === 1
        ? 'You wrote once, in about ' + words + ' words.'
        : `You wrote ${entryCount} times, in about ${words} words altogether.`,
    );
  } else {
    sentences.push(
      `You wrote on ${dayCount} days, ${entryCount} entries in about ${words} words altogether.`,
    );
  }

  if (themes.length > 0) {
    sentences.push(`You came back to ${listPhrase(themes.slice(0, 3))}.`);
  }

  // Named as an observation about the writing, not about her.
  const longest = allEntries
    .map((entry) => ({ title: entry?.title ?? '', length: countWords(entry?.body) }))
    .sort((a, b) => b.length - a.length)[0];

  if (longest && longest.title.trim().length > 0 && longest.length > 0) {
    sentences.push(`The most you wrote in one sitting was "${longest.title.trim()}".`);
  }

  return {
    reflection: sentences.join(' '),
    themes,
    wordCount: words,
    entryCount,
    dayCount,
    version: JOURNAL_REFLECTION_VERSION,
  };
}

/**
 * Today's reflection, or null when nothing has been written today.
 *
 * Null is a real answer. The previous version had no empty state at all: with
 * no journal it still returned a confident paragraph.
 */
export async function getJournalReflection(userId, { days = 7 } = {}) {
  const journals = await journalRepository.getJournalsByUserId(userId, days);
  return buildJournalReflection(journals);
}
