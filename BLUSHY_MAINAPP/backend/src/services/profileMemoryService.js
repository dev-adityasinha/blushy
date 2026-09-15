const CONSENT_PATTERNS = [
  /\bsave\s+this\b/i,
  /\bremember\s+this\b/i,
  /\bstore\s+my\s+profile\b/i,
  /\bkeep\s+this\s+data\b/i,
  /\byou\s+can\s+save\s+it\b/i,
  /\badd\s+this\s+to\s+memory\b/i,
  /\bupdate\s+my\s+profile\b/i,
];

const SENSITIVE_PATTERNS = [
  /\b(?:otp|one\s*time\s*password|password|passcode)\b/i,
  /\b(?:aadhaar|aadhar|pan\s*card|credit\s*card|debit\s*card|bank\s*account|ifsc)\b/i,
];

function normalizeText(input) {
  if (Array.isArray(input)) {
    return input
      .filter((item) => typeof item === 'string' && item.trim().length > 0)
      .join(' ')
      .trim();
  }

  if (typeof input === 'string') {
    return input.trim();
  }

  return '';
}

function hasExplicitConsent(text) {
  return CONSENT_PATTERNS.some((pattern) => pattern.test(text));
}

function containsSensitiveInfo(text) {
  return SENSITIVE_PATTERNS.some((pattern) => pattern.test(text));
}

