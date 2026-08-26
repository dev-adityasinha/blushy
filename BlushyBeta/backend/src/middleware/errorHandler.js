export function httpErrorHandler(err, req, res, next) {
  if (res.headersSent) {
    return next(err);
  }

  const statusCode = err.statusCode ?? err.status ?? 500;
  const message = err.message ?? 'Internal server error';

  res.status(statusCode).json({
    error: {
      message,
      statusCode,
      details: err.details ?? null,
    },
  });
}