import { logger } from './logger.js';

/**
 * One place that knows what languages the app speaks.
 *
 * The table lived privately inside aiChatService, which is why Docsy chat
 * answered in the user's language and the three stage briefs -- menopause,
 * perimenopause, postpartum -- did not: they had no way to ask for one. A
 * second copy would have drifted, so this is the copy and everything imports
 * it.
 */

/** The languages the app ships strings for. */
export const SUPPORTED_LANGUAGE_CODES = Object.freeze([
  'en', 'hi', 'bn', 'ta', 'te', 'mr', 'kn',
]);

const LABELS = Object.freeze({
  en: 'English',
  hi: 'Hindi',
  bn: 'Bengali',
  ta: 'Tamil',
  te: 'Telugu',
  mr: 'Marathi',
  kn: 'Kannada',
});

/** An unknown or missing code falls back to English rather than failing. */
export function normaliseLanguageCode(languageCode) {
  const value = typeof languageCode === 'string' ? languageCode.trim().toLowerCase() : '';
  return SUPPORTED_LANGUAGE_CODES.includes(value) ? value : 'en';
}

/** The name to use when telling a model which language to write in. */
export function languageLabelForCode(languageCode) {
  return LABELS[normaliseLanguageCode(languageCode)];
}

/**
 * The instruction to append to a prompt that returns JSON.
 *
 * Empty for English, so an English request is byte-for-byte the prompt it was
 * before this existed and nothing about it can regress.
 *
 * The part about keys is not politeness. Every one of these briefs is parsed by
 * key name -- `openingHeadline`, `whatMattersToday` -- and a model told only
 * "reply in Hindi" will cheerfully translate the keys too. That is not a
 * mistranslation, it is a parse failure, and it would surface as the stage
 * brief silently falling back to its generic text.
 */
export function jsonLanguageInstruction(languageCode) {
  const code = normaliseLanguageCode(languageCode);
  if (code === 'en') return '';

  return `

LANGUAGE:
Write every human-readable value entirely in ${LABELS[code]}.
Keep the JSON keys exactly as written above, in English. The keys are read by
name, so a translated key is a parse failure rather than a translation.`;
}

/** The same, for a prompt whose whole reply is prose. */
export function proseLanguageInstruction(languageCode) {
  const code = normaliseLanguageCode(languageCode);
  if (code === 'en') return '';
  return `\n\nWrite your entire reply in ${LABELS[code]}.`;
}

/**
 * The language a user has asked for, from her onboarding answers.
 *
 * These endpoints receive `req.user`, which is the token payload and does not
 * carry onboarding answers, so the record is read here. Best-effort on purpose:
 * a brief in English is a worse brief, but a brief that throws is no brief at
 * all, so every failure path returns 'en'.
 */
export async function resolveUserLanguage(userId) {
  if (!userId) return 'en';

  try {
    // Imported lazily: utils/db.js opens a MongoDB connection at module load,
    // and a static import here would pull that into every consumer of this
    // file, including the unit tests that only want the label table.
    const { userRepository } = await import('../repositories/userRepository.js');
    const user = await userRepository.getUserById(userId);
    return normaliseLanguageCode(user?.onboardingAnswers?.preferred_language);
  } catch (error) {
    logger.warn(`Could not resolve user language, defaulting to English: ${error.message}`);
    return 'en';
  }
}
