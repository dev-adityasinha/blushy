/**
 * Health event taxonomy and validation (spec §6 "Logging System",
 * §21 "Data Model Rules", and the "DATA SHOULD BE EVENT BASED" mapping).
 *
 * Every event carries: id, userId, eventType, timestamp, source, schemaVersion,
 * createdAt, updatedAt. Derived cards are calculated from these events, never
 * stored as the final number.
 *
 * Pure module: no database access, so validation is unit testable.
 */

export const EVENT_SCHEMA_VERSION = 1;

export const EVENT_SOURCES = Object.freeze(['manual', 'voice', 'imported', 'device', 'ai_derived']);

/**
 * `ai_derived` is never treated as user confirmed (spec §6).
 */
export function isUserConfirmedSource(source) {
  return source !== 'ai_derived';
}

const SEVERITY_SCALE = { min: 0, max: 10 };
const LEVEL_SCALE = { min: 1, max: 5 };

const MOODS = ['great', 'good', 'okay', 'low', 'awful', 'anxious', 'irritable', 'calm', 'sad', 'energised'];
const FLOWS = ['spotting', 'light', 'medium', 'heavy'];
const SLEEP_QUALITY = ['poor', 'fair', 'good', 'excellent'];
const CERVICAL_MUCUS = ['dry', 'sticky', 'creamy', 'watery', 'egg_white'];
const LH_RESULTS = ['negative', 'low', 'high', 'peak'];

function num(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function inRange(value, { min, max }) {
  const n = num(value);
  return n !== null && n >= min && n <= max;
}

function str(value, maxLength = 500) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, maxLength);
}

/**
 * The label the user actually chose, when the UI offers buckets rather than an
 * exact value ("6-8h", "Medium", "2L"). Kept alongside the derived number so a
 * bucketed answer is never displayed back as precise, and so the derivation
 * stays reproducible from the source event (spec section 21).
 */
function reportedAs(payload) {
  return str(payload?.reportedAs, 40);
}

function strArray(value, maxItems = 30, maxLength = 80) {
  if (!Array.isArray(value)) return null;
  const out = [];
  for (const item of value.slice(0, maxItems)) {
    const s = str(item, maxLength);
    if (s) out.push(s);
  }
  return out;
}

/**
 * Event registry. Each entry declares the payload validator and which derived
 * surfaces must be recalculated when an event of this type is written, edited
 * or deleted (spec: "User edits/deletes should trigger recalculation of
 * dependent derived data").
 */
