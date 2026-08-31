import { aiFetch } from '../utils/aiRequest.js';
import { env } from '../utils/env.js';
import { logger } from '../utils/logger.js';

/**
 * Turns what she answered at signup into how the app should behave for her.
 *
 * Two hard rules, because this runs unattended over health answers:
 *
 *  1. **The model may only choose, never invent.** Its output is intersected
 *     with `FOCUS_AREAS` below and anything else is dropped. It cannot name a
 *     focus the app has no support for, and it cannot introduce a condition
 *     she did not report.
 *  2. **It may not give guidance.** The summary is one neutral sentence about
 *     what the app will show her. Anything about what a symptom *means* is
 *     clinical content and belongs to the reviewed pipeline.
 *
 * If the model is unavailable, malformed, or off-list, the rule-based
 * derivation is used instead. It is not a degraded mode -- it is the floor,
 * and the model only ever reorders what the rules already allow.
 */

/** The only focus areas the app can actually act on. */
export const FOCUS_AREAS = Object.freeze([
  'cycle',
  'symptoms',
  'mood',
  'sleep',
  'energy',
  'nutrition',
  'movement',
  'fertility',
  'pregnancy',
  'recovery',
  'menopause',
  'medication',
]);

/** Which answers imply which focus. Substring matched against her answers. */
const RULES = Object.freeze({
  cycle: ['period', 'cycle', 'flow', 'spotting', 'irregular', 'bleeding'],
  symptoms: ['cramps', 'pain', 'bloating', 'acne', 'headache', 'discharge', 'swelling'],
  mood: ['mood', 'anxiety', 'stress', 'pms', 'mental health'],
  sleep: ['sleep', 'insomnia', 'night sweats', 'fatigue'],
  energy: ['energy', 'fatigue', 'brain fog'],
  nutrition: ['nutrition', 'weight', 'digestion', 'metabolism'],
  movement: ['exercise', 'walk', 'movement', 'fitness', 'strength', 'pelvic floor'],
  fertility: ['ovulation', 'fertility', 'conceive', 'bbt', 'cervical mucus', 'trying'],
  pregnancy: ['pregnan', 'due date', 'baby movement', 'kick'],
  recovery: ['postpartum', 'lochia', 'stitches', 'incision', 'perineal', 'feeding', 'healing'],
  menopause: ['menopause', 'hot flashes', 'hrt', 'vaginal dryness', 'bone', 'joint'],
  medication: ['medication', 'treatment', 'hrt', 'pill', 'iud', 'ivf', 'iui'],
});

/** Every answer value she gave, lowercased, as one searchable list. */
function answerText(answers) {
  const out = [];
  for (const [key, value] of Object.entries(answers ?? {})) {
    if (key.startsWith('log_') || key.startsWith('daily_')) continue;
    if (value == null) continue;
    if (Array.isArray(value)) out.push(...value.map((v) => String(v).toLowerCase()));
    else out.push(String(value).toLowerCase());
  }
  return out;
}

/**
 * What the rules alone conclude. Deterministic, and the ceiling on what the
 * model is allowed to return.
 */
export function deriveFocusAreas(answers) {
  const text = answerText(answers).join(' | ');
  return FOCUS_AREAS.filter((area) =>
    RULES[area].some((needle) => text.includes(needle)),
  );
}

/**
 * Keeps only focus areas the rules already permit, in the model's order.
 *
 * The model reprioritises; it cannot add. An area she gave no basis for stays
 * out however confidently it was returned.
 */
export function reconcileFocusAreas(modelAreas, allowedAreas) {
  const allowed = new Set(allowedAreas);
  const seen = new Set();
  const ordered = [];

  for (const raw of Array.isArray(modelAreas) ? modelAreas : []) {
    const area = String(raw ?? '').trim().toLowerCase();
    if (!allowed.has(area) || seen.has(area)) continue;
    seen.add(area);
    ordered.push(area);
  }

  // Anything the rules found and the model omitted still belongs to her.
  for (const area of allowedAreas) {
    if (!seen.has(area)) ordered.push(area);
  }

  return ordered;
}

function ruleSummary(areas) {
  if (areas.length === 0) {
    return 'Your home page will fill in as you log.';
  }
  const named = areas.slice(0, 3).join(', ');
  return `Your home page is set up around ${named}.`;
}

/**
 * Analyses one user's onboarding answers.
 *
 * Never throws: this runs as a side effect of finishing signup, and a failure
 * here must not be able to break onboarding.
 */
export async function analyseOnboarding(answers, { signal } = {}) {
  const allowed = deriveFocusAreas(answers);
  const fallback = {
    focusAreas: allowed,
    summary: ruleSummary(allowed),
    source: 'rules',
  };

  if (!env.aiChatApiKey || allowed.length === 0) return fallback;

  try {
    const response = await aiFetch(env.aiChatApiUrl, {
      method: 'POST',
      signal,
      headers: {
        Authorization: `Bearer ${env.aiChatApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: env.aiChatModel,
        messages: [
          {
            role: 'system',
            content:
              'You order a health app home page. Reply with JSON only: ' +
              '{"focus_areas":[...],"summary":"one sentence"}. ' +
              `Choose focus_areas ONLY from this list, most important first: ${allowed.join(', ')}. ` +
              'Do not invent areas. Do not give health advice, do not interpret ' +
              'symptoms, and do not mention conditions. The summary states only ' +
              'what the app will show her.',
          },
          { role: 'user', content: answerText(answers).join(', ') },
        ],
        max_tokens: 220,
        temperature: 0.2,
      }),
    });

    if (!response?.ok) return fallback;

    const payload = await response.json();
    const raw = payload?.choices?.[0]?.message?.content ?? '';
    const match = String(raw).match(/\{[\s\S]*\}/);
    if (!match) return fallback;

    const parsed = JSON.parse(match[0]);
    const focusAreas = reconcileFocusAreas(parsed.focus_areas, allowed);
    const summary =
      typeof parsed.summary === 'string' && parsed.summary.trim().length > 0
        ? parsed.summary.trim().slice(0, 200)
        : ruleSummary(focusAreas);

    return { focusAreas, summary, source: 'ai' };
  } catch (error) {
    logger.warn(`Onboarding analysis fell back to rules: ${error.message}`);
    return fallback;
  }
}
