import { userRepository } from '../repositories/userRepository.js';
import { onboardingAuditRepository } from '../repositories/onboardingAuditRepository.js';

const EXCLUDED_KEYS = new Set(['preferred_name', 'date_of_birth', 'age_range', 'age', 'name', 'first_name', 'last_name']);

const WEIGHT_UNIT_MAP = {
  kg: 'kg',
  kgs: 'kg',
  kilogram: 'kg',
  kilograms: 'kg',
  lb: 'lb',
  lbs: 'lb',
  pound: 'lb',
  pounds: 'lb',
};

function normalizeText(value) {
  return String(value ?? '').trim();
}

function nowIso() {
  return new Date().toISOString();
}

function normalizeWeightUnit(unitRaw) {
  const unit = normalizeText(unitRaw).toLowerCase();
  return WEIGHT_UNIT_MAP[unit] ?? '';
}

function parseWeightSignals(message) {
  const normalized = normalizeText(message);
  if (!normalized) {
    return {};
  }

  const patch = {};

  const currentWeightMatch = /\b(?:my\s+)?(?:current\s+)?weight\s*(?:is|=|:)?\s*(\d{2,3}(?:\.\d+)?)\s*(kg|kgs|kilograms?|lb|lbs|pounds?)?\b/i.exec(normalized);
  if (currentWeightMatch) {
    const value = currentWeightMatch[1];
    const unit = normalizeWeightUnit(currentWeightMatch[2]);
    patch.weight_current = unit ? `${value} ${unit}` : value;
  }

  const weightChangeMatch = /\b(?:i\s+)?(?:have\s+)?(?:gained|increased|lost|decreased|reduced)\s+(?:my\s+)?weight\s*(?:by)?\s*(\d{1,3}(?:\.\d+)?)\s*(kg|kgs|kilograms?|lb|lbs|pounds?)?\b/i.exec(normalized);
  if (weightChangeMatch) {
    const value = weightChangeMatch[1];
    const unit = normalizeWeightUnit(weightChangeMatch[2]);
    const direction = /\b(gained|increased)\b/i.test(normalized) ? 'increased' : 'decreased';
    patch.recent_major_weight_changes = unit
      ? `${direction} by ${value} ${unit}`
      : `${direction} by ${value}`;
    patch.weight_cycle_changes = 'yes';
  }

  return patch;
}

function parseAllergySignals(message) {
  const normalized = normalizeText(message);
  if (!normalized) {
    return {};
  }

  const patch = {};
  if (/\b(allerg(?:y|ies|ic))\b/i.test(normalized)) {
    patch.allergy_has_any = 'yes';
  }

  const detailsMatch = /\b(?:allergic\s+to|allergy\s+to)\s+([^.,;!?]+)/i.exec(normalized);
  if (detailsMatch) {
    const details = normalizeText(detailsMatch[1]);
    if (details) {
      patch.allergy_details = details;
      patch.nutrition_allergies_sensitivities = details;
    }
  }

  return patch;
}

