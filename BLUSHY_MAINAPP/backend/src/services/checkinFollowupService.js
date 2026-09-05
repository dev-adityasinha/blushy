/**
 * Docsy writes the day's check-in cards from what was logged.
 *
 * The check-in used to come from a fixed rule table: fatigue asked about
 * sleep, cramps about movement. Docsy now chooses and phrases the questions
 * for the symptoms actually logged today, in her own voice. What the table
 * guaranteed still holds, and is enforced here rather than asked of the
 * model: every card is a yes/no question about one of a fixed set of
 * metrics, its two answers are values that metric already stores, and a
 * card never states a finding about the symptom that produced it. A reply
 * that breaks any of that is dropped card by card; a reply that cannot be
 * read at all yields no cards, and the app falls back to its rule table.
 */
import { createHttpError } from '../utils/httpError.js';
import { env } from '../utils/env.js';
import { aiFetch } from '../utils/aiRequest.js';
import { logger } from '../utils/logger.js';

/** The metrics a card may ask about, and the answers each may carry. */
export const FOLLOWUP_METRICS = Object.freeze({
  sleep: ['<6h', '6-8h', '>8h', '7-8h'],
  water: ['1L', '2L', '3L'],
  exercise: ['Active', 'Light', 'None'],
  stress: ['Low', 'Moderate', 'High'],
  energy: ['High', 'Medium', 'Low'],
  mood: ['Happy', 'Okay', 'Calm', 'Low', 'Irritable'],
  pain: ['None', 'Mild', 'Severe'],
});

export const MAX_CARDS = 6;

const cache = new Map();

function normaliseSymptoms(symptoms) {
  const out = [];
  for (const raw of Array.isArray(symptoms) ? symptoms : []) {
    const s = String(raw ?? '').trim();
    if (!s || s.length > 60) continue;
    const lower = s.toLowerCase();
    if (out.some((x) => x.toLowerCase() === lower)) continue;
    out.push(s);
    if (out.length >= 20) break;
  }
  return out;
}

export function cacheKeyFor(userId, date, symptoms) {
  return `${userId}|${date}|${normaliseSymptoms(symptoms).map((s) => s.toLowerCase()).sort().join(',')}`;
}

function buildPrompt(symptoms, stage) {
  const metrics = Object.entries(FOLLOWUP_METRICS)
    .map(([m, values]) => `- ${m}: ${values.join(' | ')}`)
    .join('\n');
  return `A woman logged these symptoms today: ${symptoms.join(', ')}.` +
    (stage ? ` Her life stage: ${stage}.` : '') + `

Write up to ${MAX_CARDS} short yes/no check-in questions that help her log the lifestyle metrics most likely to relate to what she logged. Rules:
- Each question is about exactly one metric from this list, and its "yes" and "no" answers must be two different values from that metric's allowed values:
${metrics}
- One question per metric at most.
- A question asks about her day; it never states a cause, a diagnosis or a finding about her symptoms.
- Plain, warm, under 12 words. No medical advice.
- "becauseOf" lists which of her logged symptoms the question relates to (use her exact words).

Return ONLY a JSON array, no prose, no markdown, of objects:
{"metric": "sleep", "question": "Did you sleep at least 7 hours?", "yesValue": "7-8h", "noValue": "<6h", "becauseOf": ["Fatigue"]}`;
}

/** Keeps only cards that respect the contract; never throws. */
export function validateCards(raw, symptoms) {
  const list = Array.isArray(raw) ? raw : (raw && Array.isArray(raw.cards) ? raw.cards : []);
  const lowerSymptoms = normaliseSymptoms(symptoms).map((s) => s.toLowerCase());
  const seen = new Set();
  const out = [];
  for (const item of list) {
    if (!item || typeof item !== 'object') continue;
    const metric = String(item.metric ?? '').trim().toLowerCase();
    const allowed = FOLLOWUP_METRICS[metric];
    if (!allowed || seen.has(metric)) continue;
    const question = String(item.question ?? '').trim();
    if (question.length < 8 || question.length > 120 || !question.endsWith('?')) continue;
    const yes = String(item.yesValue ?? '').trim();
    const no = String(item.noValue ?? '').trim();
    if (!allowed.includes(yes) || !allowed.includes(no) || yes === no) continue;
    const because = (Array.isArray(item.becauseOf) ? item.becauseOf : [])
      .map((b) => String(b ?? '').trim())
      .filter((b) => b && lowerSymptoms.includes(b.toLowerCase()))
      .slice(0, 4);
    seen.add(metric);
    out.push({
      id: `ai_${metric}`,
      metric,
      question,
      yesValue: yes,
      noValue: no,
      becauseOf: because,
    });
    if (out.length >= MAX_CARDS) break;
  }
  return out;
}

function parseModelJson(text) {
  let body = String(text ?? '').trim();
  const fence = body.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) body = fence[1].trim();
  const start = body.indexOf('[');
  const end = body.lastIndexOf(']');
  if (start !== -1 && end > start) body = body.slice(start, end + 1);
  return JSON.parse(body);
}

/**
 * Cards for the day. `{ cards, source }` where source is 'docsy' when the
 * model wrote them and 'none' when it could not, so the app knows to use
 * its own rules.
 */
export async function generateCheckinFollowUps({ userId, date, symptoms, stage = null }) {
  const clean = normaliseSymptoms(symptoms);
  if (clean.length === 0) return { cards: [], source: 'none', reason: 'nothing_logged' };
  if (!env.aiChatApiKey) throw createHttpError(503, 'Docsy is not configured. Add GROK_API_KEY in backend .env');

  const key = cacheKeyFor(userId, date, clean);
  const cached = cache.get(key);
  if (cached && cached.expires > Date.now()) return cached.value;

  let response;
  try {
    response = await aiFetch(env.aiChatApiUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.aiChatApiKey}`,
        'Content-Type': 'application/json',
        'X-Title': 'Blushy Check-in',
      },
      body: JSON.stringify({
        model: env.aiChatModel,
        messages: [
          { role: 'system', content: 'You are Docsy, a warm women\'s health companion. Return ONLY valid JSON.' },
          { role: 'user', content: buildPrompt(clean, stage) },
        ],
        max_tokens: 900,
        temperature: 0.4,
      }),
    });
  } catch (error) {
    logger.warn('Check-in follow-ups: model unreachable', { message: error?.message });
    return { cards: [], source: 'none', reason: 'unreachable' };
  }

  let payload;
  try {
    payload = await response.json();
  } catch (_) {
    return { cards: [], source: 'none', reason: 'bad_response' };
  }
  const content = payload?.choices?.[0]?.message?.content ?? '';
  let parsed;
  try {
    parsed = parseModelJson(content);
  } catch (_) {
    logger.warn('Check-in follow-ups: reply was not JSON', { head: String(content).slice(0, 120) });
    return { cards: [], source: 'none', reason: 'not_json' };
  }
  const cards = validateCards(parsed, clean);
  const value = { cards, source: cards.length ? 'docsy' : 'none', reason: cards.length ? null : 'no_valid_cards' };
  // Same symptoms, same day, same cards: they should not shuffle on every
  // open, and the model is not asked twice for the same thing.
  cache.set(key, { value, expires: Date.now() + 12 * 60 * 60 * 1000 });
  return value;
}

export function clearCheckinFollowupCache() {
  cache.clear();
}
