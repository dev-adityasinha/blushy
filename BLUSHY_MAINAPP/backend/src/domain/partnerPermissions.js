/**
 * Partner permission matrix and server-side privacy filter
 * (spec §9 "Dr. Docsy for Partners", §10 "Partner Permissions", §19-§21, §25).
 *
 * Every permission defaults to OFF. The filter here is the only place partner
 * facing data is assembled, and it runs BEFORE any AI context is constructed
 * (spec §22: "Partner privacy filter runs before AI context construction").
 *
 * Pure module: unit testable without a database.
 */

export const PERMISSION_MATRIX_VERSION = 'permissions-v2.0.0';

/**
 * Canonical permission keys, exactly matching the spec §10 table.
 * `legacyKeys` maps the older flags already stored on existing connections so
 * no live user loses or silently gains sharing during the migration.
 */
export const PERMISSIONS = Object.freeze({
  general_ai_insights: {
    key: 'general_ai_insights',
    label: 'General AI insights',
    example: 'Dr. Docsy noticed she may need more rest.',
    default: false,
    legacyKeys: ['shareInsights', 'allowAiSuggestionsMan'],
    grants: ['insight.general'],
  },
  cycle_insights: {
    key: 'cycle_insights',
    label: 'Cycle insights',
    example: 'Her period may be approaching.',
    default: false,
    legacyKeys: ['shareCycle'],
    grants: ['cycle.phase', 'cycle.next_period_window', 'insight.cycle'],
  },
  fertility_insights: {
    key: 'fertility_insights',
    label: 'Fertility insights',
    example: 'Shared fertile window context.',
    default: false,
    legacyKeys: [],
    grants: ['fertility.window', 'insight.fertility'],
  },
  pregnancy_updates: {
    key: 'pregnancy_updates',
    label: 'Pregnancy updates',
    example: 'Shared pregnancy milestone.',
    default: false,
    legacyKeys: [],
    grants: ['pregnancy.week', 'pregnancy.milestone', 'insight.pregnancy'],
  },
  postpartum_updates: {
    key: 'postpartum_updates',
    label: 'Postpartum updates',
    example: 'Shared recovery context.',
    default: false,
    legacyKeys: [],
    grants: ['postpartum.milestone', 'insight.postpartum'],
  },
  energy: {
    key: 'energy',
    label: 'Energy',
    example: 'She shared that energy is low.',
    default: false,
    legacyKeys: [],
    grants: ['log.energy'],
  },
  symptoms: {
    key: 'symptoms',
    label: 'Symptoms',
    example: 'Only if explicitly permitted.',
    default: false,
    legacyKeys: [],
    grants: ['log.symptoms'],
  },
  mood: {
    key: 'mood',
    label: 'Mood',
    example: 'Only if explicitly permitted.',
    default: false,
    legacyKeys: ['shareMood'],
    grants: ['log.mood'],
  },
  sleep: {
    key: 'sleep',
    label: 'Sleep',
    example: 'Only if explicitly permitted.',
    default: false,
    legacyKeys: ['shareSleep'],
    grants: ['log.sleep'],
  },
  appointments: {
    key: 'appointments',
    label: 'Appointments',
    example: 'Shared appointment reminder.',
    default: false,
    legacyKeys: [],
    grants: ['appointment.summary'],
  },
  care_requests: {
    key: 'care_requests',
    label: 'Care requests',
    example: 'She asked for help.',
    default: true, // The request itself is always addressed to the partner.
    alwaysOn: true,
    legacyKeys: [],
    grants: ['support_request'],
  },
  journal: {
    key: 'journal',
    label: 'Journal',
    example: 'Private unless explicitly shared.',
    default: false,
    legacyKeys: [],
    grants: ['journal.entry'],
  },
  sia_conversations: {
    key: 'sia_conversations',
    label: 'Dr. Docsy conversations',
    example: 'Private unless explicitly shared.',
    default: false,
    legacyKeys: [],
    grants: ['sia.conversation'],
  },
});

export const PERMISSION_KEYS = Object.freeze(Object.keys(PERMISSIONS));

/**
 * Data classes that must NEVER reach a partner regardless of permission state.
 * These are the raw records; the woman shares derived, filtered objects only
 * (spec §21: "Partner must never query the woman's raw health records").
 */
