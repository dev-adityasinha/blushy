/**
 * Re-keys dated health rows onto a single calendar.
 *
 * Two writers were in play. Older code stored a day as midnight in India
 * (`...T18:30:00.000Z`); newer code stored it as UTC midnight
 * (`...T00:00:00.000Z`), which sits 5.5 hours inside the day it names. Both
 * shapes are in the live collections, and a lookup by one instant does not
 * find a row written under the other -- so part of a user's own history was
 * invisible to her.
 *
 * This converts UTC-midnight rows to the India-midnight key while preserving
 * the calendar date the writer intended. It does not touch rows that are
 * already correct, and it refuses to merge: if converting a row would collide
 * with an existing one for the same user and day, it is reported and skipped
 * so a human decides which reading is real.
 *
 * Run:
 *   node src/scripts/migrateDayKeys.mjs
 *   node src/scripts/migrateDayKeys.mjs --apply
 */
import 'dotenv/config';
import { db } from '../utils/db.js';
import { dayStart } from '../utils/appCalendar.js';

const COLLECTIONS = [
  'user_daily_moods',
  'user_daily_moods_woman',
  'user_daily_moods_man',
  'daily_moods',
  'user_sleep_logs',
  'user_sleep_logs_woman',
  'user_sleep_logs_man',
];

const apply = process.argv.includes('--apply');

async function main() {
  let totalConverted = 0;
  let totalCollisions = 0;

  for (const name of COLLECTIONS) {
    let rows;
    try {
      rows = await db.collection(name).find({}).toArray();
    } catch {
      continue;
    }
    if (rows.length === 0) continue;

    const converted = [];
    const collisions = [];

    // Index what is already there so a conversion cannot silently overwrite.
    const occupied = new Set(
      rows
        .filter((r) => r.entry_date instanceof Date)
        .map((r) => `${r.user_id}|${r.entry_date.toISOString()}`),
    );

    for (const row of rows) {
      const value = row.entry_date;
      if (!(value instanceof Date)) continue;

      const iso = value.toISOString();
      // UTC midnight is the shape written by the newer code.
      if (!iso.endsWith('T00:00:00.000Z')) continue;

      const intendedDay = iso.slice(0, 10);
      const target = dayStart(intendedDay);
      const targetKey = `${row.user_id}|${target.toISOString()}`;

      if (occupied.has(targetKey)) {
        collisions.push({ id: row._id, day: intendedDay, user: row.user_id });
        continue;
      }

      converted.push({ id: row._id, from: iso, to: target.toISOString(), day: intendedDay });
      occupied.add(targetKey);
      occupied.delete(`${row.user_id}|${iso}`);
    }

    if (converted.length === 0 && collisions.length === 0) {
      console.log(`${name.padEnd(26)} nothing to do (${rows.length} rows)`);
      continue;
    }

    console.log(`${name.padEnd(26)} convert=${converted.length} collisions=${collisions.length} of ${rows.length}`);
    for (const c of collisions) {
      console.log(`    COLLISION user=${c.user} day=${c.day} id=${c.id} -- left alone, resolve by hand`);
    }

    if (apply) {
      for (const c of converted) {
        await db.collection(name).updateOne(
          { _id: c.id },
          { $set: { entry_date: new Date(c.to), day_key_migrated_at: new Date() } },
        );
      }
      console.log(`    applied ${converted.length}`);
    }

    totalConverted += converted.length;
    totalCollisions += collisions.length;
  }

  console.log(`\ntotal: convert=${totalConverted} collisions=${totalCollisions}`);
  if (!apply) console.log('Dry run. Pass --apply to write these changes.');
  process.exit(totalCollisions > 0 && apply ? 1 : 0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