function cleanValue(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function pickMatch(text, patterns) {
  for (const pattern of patterns) {
    const match = pattern.exec(text);
    if (match?.[1]) {
      const value = cleanValue(match[1]);
      if (value) {
        return value;
      }
    }
  }
  return null;
}

function parseListFromSegment(segment) {
  if (!segment || typeof segment !== 'string') {
    return [];
  }

  return segment
    .split(/,|\band\b/gi)
    .map((item) => item.trim())
    .filter((item) => item.length > 0)
    .filter((item, index, all) => all.findIndex((v) => v.toLowerCase() === item.toLowerCase()) === index);
}

function removeUndefinedDeep(value) {
  if (Array.isArray(value)) {
    const items = value
      .map(removeUndefinedDeep)
      .filter((item) => item !== undefined);
    return items.length > 0 ? items : undefined;
  }

  if (value && typeof value === 'object') {
    const next = {};
    for (const [key, val] of Object.entries(value)) {
      const cleaned = removeUndefinedDeep(val);
      if (cleaned !== undefined) {
        next[key] = cleaned;
      }
    }

    return Object.keys(next).length > 0 ? next : undefined;
  }

  if (value === null || value === '') {
    return undefined;
  }

  return value;
}

function extractProfile(text) {
  const fullName = pickMatch(text, [
    /\bmy\s+full\s+name\s+is\s+([A-Za-z][A-Za-z\s.'-]{1,60})\b/i,
    /\bmy\s+name\s+is\s+([A-Za-z][A-Za-z\s.'-]{1,60})\b/i,
  ]);

  const preferredName = pickMatch(text, [
    /\bcall\s+me\s+([A-Za-z][A-Za-z\s.'-]{1,60})\b/i,
    /\bpreferred\s+name\s*(?:is|:)\s*([A-Za-z][A-Za-z\s.'-]{1,60})\b/i,
  ]);

  const city = pickMatch(text, [
    /\bI\s+live\s+in\s+([A-Za-z][A-Za-z\s.'-]{1,60})\b/i,
    /\bmy\s+city\s*(?:is|:)\s*([A-Za-z][A-Za-z\s.'-]{1,60})\b/i,
  ]);

  const state = pickMatch(text, [
    /\bmy\s+state\s*(?:is|:)\s*([A-Za-z][A-Za-z\s.'-]{1,60})\b/i,
  ]);

  const country = pickMatch(text, [
    /\bmy\s+country\s*(?:is|:)\s*([A-Za-z][A-Za-z\s.'-]{1,60})\b/i,
    /\bI\s+am\s+from\s+([A-Za-z][A-Za-z\s.'-]{1,60})\b/i,
  ]);

  const languagesSegment = pickMatch(text, [
    /\bI\s+speak\s+([A-Za-z,\s]+)\b/i,
    /\blanguages\s*(?:are|:|=)\s*([A-Za-z,\s]+)\b/i,
  ]);

  const college = pickMatch(text, [
    /\bI\s+stud(?:y|ied)\s+at\s+([A-Za-z0-9&,.\s'-]{2,80})\b/i,
    /\bcollege\s*(?:is|:|=)\s*([A-Za-z0-9&,.\s'-]{2,80})\b/i,
  ]);

  const degree = pickMatch(text, [
    /\bdegree\s*(?:is|:|=)\s*([A-Za-z0-9&,.\s'-]{2,80})\b/i,
  ]);

  const year = pickMatch(text, [
    /\b(?:graduation\s+year|year)\s*(?:is|:|=)\s*(\d{4})\b/i,
  ]);

  const occupation = pickMatch(text, [
    /\bI\s+am\s+(?:a|an)\s+([A-Za-z][A-Za-z\s'-]{2,80})\b/i,
    /\boccupation\s*(?:is|:|=)\s*([A-Za-z][A-Za-z\s'-]{2,80})\b/i,
  ]);

  const experienceYears = pickMatch(text, [
    /\b(\d{1,2})\s+years?\s+of\s+experience\b/i,
    /\bexperience\s*(?:is|:|=)\s*(\d{1,2})\b/i,
  ]);

  const skillsSegment = pickMatch(text, [
    /\bskills\s*(?:are|:|=)\s*([A-Za-z0-9,\s.+#-]{2,120})\b/i,
  ]);

  const favoriteColor = pickMatch(text, [
    /\bfavou?rite\s+color\s*(?:is|:|=)\s*([A-Za-z][A-Za-z\s-]{1,30})\b/i,
  ]);

  const favoriteFood = pickMatch(text, [
    /\bfavou?rite\s+food\s*(?:is|:|=)\s*([A-Za-z][A-Za-z\s-]{1,40})\b/i,
  ]);

  const hobbiesSegment = pickMatch(text, [
    /\bhobbies\s*(?:are|:|=)\s*([A-Za-z,\s'-]{2,120})\b/i,
    /\bI\s+love\s+([A-Za-z,\s'-]{2,120})\b/i,
  ]);

  const interestsSegment = pickMatch(text, [
    /\binterests\s*(?:are|:|=)\s*([A-Za-z,\s'-]{2,120})\b/i,
  ]);

  const shortTermSegment = pickMatch(text, [
    /\bshort\s*term\s+goals?\s*(?:are|:|=)\s*([A-Za-z0-9,\s'-]{2,180})\b/i,
  ]);

  const longTermSegment = pickMatch(text, [
    /\blong\s*term\s+goals?\s*(?:are|:|=)\s*([A-Za-z0-9,\s'-]{2,180})\b/i,
  ]);

  return removeUndefinedDeep({
    profile: {
      location: {
        country: country ?? undefined,
        state: state ?? undefined,
        city: city ?? undefined,
      },
      languages: parseListFromSegment(languagesSegment),
      education: {
        college: college ?? undefined,
        degree: degree ?? undefined,
        year: year ?? undefined,
      },
      professional: {
        occupation: occupation ?? undefined,
        skills: parseListFromSegment(skillsSegment),
        experience_years: experienceYears ?? undefined,
      },
      preferences: {
        favorite_color: favoriteColor ?? undefined,
        favorite_food: favoriteFood ?? undefined,
        hobbies: parseListFromSegment(hobbiesSegment),
        interests: parseListFromSegment(interestsSegment),
      },
      goals: {
        short_term: parseListFromSegment(shortTermSegment),
        long_term: parseListFromSegment(longTermSegment),
      },
    },
  });
}

function noConsentResponse() {
  return {
    store: false,
    reason: 'No explicit user consent',
  };
}

class ProfileMemoryService {
  analyzeConversation(input) {
    const text = normalizeText(input);

    if (!text || !hasExplicitConsent(text)) {
      return noConsentResponse();
    }

    if (containsSensitiveInfo(text)) {
      return noConsentResponse();
    }

    const extracted = extractProfile(text);
    const profileData = {
      ...(extracted ?? {}),
      consent_given: true,
    };

    return {
      store: true,
      profile_data: profileData,
    };
  }
}

export const profileMemoryService = new ProfileMemoryService();