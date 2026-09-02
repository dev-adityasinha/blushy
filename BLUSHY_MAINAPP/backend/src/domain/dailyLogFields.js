/**
 * Normalises one day's check-in answers before they are stored.
 *
 * Pulled out of the write so it can be asserted on directly: both bugs it
 * used to carry were silent. A number sent as `energyLevel` was dropped and
 * the request still answered 200, and `sleepHours` was rounded to whole
 * hours, so 7.5 came back as 8 -- a figure nobody had entered.
 */
export function sanitizeDailyLogFields(data = {}) {
  const mood = typeof data.mood === 'string' ? data.mood.slice(0, 50) : null;

  // Numbers are kept, not dropped. This accepted a string and nothing else,
  // so a client sending `energyLevel: 7` got a 200 and a stored null. The app
  // sends labels ("Low", "Balanced"), which is why it went unnoticed.
  const rawEnergy = data.energyLevel ?? data.energy_level;
  const energyLevel = typeof rawEnergy === 'string'
    ? rawEnergy.slice(0, 50)
    : (typeof rawEnergy === 'number' && Number.isFinite(rawEnergy)
        ? String(rawEnergy)
        : null);

  // Half hours survive. Sleep is logged in halves more often than not, so
  // rounding to whole hours was quietly wrong most of the time.
  const rawSleep = typeof data.sleepHours === 'number'
    ? data.sleepHours
    : (typeof data.sleep_hours === 'number' ? data.sleep_hours : null);
  const sleepHours = rawSleep === null || !Number.isFinite(rawSleep)
    ? null
    : Math.max(0, Math.min(24, Math.round(rawSleep * 2) / 2));

  const symptoms = Array.isArray(data.symptoms)
    ? data.symptoms
        .filter((s) => typeof s === 'string' && s.trim().length > 0)
        .map((s) => s.trim().slice(0, 50))
        .slice(0, 20)
    : [];
  const notes = typeof data.notes === 'string' ? data.notes.slice(0, 500) : null;
  const source = typeof data.source === 'string' ? data.source.slice(0, 50) : 'manual_checkin';

  return { mood, energyLevel, sleepHours, symptoms, notes, source };
}