export const NEVER_SHAREABLE = Object.freeze([
  'raw_health_events',
  'diagnosis',
  'medical_reports',
  'screening_scores',
  'account_identifiers',
  'auth_tokens',
]);

export function defaultPermissions() {
  const out = {};
  for (const key of PERMISSION_KEYS) {
    out[key] = PERMISSIONS[key].default;
  }
  return out;
}

/**
 * Migrates a stored permission object - which may use the legacy `shareMood`
 * style flags - to the canonical matrix. Unknown keys are dropped.
 */
export function normalizePermissions(stored) {
  const result = defaultPermissions();
  if (!stored || typeof stored !== 'object') return result;

  for (const key of PERMISSION_KEYS) {
    const definition = PERMISSIONS[key];
    if (definition.alwaysOn) {
      result[key] = true;
      continue;
    }
    if (typeof stored[key] === 'boolean') {
      result[key] = stored[key];
      continue;
    }
    for (const legacyKey of definition.legacyKeys) {
      if (typeof stored[legacyKey] === 'boolean') {
        result[key] = result[key] || stored[legacyKey];
      }
    }
  }

  return result;
}

/**
 * Sanitizes a permission patch from the client. Only known keys are accepted,
 * always-on permissions cannot be turned off, and values are coerced to boolean.
 */
export function sanitizePermissionPatch(patch) {
  const clean = {};
  const rejected = [];
  if (!patch || typeof patch !== 'object') return { clean, rejected };

  for (const [key, value] of Object.entries(patch)) {
    const definition = PERMISSIONS[key];
    if (!definition) {
      rejected.push(key);
      continue;
    }
    if (definition.alwaysOn) {
      rejected.push(key);
      continue;
    }
    clean[key] = Boolean(value);
  }

  return { clean, rejected };
}

const GRANT_INDEX = (() => {
  const index = new Map();
  for (const key of PERMISSION_KEYS) {
    for (const grant of PERMISSIONS[key].grants) {
      index.set(grant, key);
    }
  }
  return index;
})();

export function permissionForGrant(grant) {
  return GRANT_INDEX.get(grant) ?? null;
}

export function hasGrant(permissions, grant) {
  const key = permissionForGrant(grant);
  if (!key) return false;
  return Boolean(permissions?.[key]);
}

/**
 * Relationship states (spec §2). Only `accepted` grants any partner access.
 */
export const CONNECTION_STATES = Object.freeze({
  PENDING: 'pending',
  ACCEPTED: 'accepted',
  DECLINED: 'declined',
  EXPIRED: 'expired',
  REVOKED: 'revoked',
  BLOCKED: 'blocked',
});

const LEGACY_CONNECTION_STATE_MAP = Object.freeze({
  pending_sender_acceptance: CONNECTION_STATES.PENDING,
  pending_recipient_acceptance: CONNECTION_STATES.PENDING,
  pending: CONNECTION_STATES.PENDING,
  active: CONNECTION_STATES.ACCEPTED,
  accepted: CONNECTION_STATES.ACCEPTED,
  breakup_pending: CONNECTION_STATES.ACCEPTED,
  declined: CONNECTION_STATES.DECLINED,
  rejected: CONNECTION_STATES.DECLINED,
  expired: CONNECTION_STATES.EXPIRED,
  revoked: CONNECTION_STATES.REVOKED,
  disconnected: CONNECTION_STATES.REVOKED,
  ended: CONNECTION_STATES.REVOKED,
  blocked: CONNECTION_STATES.BLOCKED,
});

export function normalizeConnectionState(status) {
  if (typeof status !== 'string') return CONNECTION_STATES.REVOKED;
  return LEGACY_CONNECTION_STATE_MAP[status.trim().toLowerCase()] ?? CONNECTION_STATES.REVOKED;
}

export function isConnectionActive(status) {
  return normalizeConnectionState(status) === CONNECTION_STATES.ACCEPTED;
}

/**
 * Builds the partner-safe context.
 *
 * This is the mandatory server-side filter. It takes the woman's full context
 * and returns ONLY the fields the current permissions allow. It is also what
 * feeds Partner Dr. Docsy, so the AI never sees unpermitted data at all.
 *
 * @param {object} fullContext  the woman's assembled context
 * @param {object} permissions  normalized permission object
 * @param {object} options      { connectionState }
 * @returns {{ context: object, allowedGrants: string[], restrictedGrants: string[], state: string }}
 */
