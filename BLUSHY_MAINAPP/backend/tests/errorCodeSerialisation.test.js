import { test } from 'node:test';
import assert from 'node:assert/strict';
import createHttpError from 'http-errors';
import { httpErrorHandler } from '../src/middleware/errorHandler.js';

/**
 * A machine readable reason is only useful if it survives the wire.
 *
 * Controllers attach one with `createHttpError(status, message, { code })`,
 * which puts it on the error itself. The handler serialised only `details`,
 * so every code was dropped and the app could show nothing more specific than
 * "something went wrong".
 */
function capture(err) {
  let body = null;
  let status = null;
  const res = {
    headersSent: false,
    setHeader() {},
    status(code) { status = code; return this; },
    json(payload) { body = payload; return this; },
  };
  httpErrorHandler(err, { method: 'POST', originalUrl: '/ai/transcribe' }, res, () => {});
  return { status, body };
}

test('a code attached by a controller reaches the response', () => {
  const err = createHttpError(502, 'The speech-to-text provider rejected the request.', {
    code: 'STT_CREDENTIAL_REJECTED',
    providerStatus: 401,
  });
  const { status, body } = capture(err);

  assert.equal(status, 502);
  assert.equal(body.error.code, 'STT_CREDENTIAL_REJECTED');
  assert.equal(body.errorCode, 'STT_CREDENTIAL_REJECTED',
    'the app reads this shape too');
});

test('an error with no code still serialises cleanly', () => {
  const { status, body } = capture(createHttpError(404, 'Not found.'));

  assert.equal(status, 404);
  assert.equal(body.error.code, null);
  assert.equal(body.error.message, 'Not found.');
});

test('details are still carried when a controller sets them', () => {
  const err = createHttpError(400, 'Bad input.');
  err.details = { field: 'email' };
  const { body } = capture(err);

  assert.deepEqual(body.error.details, { field: 'email' });
});
