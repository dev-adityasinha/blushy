import { randomUUID } from 'node:crypto';

import { db } from './db.js';
import { env } from './env.js';
import { logger } from './logger.js';

/**
 * Decides which process runs the background schedulers.
 *
 * Four schedulers start at boot -- community cleanup, daily chat summaries,
 * push dispatch and time-capsule delivery. Every one of them writes: it deletes
 * messages, sends notifications, delivers capsules. Started once, that is
 * correct. Started in every process, each job runs once per process: every user
 * gets the same push notification N times, capsules deliver N times, and N
 * cleanup passes delete concurrently.
 *
 * That happens the moment a second instance exists, which on Render is a slider
 * rather than a code change -- so this cannot be guarded with `cluster.isPrimary`.
 * That only knows about workers on one host and would let two instances both
 * believe they were the primary.
 *
 * So the claim is made in the database, where every instance can see it:
 * one row, one holder, a lease that expires. Whoever writes it runs the
 * schedulers; the rest stand by. If the holder dies, the lease lapses and
 * another instance takes over on its next check rather than the jobs stopping
 * for good.
 */

const COLLECTION = 'scheduler_leases';
const LEASE_ID = 'background-schedulers';

/** How long a claim is good for without renewal. */
const LEASE_TTL_MS = 90 * 1000;

/** How often the holder renews, comfortably inside the TTL. */
const RENEW_INTERVAL_MS = 30 * 1000;

/** Identifies this process in the lease row, for diagnosis. */
const OWNER_ID = `${process.env.RENDER_INSTANCE_ID ?? 'local'}-${process.pid}-${randomUUID().slice(0, 8)}`;

/**
 * Tries to take or renew the lease.
 *
 * The update matches only when the lease is unheld, already ours, or expired,
 * so two processes racing cannot both succeed: MongoDB applies the update to
 * one document atomically and the loser's filter no longer matches.
 */
/**
 * The unique index the race depends on.
 *
 * `initDatabase` creates it too, but correctness here must not rest on another
 * module having run first: without it, two processes that both find no row will
 * both insert one, and both believe they hold the lease. Creating an index that
 * already exists is a no-op, so this is cheap insurance.
 */
let indexReady = null;
async function ensureIndex() {
  if (!indexReady) {
    indexReady = db.collection(COLLECTION)
      .createIndex({ lease_id: 1 }, { unique: true })
      .catch((error) => {
        logger.warn(`Scheduler lease index could not be created: ${error.message}`);
      });
  }
  return indexReady;
}

async function claim() {
  await ensureIndex();
  const now = new Date();
  const expiry = new Date(now.getTime() + LEASE_TTL_MS);

  try {
    const result = await db.collection(COLLECTION).updateOne(
      {
        lease_id: LEASE_ID,
        $or: [
          { owner: OWNER_ID },
          { expires_at: { $lt: now } },
        ],
      },
      { $set: { lease_id: LEASE_ID, owner: OWNER_ID, expires_at: expiry, updated_at: now } },
      { upsert: false },
    );

    if (result.matchedCount > 0) return true;

    // No row matched. Either there is none yet, or someone else holds a live
    // lease. Try to create it -- the unique index means only one insert wins.
    try {
      await db.collection(COLLECTION).insertOne({
        lease_id: LEASE_ID,
        owner: OWNER_ID,
        expires_at: expiry,
        updated_at: now,
      });
      return true;
    } catch {
      // Either someone inserted first, or a live lease already exists. Read who
      // actually holds it rather than assuming -- the answer is the only thing
      // that decides whether this process runs the jobs.
      const row = await db.collection(COLLECTION).findOne({ lease_id: LEASE_ID });
      return row?.owner === OWNER_ID;
    }
  } catch (error) {
    logger.warn(`Scheduler lease check failed: ${error.message}`);
    return false;
  }
}

/**
 * Runs [startSchedulers] on exactly one process, and keeps it there.
 *
 * @param {() => Array<() => void>} startSchedulers returns the stop functions.
 * @returns {Promise<() => void>} stops the schedulers and the renewal timer.
 */
export async function runSchedulersOnOneProcess(startSchedulers) {
  if (!env.schedulersEnabled) {
    logger.info('Background schedulers disabled by SCHEDULERS_ENABLED=false.');
    return () => {};
  }

  let stops = [];
  let holding = false;

  const check = async () => {
    const won = await claim();

    if (won && !holding) {
      holding = true;
      stops = startSchedulers();
      logger.info(`Background schedulers started on this process (lease ${OWNER_ID}).`);
    } else if (!won && holding) {
      // Lost the lease -- most likely a stall long enough for it to expire and
      // another instance to take over. Stop, rather than have two run at once.
      holding = false;
      for (const stop of stops) {
        try { stop(); } catch { /* a scheduler that will not stop must not block the rest */ }
      }
      stops = [];
      logger.warn('Background scheduler lease lost; schedulers stopped on this process.');
    }
  };

  await check();
  if (!holding) {
    logger.info('Background schedulers are running on another process; standing by.');
  }

  const timer = setInterval(() => { check().catch(() => {}); }, RENEW_INTERVAL_MS);
  timer.unref?.();

  return () => {
    clearInterval(timer);
    for (const stop of stops) {
      try { stop(); } catch { /* ignore */ }
    }
    stops = [];
    holding = false;
  };
}
