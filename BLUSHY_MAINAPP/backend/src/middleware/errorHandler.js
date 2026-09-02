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