export function buildPartnerSafeContext(fullContext = {}, permissions = {}, { connectionState = CONNECTION_STATES.ACCEPTED } = {}) {
  if (normalizeConnectionState(connectionState) !== CONNECTION_STATES.ACCEPTED) {
    return {
      context: { relationshipActive: false },
      allowedGrants: [],
      restrictedGrants: [...GRANT_INDEX.keys()],
      state: 'restricted',
      matrixVersion: PERMISSION_MATRIX_VERSION,
    };
  }

  const perms = normalizePermissions(permissions);
  const allowedGrants = [];
  const restrictedGrants = [];

  // Always-available, non-private context. The partner app must stay useful
  // even when nothing is shared (spec §25: "No sharing -> partner still
  // receives general education/support").
  const context = {
    relationshipActive: true,
    partnerPreferredName: fullContext.preferredName ?? null,
    lifeStage: fullContext.lifeStage ?? null, // stage only; never the underlying data
    relationshipType: fullContext.relationshipType ?? null,
  };

  const put = (grant, key, value) => {
    if (hasGrant(perms, grant)) {
      allowedGrants.push(grant);
      if (value !== undefined && value !== null) {
        context[key] = value;
      }
    } else {
      restrictedGrants.push(grant);
    }
  };

  put('cycle.phase', 'cyclePhase', fullContext.cyclePhase);
  put('cycle.next_period_window', 'nextPeriodWindow', fullContext.nextPeriodWindow);
  put('fertility.window', 'fertileWindow', fullContext.fertileWindow);
  put('pregnancy.week', 'pregnancyWeek', fullContext.pregnancyWeek);
  put('pregnancy.milestone', 'pregnancyMilestone', fullContext.pregnancyMilestone);
  put('postpartum.milestone', 'postpartumMilestone', fullContext.postpartumMilestone);
  put('log.energy', 'energyLevel', fullContext.energyLevel);
  put('log.mood', 'mood', fullContext.mood);
  put('log.sleep', 'sleep', fullContext.sleep);
  put('log.symptoms', 'symptoms', fullContext.symptoms);
  put('appointment.summary', 'appointments', fullContext.appointments);
  put('support_request', 'supportRequests', fullContext.supportRequests);
  put('journal.entry', 'journalEntries', fullContext.journalEntries);
  put('sia.conversation', 'siaConversations', fullContext.siaConversations);
  put('insight.general', 'generalInsights', fullContext.generalInsights);

  // Defence in depth: strip anything that must never leave the woman's side,
  // even if a caller passed it in by mistake.
  for (const forbidden of NEVER_SHAREABLE) {
    delete context[forbidden];
  }

  const sharedKeys = Object.keys(context).filter(
    (key) => !['relationshipActive', 'partnerPreferredName', 'lifeStage', 'relationshipType'].includes(key),
  );

  return {
    context,
    allowedGrants,
    restrictedGrants,
    state: sharedKeys.length > 0 ? 'ready' : 'empty',
    matrixVersion: PERMISSION_MATRIX_VERSION,
  };
}

/**
 * Filters a list of already-generated SharedInsight objects against the CURRENT
 * permissions. An insight generated before a revocation must stop being
 * returned (spec §20 step 8, §25).
 */
export function filterSharedInsights(insights = [], permissions = {}, { connectionState = CONNECTION_STATES.ACCEPTED } = {}) {
  if (normalizeConnectionState(connectionState) !== CONNECTION_STATES.ACCEPTED) return [];
  const perms = normalizePermissions(permissions);

  return insights.filter((insight) => {
    const grants = Array.isArray(insight?.requiredGrants) ? insight.requiredGrants : [];
    if (grants.length === 0) return false; // fail closed
    return grants.every((grant) => hasGrant(perms, grant));
  });
}

/**
 * What the woman sees on her "what am I sharing" screen (spec §10: "Woman can
 * always see what is shared").
 */
export function describeSharingState(permissions = {}) {
  const perms = normalizePermissions(permissions);
  return PERMISSION_KEYS.map((key) => ({
    key,
    label: PERMISSIONS[key].label,
    example: PERMISSIONS[key].example,
    enabled: perms[key],
    alwaysOn: Boolean(PERMISSIONS[key].alwaysOn),
  }));
}