export const EVENT_TYPES = Object.freeze({
  period_logged: {
    invalidates: ['cycle', 'patterns', 'timeline', 'care_plan', 'notifications'],
    validate(payload) {
      const startDate = str(payload.startDate ?? payload.periodStartDate);
      if (!startDate || !isCalendarDate(startDate)) {
        return { ok: false, error: 'startDate must be a YYYY-MM-DD calendar date.' };
      }
      const endDate = str(payload.endDate ?? payload.periodEndDate);
      if (endDate && !isCalendarDate(endDate)) {
        return { ok: false, error: 'endDate must be a YYYY-MM-DD calendar date.' };
      }
      if (endDate && endDate < startDate) {
        return { ok: false, error: 'endDate cannot be before startDate.' };
      }
      const flow = str(payload.flow ?? payload.flowIntensity);
      if (flow && !FLOWS.includes(flow)) {
        return { ok: false, error: `flow must be one of: ${FLOWS.join(', ')}.` };
      }
      return { ok: true, value: { startDate, endDate: endDate ?? null, flow: flow ?? null } };
    },
  },

  symptom_logged: {
    invalidates: ['patterns', 'timeline', 'care_plan', 'safety'],
    validate(payload) {
      const symptom = str(payload.symptom, 80);
      if (!symptom) return { ok: false, error: 'symptom is required.' };
      const severity = payload.severity === undefined || payload.severity === null ? null : num(payload.severity);
      if (severity !== null && !inRange(severity, SEVERITY_SCALE)) {
        return { ok: false, error: 'severity must be between 0 and 10.' };
      }
      return { ok: true, value: { symptom, severity, bodySite: str(payload.bodySite, 60) } };
    },
  },

  mood_logged: {
    invalidates: ['patterns', 'timeline', 'safety'],
    validate(payload) {
      const mood = str(payload.mood, 40)?.toLowerCase() ?? null;
      if (!mood) return { ok: false, error: 'mood is required.' };
      if (!MOODS.includes(mood)) {
        return { ok: false, error: `mood must be one of: ${MOODS.join(', ')}.` };
      }
      const intensity = payload.intensity === undefined || payload.intensity === null ? null : num(payload.intensity);
      if (intensity !== null && !inRange(intensity, LEVEL_SCALE)) {
        return { ok: false, error: 'intensity must be between 1 and 5.' };
      }
      return { ok: true, value: { mood, intensity, note: str(payload.note, 300) } };
    },
  },

  energy_logged: {
    invalidates: ['patterns', 'timeline', 'care_plan'],
    validate(payload) {
      const level = num(payload.level);
      if (!inRange(level, LEVEL_SCALE)) return { ok: false, error: 'level must be between 1 and 5.' };
      return { ok: true, value: { level, reportedAs: reportedAs(payload) } };
    },
  },

  recovery_session_completed: {
    // Recorded so a finished session reaches the timeline like any other
    // logged activity, rather than being counted only on the device.
    invalidates: ['timeline'],
    validate(payload) {
      const sessionId = str(payload.sessionId, 120);
      if (!sessionId) {
        return { ok: false, error: 'sessionId is required.' };
      }
      const secondsListened = num(payload.secondsListened ?? 0) ?? 0;
      if (secondsListened < 0 || secondsListened > 24 * 3600) {
        return { ok: false, error: 'secondsListened is out of range.' };
      }
      return {
        ok: true,
        value: {
          sessionId,
          title: str(payload.title, 200) ?? null,
          secondsListened: Math.round(secondsListened),
        },
      };
    },
  },

  sleep_logged: {
    invalidates: ['patterns', 'timeline', 'care_plan'],
    validate(payload) {
      const durationHours = num(payload.durationHours ?? payload.duration);
      if (durationHours === null || durationHours < 0 || durationHours > 24) {
        return { ok: false, error: 'durationHours must be between 0 and 24.' };
      }
      const quality = str(payload.quality, 20)?.toLowerCase() ?? null;
      if (quality && !SLEEP_QUALITY.includes(quality)) {
        return { ok: false, error: `quality must be one of: ${SLEEP_QUALITY.join(', ')}.` };
      }
      return { ok: true, value: { durationHours, quality, reportedAs: reportedAs(payload) } };
    },
  },

  hydration_logged: {
    invalidates: ['patterns', 'timeline'],
    validate(payload) {
      const glasses = num(payload.glasses ?? payload.amount);
      if (glasses === null || glasses < 0 || glasses > 40) {
        return { ok: false, error: 'glasses must be between 0 and 40.' };
      }
      return { ok: true, value: { glasses, reportedAs: reportedAs(payload) } };
    },
  },

  pain_logged: {
    invalidates: ['patterns', 'timeline', 'care_plan', 'safety'],
    validate(payload) {
      const severity = num(payload.severity);
      if (!inRange(severity, SEVERITY_SCALE)) return { ok: false, error: 'severity must be between 0 and 10.' };
      return { ok: true, value: { severity, location: str(payload.location, 60), type: str(payload.type, 40), reportedAs: reportedAs(payload) } };
    },
  },

  flow_logged: {
    // Spec section 5 tracks flow independently of symptoms, mood, energy and
    // pain, and separately from the period_logged start event.
    invalidates: ['patterns', 'timeline', 'cycle'],
    validate(payload) {
      const flow = str(payload.flow ?? payload.level, 20)?.toLowerCase() ?? null;
      if (!flow || !FLOWS.includes(flow)) {
        return { ok: false, error: `flow must be one of: ${FLOWS.join(', ')}.` };
      }
      return { ok: true, value: { flow, reportedAs: reportedAs(payload) } };
    },
  },

  journal_created: {
    // Journal text itself never reaches AI context or analytics without consent.
    invalidates: ['timeline'],
    validate(payload) {
      const text = str(payload.text, 20000);
      const audioRef = str(payload.audioRef, 300);
      if (!text && !audioRef) return { ok: false, error: 'journal requires text or audioRef.' };
      return {
        ok: true,
        value: {
          text,
          audioRef,
          audioDurationSeconds: num(payload.audioDurationSeconds),
          wordCount: text ? text.split(/\s+/).filter(Boolean).length : null,
        },
      };
    },
  },

  bbt_logged: {
    invalidates: ['fertility', 'patterns', 'timeline'],
    validate(payload) {
      const celsius = num(payload.celsius ?? payload.temperatureCelsius);
      if (celsius === null || celsius < 33 || celsius > 43) {
        return { ok: false, error: 'celsius must be between 33 and 43.' };
      }
      return { ok: true, value: { celsius } };
    },
  },

  lh_test_logged: {
    invalidates: ['fertility', 'timeline'],
    validate(payload) {
      const result = str(payload.result, 20)?.toLowerCase() ?? null;
      if (!result || !LH_RESULTS.includes(result)) {
        return { ok: false, error: `result must be one of: ${LH_RESULTS.join(', ')}.` };
      }
      return { ok: true, value: { result } };
    },
  },

  cervical_mucus_logged: {
    invalidates: ['fertility', 'timeline'],
    validate(payload) {
      const observation = str(payload.observation, 20)?.toLowerCase() ?? null;
      if (!observation || !CERVICAL_MUCUS.includes(observation)) {
        return { ok: false, error: `observation must be one of: ${CERVICAL_MUCUS.join(', ')}.` };
      }
      return { ok: true, value: { observation } };
    },
  },

  pregnancy_week_updated: {
    invalidates: ['pregnancy', 'timeline', 'care_plan', 'notifications'],
    validate(payload) {
      const dueDate = str(payload.dueDate);
      const lmpDate = str(payload.lmpDate);
      const week = payload.week === undefined || payload.week === null ? null : num(payload.week);
      if (!dueDate && !lmpDate && week === null) {
        return { ok: false, error: 'one of dueDate, lmpDate or week is required.' };
      }
      if (dueDate && !isCalendarDate(dueDate)) return { ok: false, error: 'dueDate must be YYYY-MM-DD.' };
      if (lmpDate && !isCalendarDate(lmpDate)) return { ok: false, error: 'lmpDate must be YYYY-MM-DD.' };
      if (week !== null && (week < 0 || week > 45)) return { ok: false, error: 'week must be between 0 and 45.' };
      return { ok: true, value: { dueDate: dueDate ?? null, lmpDate: lmpDate ?? null, week, dateSource: str(payload.dateSource, 40) ?? 'user_reported' } };
    },
  },

  pregnancy_ended: {
    invalidates: ['pregnancy', 'timeline', 'care_plan', 'notifications', 'partner_shared'],
    validate(payload) {
      const outcome = str(payload.outcome, 40);
      const allowed = ['birth', 'loss', 'termination', 'other', 'prefer_not_to_say'];
      if (!outcome || !allowed.includes(outcome)) {
        return { ok: false, error: `outcome must be one of: ${allowed.join(', ')}.` };
      }
      const endDate = str(payload.endDate);
      if (endDate && !isCalendarDate(endDate)) return { ok: false, error: 'endDate must be YYYY-MM-DD.' };
      return { ok: true, value: { outcome, endDate: endDate ?? null } };
    },
  },

  feeding_logged: {
    invalidates: ['timeline', 'patterns'],
    validate(payload) {
      const method = str(payload.method, 30)?.toLowerCase() ?? null;
      const allowed = ['breast', 'bottle', 'mixed', 'solids'];
      if (!method || !allowed.includes(method)) {
        return { ok: false, error: `method must be one of: ${allowed.join(', ')}.` };
      }
      return { ok: true, value: { method, durationMinutes: num(payload.durationMinutes), amountMl: num(payload.amountMl), side: str(payload.side, 10) } };
    },
  },

  recovery_metric_logged: {
    invalidates: ['timeline', 'patterns', 'care_plan'],
    validate(payload) {
      const metric = str(payload.metric, 60);
      if (!metric) return { ok: false, error: 'metric is required.' };
      const value = num(payload.value);
      if (value === null) return { ok: false, error: 'value must be numeric.' };
      return { ok: true, value: { metric, value, scale: str(payload.scale, 30) ?? 'self_reported' } };
    },
  },

  hot_flash_logged: {
    invalidates: ['patterns', 'timeline'],
    validate(payload) {
      const severity = num(payload.severity);
      if (!inRange(severity, SEVERITY_SCALE)) return { ok: false, error: 'severity must be between 0 and 10.' };
      return { ok: true, value: { severity, durationMinutes: num(payload.durationMinutes), nightSweat: Boolean(payload.nightSweat) } };
    },
  },

  stress_logged: {
    invalidates: ['patterns', 'timeline', 'care_plan'],
    validate(payload) {
      const level = num(payload.level);
      if (!inRange(level, LEVEL_SCALE)) return { ok: false, error: 'level must be between 1 and 5.' };
      return { ok: true, value: { level, reportedAs: reportedAs(payload) } };
    },
  },

  activity_logged: {
    invalidates: ['patterns', 'timeline'],
    validate(payload) {
      const activity = str(payload.activity, 60);
      if (!activity) return { ok: false, error: 'activity is required.' };
      return { ok: true, value: { activity, durationMinutes: num(payload.durationMinutes), intensity: str(payload.intensity, 20), reportedAs: reportedAs(payload) } };
    },
  },

  appointment_logged: {
    invalidates: ['timeline', 'notifications', 'partner_shared'],
    validate(payload) {
      const title = str(payload.title, 120);
      if (!title) return { ok: false, error: 'title is required.' };
      const date = str(payload.date);
      if (!date || !isCalendarDate(date)) return { ok: false, error: 'date must be YYYY-MM-DD.' };
      return { ok: true, value: { title, date, time: str(payload.time, 10), provider: str(payload.provider, 120), notes: str(payload.notes, 1000) } };
    },
  },

  life_scene_set: {
    // Temporary contexts such as travel, exams, new job, wedding (spec §20).
    invalidates: ['care_plan', 'home'],
    validate(payload) {
      const scene = str(payload.scene, 40)?.toLowerCase() ?? null;
      const allowed = ['travel', 'exams', 'new_job', 'wedding', 'moving', 'bereavement', 'illness', 'none'];
      if (!scene || !allowed.includes(scene)) {
        return { ok: false, error: `scene must be one of: ${allowed.join(', ')}.` };
      }
      const endsOn = str(payload.endsOn);
      if (endsOn && !isCalendarDate(endsOn)) return { ok: false, error: 'endsOn must be YYYY-MM-DD.' };
      return { ok: true, value: { scene, endsOn: endsOn ?? null } };
    },
  },

  condition_reported: {
    // Explicitly selected by the user - never inferred (spec §14 Hormonal Health).
    invalidates: ['care_plan', 'patterns', 'home'],
    validate(payload) {
      const conditions = strArray(payload.conditions, 20, 60);
      if (!conditions || conditions.length === 0) return { ok: false, error: 'conditions must be a non-empty array.' };
      return { ok: true, value: { conditions, diagnosedBy: str(payload.diagnosedBy, 60) ?? 'self_reported' } };
    },
  },
});

