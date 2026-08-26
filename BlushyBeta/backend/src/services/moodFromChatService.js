import { dailyMoodRepository } from '../repositories/dailyMoodRepository.js';

const MOOD_KEYWORDS = {
  great: ['happy', 'great', 'amazing', 'awesome', 'excited', 'joyful'],
  okay: ['okay', 'ok', 'fine', 'alright', 'normal', 'so so', 'neutral'],
  low: ['sad', 'down', 'depressed', 'low', 'upset', 'heartbroken', 'lonely'],
  anxious: ['anxious', 'anxiety', 'worried', 'nervous', 'panic', 'tense'],
  irritated: ['angry', 'irritated', 'annoyed', 'frustrated', 'mad', 'pissed'],
};

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

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

  const moodPriority = ['low', 'anxious', 'irritated', 'okay', 'great'];
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

function looksLikeMoodUpdate(message) {
  const normalized = String(message || '').toLowerCase();
  if (normalized.trim().length === 0) {
    return false;
  }

  const hasFeelingContext = /(\bi\s*(am|'m)\b|\bi\s*feel\b|\bfeeling\b|\bmy mood\b|\bmood is\b)/.test(normalized);
  if (!hasFeelingContext) {
    return false;
  }

  return detectMood(normalized) != null;
}

function inferEnergyLevel(message, mood) {
  const normalized = String(message || '').toLowerCase();
  if (/\b(very tired|exhausted|drained|no energy|energy low)\b/.test(normalized)) {
    return 'low';
  }

  if (/\b(energetic|full of energy|active|super active|energy high)\b/.test(normalized)) {
    return 'high';
  }

  if (mood === 'great') {
    return 'high';
  }
  if (mood === 'low' || mood === 'anxious') {
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
  if (mood === 'great') {
    return 'low';
  }

  return 'medium';
}

async function upsertMoodFromChatMessage({ userId, message }) {
  if (!userId || typeof message !== 'string' || message.trim().length === 0) {
    return { updated: false, reason: 'invalid-input' };
  }

  if (!looksLikeMoodUpdate(message)) {
    return { updated: false, reason: 'no-mood-detected' };
  }

  const mood = detectMood(message);
  if (!mood) {
    return { updated: false, reason: 'no-mood-detected' };
  }

  const entryDate = todayIso();
  const energyLevel = inferEnergyLevel(message, mood);
  const stressLevel = inferStressLevel(message, mood);

  const row = await dailyMoodRepository.upsertDailyMood({
    userId,
    entryDate,
    mood,
    energyLevel,
    stressLevel,
    notes: '',
  });

  return {
    updated: Boolean(row),
    reason: row ? 'updated' : 'update-failed',
    entryDate,
    mood,
    energyLevel,
    stressLevel,
    source: 'ai-chat',
  };
}

export const moodFromChatService = {
  upsertMoodFromChatMessage,
};
