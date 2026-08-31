/**
 * Notification categories, quiet hours and lock-screen privacy
 * (spec §19 "Notifications & Reminders", §24 "NOTIFICATIONS & REMINDERS").
 *
 * Every reminder has an underlying entity id so it can be cancelled when its
 * source event is deleted or a permission is revoked. Sensitive health content
 * is hidden from lock screen text by default.
 *
 * Pure module. Scheduling decisions are deterministic (spec §22).
 */

export const NOTIFICATION_ENGINE_VERSION = 'notifications-v1.0.0';

export const NOTIFICATION_CATEGORIES = Object.freeze({
  period_reminder: { key: 'period_reminder', label: 'Period reminders', sensitive: true, defaultEnabled: true, audience: 'female_user' },
  checkin_reminder: { key: 'checkin_reminder', label: 'Daily check-in', sensitive: false, defaultEnabled: true, audience: 'both' },
  symptom_followup: { key: 'symptom_followup', label: 'Symptom follow-ups', sensitive: true, defaultEnabled: true, audience: 'female_user' },
  pregnancy_milestone: { key: 'pregnancy_milestone', label: 'Pregnancy milestones', sensitive: true, defaultEnabled: true, audience: 'both' },
  postpartum_reminder: { key: 'postpartum_reminder', label: 'Postpartum reminders', sensitive: true, defaultEnabled: true, audience: 'both' },
  appointment_reminder: { key: 'appointment_reminder', label: 'Appointments', sensitive: true, defaultEnabled: true, audience: 'both' },
  ttc_checkin: { key: 'ttc_checkin', label: 'Fertility check-ins', sensitive: true, defaultEnabled: true, audience: 'female_user' },
  partner_support_request: { key: 'partner_support_request', label: 'Support requests', sensitive: false, defaultEnabled: true, audience: 'partner' },
  partner_shared_update: { key: 'partner_shared_update', label: 'Shared updates', sensitive: true, defaultEnabled: true, audience: 'partner' },
  // A partner asking to see something. Goes to whoever owns the permissions,
  // so the audience is both: either side of a connection can be the owner.
  partner_permission_request: { key: 'partner_permission_request', label: 'Sharing requests', sensitive: false, defaultEnabled: true, audience: 'both' },
  sia_proactive: { key: 'sia_proactive', label: 'Dr. Docsy check-ins', sensitive: false, defaultEnabled: true, audience: 'both' },
  community: { key: 'community', label: 'Community activity', sensitive: false, defaultEnabled: true, audience: 'both' },
  content_recommendation: { key: 'content_recommendation', label: 'New content', sensitive: false, defaultEnabled: false, audience: 'both' },
  safety_escalation: { key: 'safety_escalation', label: 'Safety notices', sensitive: true, defaultEnabled: true, audience: 'female_user', alwaysOn: true },
});

export const CATEGORY_KEYS = Object.freeze(Object.keys(NOTIFICATION_CATEGORIES));

export function defaultNotificationPreferences() {
  const categories = {};
  for (const key of CATEGORY_KEYS) {
    categories[key] = NOTIFICATION_CATEGORIES[key].defaultEnabled;
  }
  return {
    categories,
    quietHours: { enabled: false, start: '22:00', end: '07:00' },
    // Sensitive health content is hidden from the lock screen by default
    // (spec §19).
    hideSensitiveOnLockScreen: true,
    timezone: null,
  };
}

export function sanitizeNotificationPreferences(patch, current = defaultNotificationPreferences()) {
  const next = {
    categories: { ...current.categories },
    quietHours: { ...current.quietHours },
    hideSensitiveOnLockScreen: current.hideSensitiveOnLockScreen,
    timezone: current.timezone ?? null,
  };

  if (patch && typeof patch === 'object') {
    if (patch.categories && typeof patch.categories === 'object') {
      for (const [key, value] of Object.entries(patch.categories)) {
        const definition = NOTIFICATION_CATEGORIES[key];
        if (!definition) continue;
        // Safety notices cannot be switched off.
        if (definition.alwaysOn) continue;
        next.categories[key] = Boolean(value);
      }
    }
    if (patch.quietHours && typeof patch.quietHours === 'object') {
      if (typeof patch.quietHours.enabled === 'boolean') next.quietHours.enabled = patch.quietHours.enabled;
      if (isTimeOfDay(patch.quietHours.start)) next.quietHours.start = patch.quietHours.start;
      if (isTimeOfDay(patch.quietHours.end)) next.quietHours.end = patch.quietHours.end;
    }
    if (typeof patch.hideSensitiveOnLockScreen === 'boolean') {
      next.hideSensitiveOnLockScreen = patch.hideSensitiveOnLockScreen;
    }
    if (typeof patch.timezone === 'string' && patch.timezone.trim()) {
      try {
        Intl.DateTimeFormat(undefined, { timeZone: patch.timezone.trim() });
        next.timezone = patch.timezone.trim();
      } catch {
        // Invalid timezone is ignored rather than rejected outright.
      }
    }
  }

  // Always-on categories are forced true regardless of stored state.
  for (const key of CATEGORY_KEYS) {
    if (NOTIFICATION_CATEGORIES[key].alwaysOn) next.categories[key] = true;
  }

  return next;
}

