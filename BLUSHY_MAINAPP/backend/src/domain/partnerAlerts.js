/**
 * Woman -> companions alerts ("Pad Squad" & "Pain Radar").
 *
 * The reverse direction of a companion nudge: the woman pings her circle for
 * help. Server-authoritative like nudges — the client sends only an `alertType`,
 * the delivered wording lives here, and no free text is accepted. These carry no
 * health data (just "she could use support"), so like care requests they need no
 * per-permission gate.
 *
 * Pure module: unit-testable without a database.
 */

const ALERTS = Object.freeze({
  need_pad: {
    id: 'need_pad',
    label: 'I need a pad',
    title: 'Pad Squad',
    message: '{name} needs a pad right now — can you help out? 🩹',
  },
  rough_day: {
    id: 'rough_day',
    label: 'Rough day',
    title: 'Care alert',
    message: '{name} is having a rough day — a little support would mean a lot. 💛',
  },
  pain_flare: {
    id: 'pain_flare',
    label: 'High pain',
    title: 'Care alert',
    message: '{name} is having a high-pain day and could use some care right now.',
  },
});

export const WOMAN_ALERT_IDS = Object.freeze(Object.keys(ALERTS));

/** The alerts a woman can broadcast (for the client UI). */
export function womanAlerts() {
  return Object.values(ALERTS).map((a) => ({ id: a.id, label: a.label }));
}

/** Resolve an alertId to its {title, message-template} entry, or null. */
export function resolveWomanAlert(alertId) {
  if (typeof alertId !== 'string' || !alertId) return null;
  return ALERTS[alertId] ?? null;
}

/** Fill the sender's name into an alert's message template. */
export function renderAlertMessage(alert, senderName) {
  const name = (senderName && senderName.trim()) ? senderName.trim() : 'Someone';
  return alert.message.replace('{name}', name);
}
