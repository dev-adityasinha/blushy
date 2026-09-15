import { isPoolSaturationError, SERVICE_BUSY_RETRY_SECONDS } from '../utils/dbErrors.js';

export function httpErrorHandler(err, req, res, next) {
  if (res.headersSent) {
    return next(err);
  }

  // Every database connection is in use. That is a busy service, not a broken
  // one: the same request will succeed shortly, so it gets a 503 and a
  // `Retry-After` rather than a 500 that reports a bug which does not exist.
  if (isPoolSaturationError(err)) {
    res.setHeader('Retry-After', String(SERVICE_BUSY_RETRY_SECONDS));
    console.warn(`${req.method} ${req.originalUrl} was refused: connection pool saturated`);
    return res.status(503).json({
      error: {
        message: 'The service is busy right now. Please try again in a moment.',
        statusCode: 503,
        code: 'SERVICE_BUSY',
        details: null,
      },
    });
  }

  const statusCode = err.statusCode ?? err.status ?? 500;
  const message = err.message ?? 'Internal server error';

  // Every failed request now says so, which is the whole point.
  //
  // Nothing here logged anything, so a request that was refused left no trace
  // at all: when someone reported a feature not working, the server could not
  // tell you whether their request had even arrived. Diagnosis came down to
  // guessing, twice in one evening.
  //
  // Method, path, status and message only -- never the body, never headers,
  // so no password, token or address is written down by this. A 5xx is ours
  // and gets `error`; a 4xx is a refusal working as designed and gets `warn`.
  const where = `${req.method} ${req.originalUrl}`;
  if (statusCode >= 500) {
    console.error(`${where} failed with ${statusCode}: ${message}`);
  } else {
    console.warn(`${where} refused with ${statusCode}: ${message}`);
  }

  // `createHttpError(status, message, { code })` puts the code on the error
  // itself, not on `details`. It was never serialised, so every machine
  // readable reason a controller attached -- STT_CREDENTIAL_REJECTED and the
  // rest -- was dropped here, and the app could only show a generic failure.
  res.status(statusCode).json({
    error: {
      message,
      statusCode,
      code: err.code ?? null,
      details: err.details ?? null,
    },
    errorCode: err.code ?? null,
  });
}
