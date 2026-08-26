import { userRepository } from '../repositories/userRepository.js';

const FOLLOW_UP_QUESTION = 'What type of medication are you taking? If you share the name or type, I can note it properly.';

const TYPE_PATTERNS = [
  {
    value: 'birth control',
    patterns: [
      /\bbirth\s*control\b/i,
      /\bcontracept(?:ive|ion|ives?)\b/i,
      /\bthe\s+pill\b/i,
    ],
  },
  {
    value: 'hormonal medication',
    patterns: [
      /\bhormonal\s+medication\b/i,
      /\bhormone\s+therapy\b/i,
      /\bhrt\b/i,
    ],
  },
  {
    value: 'pain relief',
    patterns: [
      /\bpain\s+relief\b/i,
      /\bpainkillers?\b/i,
      /\banalgesics?\b/i,
      /\bibuprofen\b/i,
      /\bparacetamol\b/i,
      /\bacetaminophen\b/i,
      /\bnaproxen\b/i,
    ],
  },
  {
    value: 'antibiotics',
    patterns: [
      /\bantibiotics?\b/i,
      /\binsulin\b/i,
      /\binhaler\b/i,
    ],
  },
  {
    value: 'mental health medication',
    patterns: [
      /\bmental\s+health\s+medication\b/i,
      /\bantidepressants?\b/i,
      /\banti-?anxiety\b/i,
      /\banxiolytics?\b/i,
      /\bssri\b/i,
    ],
  },
];

const GENERIC_TYPE_WORDS = new Set([
  'medication',
  'medicine',
  'meds',
  'pill',
  'pills',
  'tablet',
  'tablets',
  'drug',
  'drugs',
]);

const GENERIC_NON_MED_WORDS = new Set([
  'breakfast',
  'brunch',
  'lunch',
  'dinner',
  'snack',
  'water',
  'food',
  'sleep',
  'rest',
  'vacation',
  'holiday',
]);

function normalizeText(value) {
  return String(value ?? '').trim();
}

function containsMedicationContext(message) {
  const normalized = message.trim();
  if (!normalized) {
    return false;
  }

  if (TYPE_PATTERNS.some((item) => item.patterns.some((pattern) => pattern.test(normalized)))) {
    return true;
  }

  if (/\b(medication|medicine|meds?|pill(?:s)?|tablet(?:s)?|drug(?:s)?)\b/i.test(normalized)) {
    return true;
  }

  if (extractMedicationTypes(normalized).length > 0) {
    return true;
  }

  return /\b(?:taking|take|using|use|prescribed)\b/i.test(normalized)
    && /\b(medication|medicine|meds?|pill(?:s)?|tablet(?:s)?|drug(?:s)?|birth\s*control|contracept(?:ive|ion|ives?)|hormonal\s+medication|pain\s+relief|antidepressants?|anti-?anxiety|ssri|ibuprofen|paracetamol|acetaminophen|naproxen)\b/i.test(normalized);
}

function cleanMedicationCandidate(candidate) {
  const cleaned = normalizeText(candidate)
    .replace(/[.?!,;:]+$/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  if (!cleaned) {
    return null;
  }

  const lowered = cleaned.toLowerCase();
  if (GENERIC_TYPE_WORDS.has(lowered) || GENERIC_NON_MED_WORDS.has(lowered)) {
    return null;
  }

  return cleaned;
}

function extractMedicationTypes(message) {
  const normalized = message.trim();
  if (!normalized) {
    return [];
  }

  const detected = [];

  for (const item of TYPE_PATTERNS) {
    if (item.patterns.some((pattern) => pattern.test(normalized))) {
      detected.push(item.value);
    }
  }

  const phrasePatterns = [
    /\b(?:taking|take|using|use|on|prescribed)\s+(?:an?\s+|the\s+)?([A-Za-z][A-Za-z0-9'-]*(?:\s+[A-Za-z][A-Za-z0-9'-]*){0,3})(?=\s+(?:for|because|to|when|since|after|while)\b|[.,;!?]|$)/i,
    /\bmedication\s+is\s+([A-Za-z][A-Za-z0-9'-]*(?:\s+[A-Za-z][A-Za-z0-9'-]*){0,3})(?=\s+(?:for|because|to|when|since|after|while)\b|[.,;!?]|$)/i,
    /\bmedication\s+of\s+([A-Za-z][A-Za-z0-9'-]*(?:\s+[A-Za-z][A-Za-z0-9'-]*){0,3})(?=\s+(?:for|because|to|when|since|after|while)\b|[.,;!?]|$)/i,
  ];

  for (const pattern of phrasePatterns) {
    const match = pattern.exec(normalized);
    const candidate = cleanMedicationCandidate(match?.[1]);
    if (!candidate) {
      continue;
    }

    detected.push(candidate);
    break;
  }

  return [...new Set(detected.filter((item) => item.trim().length > 0))];
}

