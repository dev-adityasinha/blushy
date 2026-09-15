import test, { after } from 'node:test';
import assert from 'node:assert/strict';

import { closeDb, db } from '../src/utils/db.js';
import { runSchedulersOnOneProcess } from '../src/utils/schedulerLease.js';

/**
 * Four schedulers start at boot and every one of them writes: it deletes
 * community messages, sends push notifications, delivers time capsules. Run in
 * two processes, each job runs twice -- every user gets the same notification
 * twice, capsules deliver twice, two cleanup passes delete concurrently.
 *
 * On Render a second instance is a slider, not a code change, so this is a
 * configuration change away at any moment. The lease is what makes that safe.
 */

const COLLECTION = 'scheduler_leases';

// db.js connects at import time, so the file hangs without this.
after(async () => { await closeDb(); });

async function clearLease() {
  await db.collection(COLLECTION).deleteMany({ lease_id: 'background-schedulers' });
}

test('one process claims the lease and starts the schedulers', async () => {
  await clearLease();
  let started = 0;

  const stop = await runSchedulersOnOneProcess(() => {
    started += 1;
    return [() => {}];
  });

  assert.equal(started, 1, 'the first process should start the schedulers');
  stop();
  await clearLease();
});

test('a second claim while the first is held does not start them again', async () => {
  await clearLease();

  let firstStarts = 0;
  const stopFirst = await runSchedulersOnOneProcess(() => {
    firstStarts += 1;
    return [() => {}];
  });
  assert.equal(firstStarts, 1);

  // The module holds one owner id per process, so a second call from this same
  // process renews rather than contends. Simulating a *different* instance
  // means leaving the row in place and checking nobody else can take it.
  const row = await db.collection(COLLECTION).findOne({ lease_id: 'background-schedulers' });
  assert.ok(row, 'a lease row should exist');
  assert.ok(row.expires_at > new Date(), 'the lease should be in the future');

  stopFirst();
  await clearLease();
});

test('an expired lease can be taken over, so jobs do not stop forever', async () => {
  await clearLease();

  // A holder that died: the row is there, the lease lapsed.
  await db.collection(COLLECTION).insertOne({
    lease_id: 'background-schedulers',
    owner: 'some-dead-instance',
    expires_at: new Date(Date.now() - 60_000),
    updated_at: new Date(Date.now() - 120_000),
  });

  let started = 0;
  const stop = await runSchedulersOnOneProcess(() => {
    started += 1;
    return [() => {}];
  });

  assert.equal(started, 1, 'an expired lease should be claimable');

  const row = await db.collection(COLLECTION).findOne({ lease_id: 'background-schedulers' });
  assert.notEqual(row.owner, 'some-dead-instance', 'ownership should have moved');

  stop();
  await clearLease();
});

test('a live lease held elsewhere keeps this process on standby', async () => {
  await clearLease();

  // Another instance holds it and is renewing.
  await db.collection(COLLECTION).insertOne({
    lease_id: 'background-schedulers',
    owner: 'another-live-instance',
    expires_at: new Date(Date.now() + 60_000),
    updated_at: new Date(),
  });

  let started = 0;
  const stop = await runSchedulersOnOneProcess(() => {
    started += 1;
    return [() => {}];
  });

  try {
    assert.equal(started, 0, 'schedulers must not start while another process holds the lease');
    const row = await db.collection(COLLECTION).findOne({ lease_id: 'background-schedulers' });
    assert.equal(row.owner, 'another-live-instance', 'the holder should be undisturbed');
  } finally {
    // Released even on failure: a leaked interval keeps the runner alive.
    stop();
    await clearLease();
  }
});

test('SCHEDULERS_ENABLED=false keeps them off entirely', async () => {
  await clearLease();
  const { env } = await import('../src/utils/env.js');
  const previous = env.schedulersEnabled;
  env.schedulersEnabled = false;

  try {
    let started = 0;
    const stop = await runSchedulersOnOneProcess(() => {
      started += 1;
      return [() => {}];
    });

    assert.equal(started, 0);
    const row = await db.collection(COLLECTION).findOne({ lease_id: 'background-schedulers' });
    assert.equal(row, null, 'a disabled process should not claim the lease either');
    stop();
  } finally {
    env.schedulersEnabled = previous;
    await clearLease();
  }
});
