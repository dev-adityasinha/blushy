import { dailyMoodRepository } from '../repositories/dailyMoodRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { todayIso } from '../utils/appCalendar.js';

const MOOD_KEYWORDS = {
  great: ['happy', 'great', 'amazing', 'awesome', 'excited', 'joyful', 'wonderful', 'super', 'cheerful', 'grateful'],
  calm: ['calm', 'peaceful', 'relaxed', 'balanced', 'content', 'chill', 'serene', 'grounded'],
  okay: ['okay', 'ok', 'fine', 'alright', 'normal', 'so so', 'neutral', 'surviving'],
  low: ['sad', 'down', 'depressed', 'low', 'upset', 'heartbroken', 'lonely', 'crying', 'unhappy', 'gloomy'],
  anxious: ['anxious', 'anxiety', 'worried', 'nervous', 'panic', 'tense', 'overthinking', 'uneasy', 'fearful'],
  irritated: ['angry', 'irritated', 'annoyed', 'frustrated', 'mad', 'pissed', 'moody', 'cranky', 'grumpy'],
  exhausted: ['exhausted', 'drained', 'fatigued', 'burned out', 'burnt out', 'wiped out', 'low battery'],
};

const SYMPTOM_KEYWORDS = [
  'cramps', 'headache', 'migraine', 'bloating', 'bloated', 'acne', 'breakout',
  'hot flash', 'hot flashes', 'night sweats', 'brain fog', 'foggy', 'fatigue',
  'joint pain', 'body ache', 'backache', 'back pain', 'nausea', 'nauseous',
  'breast tenderness', 'tender breasts', 'pelvic pain', 'mood swings', 'insomnia',
  'food cravings', 'sugar cravings', 'dizziness', 'dizzy', 'spotting'
];


function containsAnyKeyword(message, keywords) {
  return keywords.some((keyword) => {
    const safe = keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s+');
    return new RegExp(`\\b${safe}\\b`, 'i').test(message);
  });
}

function containsPositiveGood(message) {
  if (!/\bgood\b/i.test(message)) {
    return false;
  }

  const negatedGoodPatterns = [
    /\bnot\s+(?:feeling\s+)?good\b/i,
    /\bno\s+good\b/i,
    /\bnever\s+good\b/i,
    /\b(?:is|am|are|'m|'re|was|were)\s+not\s+good\b/i,
    /\bdon't\s+feel\s+good\b/i,
    /\bdoesn't\s+feel\s+good\b/i,
    /\bdidn't\s+feel\s+good\b/i,
  ];

  return !negatedGoodPatterns.some((pattern) => pattern.test(message));
}

function detectMood(message) {
  const normalized = String(message || '').toLowerCase();

  const moodPriority = ['exhausted', 'low', 'anxious', 'irritated', 'calm', 'okay', 'great'];
  for (const mood of moodPriority) {
    const keywords = MOOD_KEYWORDS[mood] || [];
    if (mood === 'great') {
      if (containsAnyKeyword(normalized, keywords) || containsPositiveGood(normalized)) {
        return mood;
      }
      continue;
    }

    if (containsAnyKeyword(normalized, keywords)) {
      return mood;
    }
  }

  return null;
}

function detectSymptoms(message) {
  const normalized = String(message || '').toLowerCase();
  const found = [];
  for (const sym of SYMPTOM_KEYWORDS) {
    if (new RegExp(`\\b${sym}\\b`, 'i').test(normalized)) {
      // Normalize to title case
      const titleCase = sym.charAt(0).toUpperCase() + sym.slice(1);
      found.push(titleCase);
    }
  }
  return found;
}

function looksLikeMoodOrSymptomUpdate(message) {
  const normalized = String(message || '').toLowerCase();
  if (normalized.trim().length === 0) {
    return false;
  }

  const hasFeelingContext = /(\bi\s*(am|'m)\b|\bi\s*feel\b|\bfeeling\b|\bmy mood\b|\bmood is\b|\bi\s*have\b|\bhaving\b|\bexperiencing\b|\bsuffering\b|\bgot\b)/.test(normalized);
  const detectedMood = detectMood(normalized);
  const detectedSymptoms = detectSymptoms(normalized);

  return (hasFeelingContext && (detectedMood != null || detectedSymptoms.length > 0)) || (detectedSymptoms.length > 0);
}

function inferEnergyLevel(message, mood) {
  const normalized = String(message || '').toLowerCase();
  if (/\b(very tired|exhausted|drained|no energy|energy low|fatigue|sleepy|sluggish)\b/.test(normalized)) {
    return 'low';
  }

  if (/\b(energetic|full of energy|active|super active|energy high|high energy|great energy)\b/.test(normalized)) {
    return 'high';
  }

  if (mood === 'great') {
    return 'high';
  }
  if (mood === 'low' || mood === 'anxious' || mood === 'exhausted') {
    return 'low';
  }

  return 'medium';
}

function inferStressLevel(message, mood) {
  const normalized = String(message || '').toLowerCase();
  if (/\b(stressed|stressful|overwhelmed|panic|panicking|anxious|anxiety|worried|nervous)\b/.test(normalized)) {
    return 'high';
  }

  if (/\b(calm|peaceful|relaxed|chill)\b/.test(normalized)) {
    return 'low';
  }

  if (mood === 'anxious' || mood === 'irritated') {
    return 'high';
  }
  if (mood === 'great' || mood === 'calm') {
    return 'low';
  }

  return 'medium';
}

async function upsertMoodFromChatMessage({ userId, message }) {
  if (!userId || typeof message !== 'string' || message.trim().length === 0) {
    return { updated: false, reason: 'invalid-input' };
  }

  if (!looksLikeMoodOrSymptomUpdate(message)) {
    return { updated: false, reason: 'no-mood-or-symptom-detected' };
  }

  const mood = detectMood(message) || 'okay';
  const symptoms = detectSymptoms(message);
  const entryDate = todayIso();
  const energyLevel = inferEnergyLevel(message, mood);
  const stressLevel = inferStressLevel(message, mood);

  const row = await dailyMoodRepository.upsertDailyMood({
    userId,
    entryDate,
    mood,
    energyLevel,
    stressLevel,
    symptoms,
    notes: '',
  });

  // Also patch user's onboardingAnswers check-in cache
  try {
    const patch = {};
    if (mood) patch['checkin_feeling'] = mood;
    if (energyLevel) patch['checkin_energy'] = energyLevel;
    if (symptoms.length > 0) patch['checkin_symptoms'] = symptoms;
    if (Object.keys(patch).length > 0) {
      await userRepository.updateOnboardingAnswers(userId, patch);
    }
  } catch (_) {}

  return {
    updated: Boolean(row),
    reason: row ? 'updated' : 'update-failed',
    entryDate,
    mood,
    energyLevel,
    stressLevel,
    symptoms,
    source: 'ai-chat',
  };
}

export const moodFromChatService = {
  upsertMoodFromChatMessage,
};