export const EVENT_TYPE_KEYS = Object.freeze(Object.keys(EVENT_TYPES));

export function isCalendarDate(value) {
  if (typeof value !== 'string') return false;
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value.trim());
  if (!match) return false;
  const y = Number(match[1]);
  const m = Number(match[2]);
  const d = Number(match[3]);
  if (m < 1 || m > 12 || d < 1 || d > 31) return false;
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
}

/**
 * Validates an incoming event and returns the canonical stored shape.
 * Returns { ok: true, event } or { ok: false, error, field }.
 */
export function validateEvent({ eventType, payload = {}, timestamp, source = 'manual', clientEventId = null }) {
  const definition = EVENT_TYPES[eventType];
  if (!definition) {
    return { ok: false, field: 'eventType', error: `Unknown eventType. Allowed: ${EVENT_TYPE_KEYS.join(', ')}.` };
  }

  if (!EVENT_SOURCES.includes(source)) {
    return { ok: false, field: 'source', error: `source must be one of: ${EVENT_SOURCES.join(', ')}.` };
  }

  const when = timestamp ? new Date(timestamp) : new Date();
  if (Number.isNaN(when.getTime())) {
    return { ok: false, field: 'timestamp', error: 'timestamp must be a valid ISO-8601 date-time.' };
  }

  // Future-dating guard (spec §24 "Future dated period"). One day of leeway
  // covers users ahead of UTC; anything beyond that is a correction flow.
  const maxFuture = Date.now() + 36 * 60 * 60 * 1000;
  if (when.getTime() > maxFuture) {
    return { ok: false, field: 'timestamp', error: 'timestamp cannot be more than 36 hours in the future.' };
  }

  const result = definition.validate(payload ?? {});
  if (!result.ok) {
    return { ok: false, field: 'payload', error: result.error };
  }

  return {
    ok: true,
    event: {
      eventType,
      timestamp: when.toISOString(),
      source,
      schemaVersion: EVENT_SCHEMA_VERSION,
      payload: result.value,
      clientEventId: typeof clientEventId === 'string' ? clientEventId.slice(0, 128) : null,
      userConfirmed: isUserConfirmedSource(source),
    },
  };
}

