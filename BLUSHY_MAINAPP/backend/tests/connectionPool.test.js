import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { MongoClient } from 'mongodb';
import { env } from '../src/utils/env.js';

/**
 * The pool is bounded on purpose.
 *
 * The driver's defaults are maxPoolSize 100, waitQueueTimeoutMS 0 and
 * maxIdleTimeMS 0. Measured against this deployment, the cluster allows **500
 * connections in total**, so at 100 per process a sixth instance cannot connect
 * at all; a query that finds the pool busy waits for ever with no error; and a
 * connection opened during a burst is never handed back.
 *
 * These pin the values, because a silent drift back to the defaults would show
 * up as an outage rather than a regression.
 */
test('the configured bounds are what the driver receives', () => {
  const c = new MongoClient('mongodb://127.0.0.1:27017/x', {
    maxPoolSize: env.mongoMaxPoolSize,
    waitQueueTimeoutMS: env.mongoWaitQueueTimeoutMs,
    maxIdleTimeMS: env.mongoMaxIdleTimeMs,
  });

  assert.equal(c.options.maxPoolSize, 20);
  assert.equal(c.options.waitQueueTimeoutMS, 10000);
  assert.equal(c.options.maxIdleTimeMS, 60000);
});

test('none of them is left at the driver default', () => {
  // The defaults, confirmed against the installed driver.
  const defaults = new MongoClient('mongodb://127.0.0.1:27017/x');
  assert.equal(defaults.options.maxPoolSize, 100);
  assert.equal(defaults.options.waitQueueTimeoutMS, 0);
  assert.equal(defaults.options.maxIdleTimeMS, 0);

  assert.notEqual(env.mongoMaxPoolSize, 100);
  assert.notEqual(env.mongoWaitQueueTimeoutMs, 0,
    'waiting for ever turns a saturated pool into a hang with no error');
  assert.notEqual(env.mongoMaxIdleTimeMs, 0,
    'never releasing means idle instances keep the whole connection budget');
});

test('the pool fits the cluster it connects to', () => {
  // 500 connections cluster-wide, measured. At 20 per process, 25 instances
  // fit; at the default 100, only five.
  const CLUSTER_CONNECTION_LIMIT = 500;
  const instances = Math.floor(CLUSTER_CONNECTION_LIMIT / env.mongoMaxPoolSize);

  assert.ok(instances >= 20,
    `only ${instances} instances fit in ${CLUSTER_CONNECTION_LIMIT} connections`);
});

test('db.js passes them rather than constructing a bare client', () => {
  const source = fs.readFileSync(
    path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../src/utils/db.js'),
    'utf8',
  );

  assert.ok(!/new MongoClient\(env\.mongodbUri\)\s*;/.test(source),
    'a bare client takes every default back');
  for (const opt of ['maxPoolSize:', 'waitQueueTimeoutMS:', 'maxIdleTimeMS:']) {
    assert.ok(source.includes(opt), `${opt} must be set`);
  }
});

test('they stay overridable per environment', () => {
  // The right numbers depend on the cluster plan; these are sized for the
  // current one and must not be baked in.
  const source = fs.readFileSync(
    path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../src/utils/env.js'),
    'utf8',
  );
  for (const key of ['MONGO_MAX_POOL_SIZE', 'MONGO_WAIT_QUEUE_TIMEOUT_MS', 'MONGO_MAX_IDLE_TIME_MS']) {
    assert.ok(source.includes(key), `${key} must be readable from the environment`);
  }
});
