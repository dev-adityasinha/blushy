/**
 * What she logged, in words Docsy can read.
 *
 * Docsy's context carried her onboarding answers, her predictions, her
 * insights, her captures, her reports and her journal — and nothing at all
 * about the check-in and symptoms she fills in every day. So the one thing she
 * does daily was the one thing Docsy could not see, and asking "why am I so
 * tired this week" got an answer built from everything except this week.
 *
 * Two rules this file keeps:
 *
 *  1. **It restates, it does not conclude.** Every line is something she
 *     typed or tapped. Correlations and trends are the pattern engine's to
 *     compute (`patterns.js`, behind six paired observations), and Docsy may
 *     only phrase what that engine already decided. A summary that said "your
 *     fatigue is linked to poor sleep" would be the model inventing a finding.
 *
 *  2. **Absence is stated, never filled.** A day with nothing logged says so.
 *     The alternative is Docsy assuming a quiet day was a good one.
 */

/** Event types this summary knows how to read. */
const READERS = {
  symptom_logged: (p) => p.symptom,
  mood_logged: (p) => `mood ${p.mood}`,
  energy_logged: (p) => `energy ${p.level}/5`,
  sleep_logged: (p) => `slept ${p.durationHours}h`,
  stress_logged: (p) => `stress ${p.level}/5`,
  hydration_logged: (p) => `${p.glasses} glasses of water`,
  pain_logged: (p) => `pain ${p.severity}/10`,
  flow_logged: (p) => `${p.flow} flow`,
  activity_logged: (p) => p.activity,
  cervical_mucus_logged: (p) => `cervical mucus ${p.observation}`,
  lh_test_logged: (p) => `LH test ${p.result}`,
  bbt_logged: (p) => `BBT ${p.celsius}C`,
  weight_logged: (p) => `weight ${p.kg}kg`,
  hot_flash_logged: (p) =>
    `${p.nightSweat ? 'night sweat' : 'hot flash'} ${p.severity}/10`,
  feeding_logged: (p) => `feeding (${p.method})`,
  medication_logged: (p) => `${p.kind} ${p.taken ? 'taken' : 'not taken'}`,
  recovery_metric_logged: (p) => `${p.metric}: ${p.value}`,
  sexual_activity_logged: (p) => {
    const parts = [];
    if (p.activity && p.activity !== 'none') parts.push(String(p.activity).replace(/_/g, ' '));
    if (p.activity === 'none') parts.push('no sexual activity');
    if (p.drive) parts.push(`${p.drive} sex drive`);
    return parts.join(', ');
  },
  pregnancy_test_logged: (p) =>
    `pregnancy test ${String(p.result).replace(/_/g, ' ')}`,
};

function dayKey(timestamp) {
  const d = new Date(timestamp);
  return Number.isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10);
}

/**
 * Reads the consent she set on the symptoms sheet.
 *
 * Switching a category off stops it being collected from that moment, but it
 * does not reach back for what is already stored -- and the app says so rather
 * than implying an erasure. What it must also do is stop feeding those
 * readings to Docsy: a category she has withdrawn should not keep shaping what
 * the assistant says about her, whatever the database still holds.
 *
 * The lists are derived on the device, from the one registry that knows which
 * options belong to which category. Deriving them again here would be a second
 * copy of that mapping, and the two would drift.
 */
export function parseSymptomConsent(onboardingAnswers = {}) {
  const read = (key) => {
    const raw = onboardingAnswers?.[key];
    if (Array.isArray(raw)) return raw.map((v) => String(v).toLowerCase());
    if (typeof raw !== 'string' || raw.trim().length === 0) return [];
    try {
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed.map((v) => String(v).toLowerCase()) : [];
    } catch (_) {
      // A malformed value filters nothing rather than everything: failing
      // closed here would silently blank the context for every user whose
      // record predates this field.
      return [];
    }
  };

  return {
    excludedEventTypes: new Set(read('symptom_consent_excluded_event_types')),
    excludedSymptoms: new Set(read('symptom_consent_excluded_symptoms')),
  };
}

/**
 * A short, factual account of the last few days of logging.
 *
 * @param {Array}  events               stored health events, any order
 * @param {Date}   referenceDate        what "today" means
 * @param {number} days                 how far back to read
 * @param {Set}    excludedEventTypes   whole types she has switched off
 * @param {Set}    excludedSymptoms     symptom names from switched-off groups
 * @returns {string} empty when nothing in the window was logged
 */
export function buildDailyLogSummary(events = [], {
  referenceDate = new Date(),
  days = 7,
  excludedEventTypes = new Set(),
  excludedSymptoms = new Set(),
} = {}) {
  if (!Array.isArray(events) || events.length === 0) return '';

  const end = referenceDate instanceof Date ? referenceDate : new Date(referenceDate);
  const start = new Date(end.getTime() - days * 86400000);

  const byDay = new Map();
  for (const event of events) {
    if (event?.deletedAt) continue;
    // The model's own extractions are not evidence about her day: letting them
    // back in would have Docsy reading its own earlier guesses as fact.
    if (event?.source === 'ai_derived') continue;

    const reader = READERS[event?.eventType];
    if (!reader) continue;

    // A category she has switched off takes no part in what Docsy is told.
    if (excludedEventTypes.has(event.eventType)) continue;
    if (event.eventType === 'symptom_logged') {
      const name = String(event?.payload?.symptom ?? '').toLowerCase().trim();
      // Several groups record as `symptom_logged` -- symptoms, digestion,
      // intimate health, hair, the abnormal discharge words -- so the type
      // alone cannot say which group an entry came from. Only the name can.
      if (excludedSymptoms.has(name)) continue;
    }

    const ts = new Date(event?.timestamp).getTime();
    if (!Number.isFinite(ts) || ts < start.getTime() || ts > end.getTime()) continue;

    const key = dayKey(event.timestamp);
    if (!key) continue;

    let phrase;
    try {
      phrase = reader(event.payload ?? {});
    } catch (_) {
      continue;
    }
    if (typeof phrase !== 'string' || phrase.trim().length === 0) continue;

    const bucket = byDay.get(key) ?? new Set();
    bucket.add(phrase.trim());
    byDay.set(key, bucket);
  }

  if (byDay.size === 0) return '';

  const todayKey = dayKey(end);
  const lines = [];
  for (const key of [...byDay.keys()].sort().reverse()) {
    const label = key === todayKey ? 'Today' : key;
    lines.push(`${label}: ${[...byDay.get(key)].join(', ')}`);
  }

  return `Recent daily logs (most recent first). These are her own entries, ` +
    `not conclusions: ${lines.join(' | ')}`;
}

/**
 * Whether today specifically has anything logged.
 *
 * Kept separate so Docsy can tell "she has not logged today" from "she logged
 * and everything was unremarkable" — two very different things to say back.
 */
export function hasLoggedToday(events = [], referenceDate = new Date()) {
  const today = dayKey(referenceDate instanceof Date ? referenceDate : new Date(referenceDate));
  return (Array.isArray(events) ? events : []).some(
    (e) => !e?.deletedAt && e?.source !== 'ai_derived' &&
      READERS[e?.eventType] && dayKey(e?.timestamp) === today,
  );
}
