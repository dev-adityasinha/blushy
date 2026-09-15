/**
 * Recognising a database that is busy rather than broken.
 *
 * `waitQueueTimeoutMS` bounds how long a query waits for a free connection.
 * When it expires the driver raises a wait-queue timeout, which means every
 * connection is in use — the service is saturated, not failing. Answering that
 * with a 500 would report a bug that does not exist, and would tell the caller
 * nothing useful; 503 with `Retry-After` says what is true and what to do.
 *
 * Matched on `name` rather than `instanceof`: the class is internal to the
 * driver, is not exported from the package root, and its own source says it is
 * "not subject to semantic versioning compatibility guarantees". The name is
 * a documented getter and is the stable part.
 */

/** How long to tell a caller to wait. Short: saturation clears in seconds. */
export const SERVICE_BUSY_RETRY_SECONDS = 3;

const BUSY_ERROR_NAMES = new Set([
  'MongoWaitQueueTimeoutError',
]);

/** Whether this error means "every connection is busy", not "something broke". */
export function isPoolSaturationError(error) {
  if (!error) return false;
  if (BUSY_ERROR_NAMES.has(error.name)) return true;

  // A fallback for an error that crossed a boundary and lost its prototype —
  // wrapped by a library, or rebuilt from a serialised shape.
  return typeof error.message === 'string'
    && /timed out while checking out a connection|wait queue timed out/i.test(error.message);
}
