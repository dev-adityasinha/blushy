/**
 * Partner support requests (spec §11 "Partner Support Requests").
 *
 * The partner receives only the request itself, never unrelated medical data.
 * Requests can expire, be revoked, acknowledged and completed.
 */

export const SUPPORT_REQUEST_VERSION = 'support-v1.0.0';

export const SUPPORT_REQUEST_TYPES = Object.freeze({
  rest: { key: 'rest', label: 'I need rest', defaultMessage: 'Some quiet time would really help right now.' },
  comfort: { key: 'comfort', label: 'I need comfort', defaultMessage: 'A hug or some closeness would help.' },
  practical_help: { key: 'practical_help', label: 'Practical help', defaultMessage: 'Help with something practical today would mean a lot.' },
  company: { key: 'company', label: 'Company', defaultMessage: 'I would like some company.' },
  space: { key: 'space', label: 'Space', defaultMessage: 'I need a bit of space today.' },
  just_listen: { key: 'just_listen', label: 'Just listen', defaultMessage: 'I would like to talk, with no advice needed.' },
  custom: { key: 'custom', label: 'Something else', defaultMessage: null },
});

export const SUPPORT_REQUEST_TYPE_KEYS = Object.freeze(Object.keys(SUPPORT_REQUEST_TYPES));

export const SUPPORT_REQUEST_STATES = Object.freeze({
  PENDING: 'pending',
  ACKNOWLEDGED: 'acknowledged',
  COMPLETED: 'completed',
  REVOKED: 'revoked',
  EXPIRED: 'expired',
});

export const DEFAULT_EXPIRY_HOURS = 24;
export const MAX_EXPIRY_HOURS = 168; // one week

/**
 * Valid state transitions. The requester may revoke; the partner may
 * acknowledge and complete.
 */
const TRANSITIONS = Object.freeze({
  [SUPPORT_REQUEST_STATES.PENDING]: {
    [SUPPORT_REQUEST_STATES.ACKNOWLEDGED]: 'partner',
    [SUPPORT_REQUEST_STATES.COMPLETED]: 'partner',
    [SUPPORT_REQUEST_STATES.REVOKED]: 'requester',
    [SUPPORT_REQUEST_STATES.EXPIRED]: 'system',
  },
  [SUPPORT_REQUEST_STATES.ACKNOWLEDGED]: {
    [SUPPORT_REQUEST_STATES.COMPLETED]: 'partner',
    [SUPPORT_REQUEST_STATES.REVOKED]: 'requester',
    [SUPPORT_REQUEST_STATES.EXPIRED]: 'system',
  },
  [SUPPORT_REQUEST_STATES.COMPLETED]: {},
  [SUPPORT_REQUEST_STATES.REVOKED]: {},
  [SUPPORT_REQUEST_STATES.EXPIRED]: {},
});

/**
 * @param {string} from current state
 * @param {string} to   requested state
 * @param {string} actorRole 'requester' | 'partner' | 'system'
 */
export function canTransition(from, to, actorRole) {
  const allowedActor = TRANSITIONS[from]?.[to];
  if (!allowedActor) return { allowed: false, errorCode: 'INVALID_STATE_TRANSITION' };
  if (allowedActor !== actorRole) return { allowed: false, errorCode: 'FORBIDDEN_ACTOR' };
  return { allowed: true, errorCode: null };
}

export function validateSupportRequest({ type, message, expiresInHours }) {
  if (!SUPPORT_REQUEST_TYPES[type]) {
    return { ok: false, error: `type must be one of: ${SUPPORT_REQUEST_TYPE_KEYS.join(', ')}.` };
  }

  let text = typeof message === 'string' ? message.trim().slice(0, 300) : '';
  if (!text) {
    text = SUPPORT_REQUEST_TYPES[type].defaultMessage ?? '';
  }
  if (type === 'custom' && !text) {
    return { ok: false, error: 'A custom request needs a message.' };
  }

  let hours = Number(expiresInHours);
  if (!Number.isFinite(hours) || hours <= 0) hours = DEFAULT_EXPIRY_HOURS;
  hours = Math.min(hours, MAX_EXPIRY_HOURS);

  return {
    ok: true,
    value: {
      type,
      message: text,
      expiresInHours: hours,
    },
  };
}

export function isExpired(request, now = new Date()) {
  if (!request?.expiresAt) return false;
  const expires = new Date(request.expiresAt).getTime();
  if (!Number.isFinite(expires)) return false;
  return now.getTime() > expires;
}

/**
 * The partner-facing projection. Deliberately narrow: type, message, state and
 * timing only. No cycle data, no symptoms, no life stage detail.
 */
export function toPartnerView(request) {
  if (!request) return null;
  return {
    requestId: request.requestId,
    type: request.type,
    label: SUPPORT_REQUEST_TYPES[request.type]?.label ?? request.type,
    message: request.message,
    state: request.state,
    createdAt: request.createdAt,
    expiresAt: request.expiresAt,
    acknowledgedAt: request.acknowledgedAt ?? null,
    completedAt: request.completedAt ?? null,
  };
}
