/**
 * Standard API response contract (spec §27 "STANDARD API RESPONSE CONTRACT").
 *
 * Every spec-aligned endpoint returns the same envelope so frontend cards can
 * consume data predictably:
 *   data        canonical object/list
 *   state       ready | empty | insufficient_data | restricted | error | not_enough_data
 *   lastUpdated server timestamp
 *   source      manual | rule | ai | medical_reference | device | imported
 *   version     calculation/content/model version where relevant
 *   permissions visibility metadata when relevant
 *   errorCode   machine readable failure reason
 */

export const RESPONSE_STATES = Object.freeze({
  READY: 'ready',
  EMPTY: 'empty',
  INSUFFICIENT_DATA: 'insufficient_data',
  RESTRICTED: 'restricted',
  ERROR: 'error',
});

export const SOURCES = Object.freeze({
  MANUAL: 'manual',
  VOICE: 'voice',
  IMPORTED: 'imported',
  DEVICE: 'device',
  AI: 'ai',
  RULE: 'rule',
  MEDICAL_REFERENCE: 'medical_reference',
});

export const ERROR_CODES = Object.freeze({
  UNAUTHENTICATED: 'UNAUTHENTICATED',
  FORBIDDEN: 'FORBIDDEN',
  NOT_FOUND: 'NOT_FOUND',
  VALIDATION_FAILED: 'VALIDATION_FAILED',
  PERMISSION_RESTRICTED: 'PERMISSION_RESTRICTED',
  RELATIONSHIP_INACTIVE: 'RELATIONSHIP_INACTIVE',
  INSUFFICIENT_DATA: 'INSUFFICIENT_DATA',
  CONFLICT: 'CONFLICT',
  UPSTREAM_UNAVAILABLE: 'UPSTREAM_UNAVAILABLE',
  RATE_LIMITED: 'RATE_LIMITED',
  INTERNAL: 'INTERNAL',
});

function nowIso() {
  return new Date().toISOString();
}

/**
 * Build the envelope without sending it. Useful for embedding one contract
 * object inside another (for example Home modules).
 */
export function envelope(data, options = {}) {
  const {
    state,
    lastUpdated,
    source = null,
    version = null,
    permissions = null,
    errorCode = null,
    meta = null,
  } = options;

  let resolvedState = state;
  if (!resolvedState) {
    if (data === null || data === undefined) {
      resolvedState = RESPONSE_STATES.EMPTY;
    } else if (Array.isArray(data) && data.length === 0) {
      resolvedState = RESPONSE_STATES.EMPTY;
    } else {
      resolvedState = RESPONSE_STATES.READY;
    }
  }

  const body = {
    data: data === undefined ? null : data,
    state: resolvedState,
    lastUpdated: lastUpdated ?? nowIso(),
    source,
    version,
    permissions,
    errorCode,
  };

  if (meta) {
    body.meta = meta;
  }

  return body;
}

export function sendData(res, data, options = {}) {
  const { httpStatus = 200, ...rest } = options;
  return res.status(httpStatus).json(envelope(data, rest));
}

export function sendEmpty(res, options = {}) {
  return sendData(res, null, { ...options, state: RESPONSE_STATES.EMPTY });
}

export function sendInsufficientData(res, options = {}) {
  return sendData(res, options.data ?? null, {
    ...options,
    state: RESPONSE_STATES.INSUFFICIENT_DATA,
    errorCode: options.errorCode ?? ERROR_CODES.INSUFFICIENT_DATA,
  });
}

export function sendRestricted(res, options = {}) {
  return sendData(res, null, {
    ...options,
    httpStatus: options.httpStatus ?? 200,
    state: RESPONSE_STATES.RESTRICTED,
    errorCode: options.errorCode ?? ERROR_CODES.PERMISSION_RESTRICTED,
  });
}

export function sendError(res, httpStatus, errorCode, message, details = null) {
  return res.status(httpStatus).json({
    data: null,
    state: RESPONSE_STATES.ERROR,
    lastUpdated: nowIso(),
    source: null,
    version: null,
    permissions: null,
    errorCode,
    error: { code: errorCode, message, details },
  });
}

/**
 * Resolves the authenticated user id across the differing shapes produced by
 * requireAuth / optionalAuth in this codebase.
 */
export function resolveUserId(req) {
  const raw = req?.user?.userId ?? req?.user?.user_id ?? null;
  if (typeof raw !== 'string') {
    return raw ?? null;
  }
  return raw.replace(/^user:/, '');
}

/**
 * Wraps an async controller so thrown errors become contract errors instead of
 * unhandled rejections. `err.errorCode` and `err.statusCode` are honoured.
 */
export function contractHandler(handler) {
  return async (req, res, next) => {
    try {
      await handler(req, res, next);
    } catch (error) {
      if (res.headersSent) {
        return next(error);
      }
      const status = error.statusCode ?? error.status ?? 500;
      const code = error.errorCode ?? (status === 500 ? ERROR_CODES.INTERNAL : ERROR_CODES.VALIDATION_FAILED);
      const message = status === 500 ? 'Internal server error.' : (error.message ?? 'Request failed.');
      if (status === 500) {
        console.error(`[contract] ${req.method} ${req.originalUrl} failed:`, error.message);
      }
      return sendError(res, status, code, message, error.details ?? null);
    }
  };
}

export function contractError(statusCode, errorCode, message, details = undefined) {
  const error = new Error(message);
  error.statusCode = statusCode;
  error.errorCode = errorCode;
  if (details) error.details = details;
  return error;
}