function getExistingMedicationType(answers) {
  if (!answers || typeof answers !== 'object' || Array.isArray(answers)) {
    return null;
  }

  const keys = ['medication_type', 'taking_any_medication_type'];
  for (const key of keys) {
    const value = normalizeText(answers[key]);
    if (value) {
      return value;
    }
  }

  return null;
}

function getMedicationNote(message) {
  const normalized = normalizeText(message).replace(/\s+/g, ' ');
  return normalized.length > 0 ? normalized.slice(0, 200) : '';
}

function containsNegation(message) {
  const normalized = message.trim().toLowerCase();
  return /\b(no|not|none|don't|do not|never|stop|stopped|quit|quitted)\b/i.test(normalized);
}

function buildUpdatedAnswers(existingAnswers, medicationTypes, medicationNote, message) {
  const isNegation = containsNegation(message);
  const status = isNegation ? 'no' : 'yes';

  const nextAnswers = {
    ...(existingAnswers ?? {}),
    medication_currently_taking: status,
    taking_any_medication: status,
  };

  if (isNegation) {
    nextAnswers.medication_type = '';
    nextAnswers.taking_any_medication_type = '';
    nextAnswers.medication_recent_changes = '';
    nextAnswers.recent_medication_changes = '';
  } else {
    if (medicationTypes.length > 0) {
      const joinedTypes = medicationTypes.join(', ');
      nextAnswers.medication_type = joinedTypes;
      nextAnswers.taking_any_medication_type = joinedTypes;
    }

    if (medicationNote) {
      nextAnswers.medication_recent_changes = medicationNote;
      nextAnswers.recent_medication_changes = medicationNote;
    }
  }

  return nextAnswers;
}

async function upsertMedicationFromChatMessage({ userId, message }) {
  if (!userId || typeof message !== 'string' || message.trim().length === 0) {
    return {
      updated: false,
      reason: 'invalid-input',
      needsFollowUp: false,
    };
  }

  if (!containsMedicationContext(message)) {
    return {
      updated: false,
      reason: 'no-medication-detected',
      needsFollowUp: false,
    };
  }

  const isNegation = containsNegation(message);
  const medicationTypes = isNegation ? [] : extractMedicationTypes(message);
  const medicationNote = isNegation ? '' : getMedicationNote(message);
  const onboarding = await userRepository.getOnboardingAnswers(userId);
  const existingAnswers = onboarding?.onboardingAnswers ?? {};
  const existingType = getExistingMedicationType(existingAnswers);
  const nextAnswers = buildUpdatedAnswers(existingAnswers, medicationTypes, medicationNote, message);

  if (!nextAnswers.medication_type && existingType && !isNegation) {
    nextAnswers.medication_type = existingType;
    nextAnswers.taking_any_medication_type = existingType;
  }

  // Check if any medication fields actually changed
  const medicationKeys = [
    'medication_currently_taking',
    'taking_any_medication',
    'medication_type',
    'taking_any_medication_type',
    'medication_recent_changes',
    'recent_medication_changes',
  ];
  const changedKeys = medicationKeys.filter((key) => existingAnswers[key] !== nextAnswers[key]);

  if (changedKeys.length === 0) {
    return {
      updated: false,
      reason: 'no-new-data',
      needsFollowUp: false,
    };
  }

  const updatedUser = await userRepository.updateOnboardingAnswers(userId, nextAnswers);
  const hasMedicationType = medicationTypes.length > 0 || Boolean(existingType);
  const savedAnswers = updatedUser?.onboardingAnswers ?? nextAnswers;

  return {
    updated: Boolean(updatedUser),
    reason: updatedUser ? 'updated' : 'update-failed',
    needsFollowUp: !isNegation && !hasMedicationType,
    followUpQuestion: (!isNegation && !hasMedicationType) ? FOLLOW_UP_QUESTION : null,
    medicationCurrentlyTaking: savedAnswers.medication_currently_taking ?? 'no',
    medicationType: savedAnswers.medication_type ?? savedAnswers.taking_any_medication_type ?? null,
    medicationNote: savedAnswers.medication_recent_changes
      ?? savedAnswers.recent_medication_changes
      ?? medicationNote
      ?? null,
    source: 'ai-chat',
  };
}

export const medicationFromChatService = {
  upsertMedicationFromChatMessage,
};
