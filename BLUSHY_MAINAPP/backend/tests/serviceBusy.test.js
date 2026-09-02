import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import express from 'express';

import { httpErrorHandler } from '../src/middleware/errorHandler.js';
import { contractHandler, ERROR_CODES } from '../src/utils/apiResponse.js';
import { isPoolSaturationError } from '../src/utils/dbErrors.js';

/**
 * A saturated connection pool is a busy service, not a broken one.
 *
 * `waitQueueTimeoutMS` makes the driver stop waiting for a free connection.
 * Without this mapping that surfaced as a 500 — reporting a bug that does not
 * exist, and telling the caller nothing about what to do. It is a 503 with
 * `Retry-After`, because the same request will succeed shortly.
 *
 * The error is built here rather than raced out of a real pool: reproducing it
 * live needs a timing window that is flaky by nature. The name it carries is
 * the whole contract, and the last test holds the driver to it.
 */
function saturationError() {
  const error = new Error(
    'Timed out while checking out a connection from connection pool: '
    + 'maxPoolSize: 20, connections in use by operations: 20',
  );
  // Exactly what the driver's WaitQueueTimeoutError reports.
  Object.defineProperty(error, 'name', { value: 'MongoWaitQueueTimeoutError' });
  return error;
}

function request(app, urlPath) {
  return new Promise((resolve, reject) => {
    const server = app.listen(0, () => {
      const { port } = server.address();
      http.get({ port, path: urlPath }, (res) => {
        let body = '';
        res.on('data', (c) => { body += c; });
        res.on('end', () => {
          server.close();
          resolve({ status: res.statusCode, headers: res.headers, body: JSON.parse(body || '{}') });
        });
      }).on('error', (e) => { server.close(); reject(e); });
    });
  });
}

test('the plain handler answers 503 with Retry-After', async () => {
  const app = express();
  app.get('/busy', (_req, _res, next) => next(saturationError()));
  app.use(httpErrorHandler);

  const res = await request(app, '/busy');

  assert.equal(res.status, 503);
  assert.equal(res.headers['retry-after'], '3');
  assert.equal(res.body.error.code, 'SERVICE_BUSY');
  assert.match(res.body.error.message, /busy/i);
  assert.doesNotMatch(res.body.error.message, /internal server error/i,
    'it must not report a fault that did not happen');
});

test('the contract envelope answers 503 with the same code', async () => {
  const app = express();
  app.get('/busy', contractHandler(async () => { throw saturationError(); }));
  app.use(httpErrorHandler);

  const res = await request(app, '/busy');

  assert.equal(res.status, 503);
  assert.equal(res.headers['retry-after'], '3');

  const code = res.body.error?.code ?? res.body.errorCode ?? res.body.error?.errorCode;
  assert.equal(code, ERROR_CODES.SERVICE_BUSY);
});

test('a genuine fault is still a 500', async () => {
  assert.equal(isPoolSaturationError(new Error('something broke')), false);
  assert.equal(isPoolSaturationError(null), false);
  assert.equal(isPoolSaturationError(undefined), false);

  const app = express();
  app.get('/boom', (_req, _res, next) => next(new Error('something broke')));
  app.use(httpErrorHandler);

  const res = await request(app, '/boom');
  assert.equal(res.status, 500);
  assert.equal(res.headers['retry-after'], undefined,
    'a real fault must not invite a retry');
});

test('an error that lost its prototype is still recognised', () => {
  // Rebuilt from a serialised shape: the message survives, the class does not.
  const flattened = new Error(
    'Timed out while checking out a connection from connection pool',
  );
  assert.equal(isPoolSaturationError(flattened), true);
});

test('the driver still names it what we match on', () => {
  // The class is internal, is not exported from the package root, and its own
  // source says it is "not subject to semantic versioning compatibility
  // guarantees" — so the name is matched, and this is what holds the driver to
  // it. A rename here would otherwise turn every saturation into a 500 again.
  const driverErrors = fs.readFileSync(
    path.resolve(
      path.dirname(fileURLToPath(import.meta.url)),
      '../node_modules/mongodb/lib/cmap/errors.js',
    ),
    'utf8',
  );

  assert.match(driverErrors, /class WaitQueueTimeoutError/);
  assert.match(driverErrors, /return 'MongoWaitQueueTimeoutError'/);
});