export function isTimeOfDay(value) {
  return typeof value === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(value.trim());
}

function minutesOfDay(timeString) {
  const [h, m] = timeString.split(':').map(Number);
  return h * 60 + m;
}

function localMinutes(date, timezone) {
  try {
    const formatter = new Intl.DateTimeFormat('en-GB', {
      timeZone: timezone,
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    });
    const parts = formatter.format(date);
    return minutesOfDay(parts);
  } catch {
    return date.getUTCHours() * 60 + date.getUTCMinutes();
  }
}

/**
 * Quiet hours span midnight when `start` > `end` (for example 22:00 -> 07:00).
 */
export function isWithinQuietHours(date, quietHours, timezone) {
  if (!quietHours?.enabled) return false;
  if (!isTimeOfDay(quietHours.start) || !isTimeOfDay(quietHours.end)) return false;

  const now = localMinutes(date, timezone ?? 'UTC');
  const start = minutesOfDay(quietHours.start);
  const end = minutesOfDay(quietHours.end);

  if (start === end) return false;
  if (start < end) return now >= start && now < end;
  return now >= start || now < end;
}

/**
 * Decides whether a notification may be delivered now, and what text the lock
 * screen is allowed to show.
 *
 * @returns {{ deliver: boolean, reason: string, deferUntilQuietHoursEnd: boolean, lockScreenTitle: string, lockScreenBody: string|null }}
 */
export function evaluateDelivery({
  category,
  preferences = defaultNotificationPreferences(),
  title,
  body,
  now = new Date(),
} = {}) {
  const definition = NOTIFICATION_CATEGORIES[category];
  if (!definition) {
    return { deliver: false, reason: 'unknown_category', deferUntilQuietHoursEnd: false, lockScreenTitle: null, lockScreenBody: null };
  }

  const enabled = definition.alwaysOn || preferences.categories?.[category] !== false;
  if (!enabled) {
    return { deliver: false, reason: 'category_disabled', deferUntilQuietHoursEnd: false, lockScreenTitle: null, lockScreenBody: null };
  }

  // Safety escalations bypass quiet hours; nothing else does.
  const quiet = isWithinQuietHours(now, preferences.quietHours, preferences.timezone);
  if (quiet && !definition.alwaysOn) {
    return { deliver: false, reason: 'quiet_hours', deferUntilQuietHoursEnd: true, lockScreenTitle: null, lockScreenBody: null };
  }

  const hideSensitive = preferences.hideSensitiveOnLockScreen !== false;
  const redact = definition.sensitive && hideSensitive;

  return {
    deliver: true,
    reason: 'ok',
    deferUntilQuietHoursEnd: false,
    lockScreenTitle: redact ? 'Blushy' : (title ?? 'Blushy'),
    lockScreenBody: redact ? 'You have a new update. Open Blushy to view it.' : (body ?? null),
  };
}

/**
 * Proactive Dr. Docsy rate limit (spec §20: "Rate limit proactive Dr. Docsy so it does not
 * become notification spam").
 */
export const PROACTIVE_SIA_LIMITS = Object.freeze({
  maxPerDay: 1,
  maxPerWeek: 3,
  minHoursBetween: 20,
});

export function canSendProactiveSia(recentSendTimestamps = [], now = new Date()) {
  const times = recentSendTimestamps
    .map((t) => new Date(t).getTime())
    .filter((t) => Number.isFinite(t))
    .sort((a, b) => b - a);

  if (times.length === 0) return { allowed: true, reason: 'no_recent_sends' };

  const hoursSinceLast = (now.getTime() - times[0]) / 3600000;
  if (hoursSinceLast < PROACTIVE_SIA_LIMITS.minHoursBetween) {
    return { allowed: false, reason: 'min_interval_not_met', hoursSinceLast: Math.round(hoursSinceLast * 10) / 10 };
  }

  const dayAgo = now.getTime() - 86400000;
  if (times.filter((t) => t >= dayAgo).length >= PROACTIVE_SIA_LIMITS.maxPerDay) {
    return { allowed: false, reason: 'daily_limit_reached' };
  }

  const weekAgo = now.getTime() - 7 * 86400000;
  if (times.filter((t) => t >= weekAgo).length >= PROACTIVE_SIA_LIMITS.maxPerWeek) {
    return { allowed: false, reason: 'weekly_limit_reached' };
  }

  return { allowed: true, reason: 'within_limits' };
}