function parseRelationshipSignals(message) {
  const normalized = normalizeText(message);
  if (!normalized) {
    return {};
  }

  const patch = {};
  if (/\b(i\s+am|i'm)\s+single\b/i.test(normalized)) {
    patch.sex_in_relationship = 'no';
    patch.partner_relationship_status = 'single';
  }
  if (/\b(i\s+am|i'm)\s+(in\s+a\s+relationship|married|engaged)\b/i.test(normalized)) {
    patch.sex_in_relationship = 'yes';
    patch.partner_relationship_status = 'committed';
  }

  return patch;
}

function parseSleepSignals(message) {
  const normalized = normalizeText(message);
  if (!normalized) {
    return {};
  }

  const patch = {};

  if (/\b(sleep|slept|sleeping|insomnia|rest)\b/i.test(normalized)) {
    if (/\b(good|great|well|better)\s+sleep\b/i.test(normalized) || /\bslept\s+well\b/i.test(normalized)) {
      patch.sleep_quality = 'good';
      patch.fertility_sleep_quality = 'good';
    } else if (/\b(bad|poor|worse|worst|terrible|insomnia|couldn'?t\s+sleep|didn'?t\s+sleep)\b/i.test(normalized)) {
      patch.sleep_quality = 'poor';
      patch.fertility_sleep_quality = 'poor';
    } else {
      patch.sleep_quality = patch.sleep_quality ?? 'average';
      patch.fertility_sleep_quality = patch.fertility_sleep_quality ?? 'average';
    }
  }

  return patch;
}

function parseExerciseSignals(message) {
  const normalized = normalizeText(message);
  if (!normalized) {
    return {};
  }

  const patch = {};
  const hasExerciseSignal = /\b(exercise|workout|gym|run|running|walk|walking|yoga|training)\b/i.test(normalized);
  if (!hasExerciseSignal) {
    return patch;
  }

  if (/\b(daily|every\s+day)\b/i.test(normalized)) {
    patch.fitness_frequency = 'daily';
    patch.exercise_level = 'high';
    patch.fitness_activity_level = 'very active';
  } else if (/\b(3\s*[-to]{1,3}\s*5\s*times|3\s*to\s*5\s*times|few\s+times\s+a\s+week)\b/i.test(normalized)) {
    patch.fitness_frequency = '3-5 times/week';
    patch.exercise_level = 'moderate';
    patch.fitness_activity_level = 'lightly active';
  } else if (/\b(1\s*[-to]{1,3}\s*2\s*times|once\s+a\s+week|twice\s+a\s+week)\b/i.test(normalized)) {
    patch.fitness_frequency = '1-2 times/week';
    patch.exercise_level = 'low';
    patch.fitness_activity_level = 'lightly active';
  } else if (/\b(rarely|never|no\s+exercise|don'?t\s+exercise|inactive|sedentary)\b/i.test(normalized)) {
    patch.fitness_frequency = 'rarely';
    patch.exercise_level = 'none';
    patch.fitness_activity_level = 'sedentary';
  }

  return patch;
}

function parseDietSignals(message) {
  const normalized = normalizeText(message);
  if (!normalized) {
    return {};
  }

  const patch = {};

  if (/\b(vegan)\b/i.test(normalized)) {
    patch.nutrition_dietary_preference = 'vegan';
  } else if (/\b(vegetarian|veg)\b/i.test(normalized)) {
    patch.nutrition_dietary_preference = 'vegetarian';
  } else if (/\b(non\s*vegetarian|non\s*veg)\b/i.test(normalized)) {
    patch.nutrition_dietary_preference = 'non-vegetarian';
  }

  if (/\b(balanced\s+diet|healthy\s+diet|eat\s+healthy)\b/i.test(normalized)) {
    patch.weight_eating_habits = 'balanced';
  } else if (/\b(irregular\s+diet|junk\s+food|skip\s+meals|late\s+night\s+eating)\b/i.test(normalized)) {
    patch.weight_eating_habits = 'irregular';
  }

  return patch;
}

function parseSymptomDurationSignals(message) {
  const normalized = normalizeText(message);
  if (!normalized) {
    return {};
  }

  const patch = {};
  const durationMatch = /\bfor\s+(\d{1,3})\s*(day|days|week|weeks|month|months|hour|hours)\b/i.exec(normalized)
    || /\bsince\s+(\d{1,3})\s*(day|days|week|weeks|month|months|hour|hours)\b/i.exec(normalized);

  if (!durationMatch) {
    return patch;
  }

  const durationText = `${durationMatch[1]} ${durationMatch[2].toLowerCase()}`;

  if (/\b(headache|migraine|cramp|pain|bloating|nausea|fatigue|dizzy|dizziness|fever|cold|allergy|allergies)\b/i.test(normalized)) {
    patch.ai_symptom_duration = durationText;
    patch.ai_symptom_note = normalized.slice(0, 200);
  }

  return patch;
}

function buildPatchFromMessage(message) {
  const normalized = normalizeText(message);
  if (!normalized) {
    return {};
  }

  const patch = {
    ai_last_user_update: normalized.slice(0, 300),
    ai_last_user_update_at: nowIso(),
    ai_last_user_update_source: 'ai-chat',
  };

  Object.assign(patch, parseWeightSignals(normalized));
  Object.assign(patch, parseAllergySignals(normalized));
  Object.assign(patch, parseRelationshipSignals(normalized));
  Object.assign(patch, parseSleepSignals(normalized));
  Object.assign(patch, parseExerciseSignals(normalized));
  Object.assign(patch, parseDietSignals(normalized));
  Object.assign(patch, parseSymptomDurationSignals(normalized));

  return patch;
}

function removeExcludedKeys(patch) {
  const next = {};
  for (const [key, value] of Object.entries(patch)) {
    if (EXCLUDED_KEYS.has(key)) {
      continue;
    }
    if (typeof value !== 'string') {
      continue;
    }
    const trimmed = value.trim();
    if (!trimmed) {
      continue;
    }
    next[key] = trimmed;
  }

  return next;
}

async function upsertOnboardingFromChatMessage({ userId, message }) {
  if (!userId || typeof message !== 'string' || message.trim().length === 0) {
    return {
      updated: false,
      reason: 'invalid-input',
      changedKeys: [],
    };
  }

  const onboarding = await userRepository.getOnboardingAnswers(userId);
  const existingAnswers = onboarding?.onboardingAnswers ?? {};

  const rawPatch = buildPatchFromMessage(message);
  const patch = removeExcludedKeys(rawPatch);
  const changedKeys = Object.keys(patch).filter((key) => {
    if (key.startsWith('ai_last_user_update')) {
      return false;
    }
    return existingAnswers[key] !== patch[key];
  });

  if (changedKeys.length === 0) {
    return {
      updated: false,
      reason: 'no-new-data',
      changedKeys: [],
    };
  }

  const nextAnswers = {
    ...existingAnswers,
    ...patch,
  };

  const updatedUser = await userRepository.updateOnboardingAnswers(userId, nextAnswers);

  const previousValues = Object.fromEntries(changedKeys.map((key) => [key, existingAnswers[key] ?? null]));
  const newValues = Object.fromEntries(changedKeys.map((key) => [key, nextAnswers[key] ?? null]));

  await onboardingAuditRepository.appendAuditTrailEntry({
    userId,
    source: 'ai-chat',
    changedKeys,
    previousValues,
    newValues,
    messageSnippet: normalizeText(message).slice(0, 300),
  });

  return {
    updated: Boolean(updatedUser),
    reason: updatedUser ? 'updated' : 'update-failed',
    changedKeys,
    latestUpdate: patch.ai_last_user_update ?? null,
    source: 'ai-chat',
  };
}

export const onboardingFromChatService = {
  upsertOnboardingFromChatMessage,
};