export function getInvalidationTargets(eventType) {
  return EVENT_TYPES[eventType]?.invalidates ?? [];
}

/**
 * Human-readable timeline text (spec §11 "TIMELINES"). Timeline is raw
 * chronological history - it never carries interpretation.
 */
export function describeEvent(event) {
  const p = event?.payload ?? {};
  switch (event?.eventType) {
    case 'period_logged': return `Period started${p.flow ? ` (${p.flow} flow)` : ''}`;
    case 'symptom_logged': return `Logged ${p.symptom}${p.severity !== null && p.severity !== undefined ? ` (severity ${p.severity}/10)` : ''}`;
    case 'mood_logged': return `Mood: ${p.mood}`;
    case 'energy_logged': return `Energy level ${p.level}/5`;
    case 'recovery_session_completed':
      return `Completed "${p.title ?? 'a recovery session'}"`;
    case 'sleep_logged': return `Slept ${p.durationHours}h${p.quality ? ` (${p.quality})` : ''}`;
    case 'hydration_logged': return `${p.glasses} glasses of water`;
    case 'pain_logged': return `Pain ${p.severity}/10${p.location ? ` in ${p.location}` : ''}`;
    case 'flow_logged': return `Flow: ${p.flow}`;
    case 'journal_created': return 'Journal entry';
    case 'bbt_logged': return `BBT ${p.celsius}°C`;
    case 'lh_test_logged': return `LH test: ${p.result}`;
    case 'cervical_mucus_logged': return `Cervical mucus: ${p.observation}`;
    case 'pregnancy_week_updated': return p.week !== null && p.week !== undefined ? `Pregnancy week ${p.week}` : 'Pregnancy dates updated';
    case 'pregnancy_ended': return 'Pregnancy ended';
    case 'feeding_logged': return `Feeding (${p.method})`;
    case 'recovery_metric_logged': return `${p.metric}: ${p.value}`;
    case 'hot_flash_logged': return `Hot flash ${p.severity}/10`;
    case 'stress_logged': return `Stress level ${p.level}/5`;
    case 'activity_logged': return `Activity: ${p.activity}`;
    case 'appointment_logged': return `Appointment: ${p.title}`;
    case 'life_scene_set': return `Life scene: ${p.scene}`;
    case 'condition_reported': return `Conditions: ${(p.conditions ?? []).join(', ')}`;
    default: return event?.eventType ?? 'Event';
  }
}
