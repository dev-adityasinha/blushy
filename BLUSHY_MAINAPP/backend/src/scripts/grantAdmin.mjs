/**
 * Grants or revokes the admin role on an existing account.
 *
 * Promoting an account you already sign in with, rather than creating a new
 * one, means no new credentials exist and no password is handled anywhere.
 *
 * Admin is not a small thing here: it opens the clinical content review queue,
 * the moderation queue and the analytics funnel. So this names the account
 * explicitly and will not guess.
 *
 * Run:
 *   node src/scripts/grantAdmin.mjs --email you@example.com
 *   node src/scripts/grantAdmin.mjs --email you@example.com --apply
 *   node src/scripts/grantAdmin.mjs --email you@example.com --revoke --apply
 */
import 'dotenv/config';
import { db } from '../utils/db.js';

const COLLECTIONS = ['users_woman', 'users_man'];

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? null : process.argv[i + 1] ?? null;
}

async function main() {
  const email = (arg('email') ?? '').trim().toLowerCase();
  const apply = process.argv.includes('--apply');
  const revoke = process.argv.includes('--revoke');

  if (!email) {
    console.error('Usage: --email you@example.com [--revoke] [--apply]');
    process.exit(1);
  }

  let found = null;
  for (const collection of COLLECTIONS) {
    const row = await db.collection(collection).findOne({ email });
    if (row) {
      found = { collection, row };
      break;
    }
  }

  if (!found) {
    console.error(`No account found for ${email}.`);
    console.error('Sign up in the app first, then run this against that address.');
    process.exit(1);
  }

  const { collection, row } = found;
  // The original role is kept so revoking restores it rather than guessing.
  const previousRole = row.previous_role ?? row.role;
  const nextRole = revoke ? (previousRole === 'admin' ? 'woman' : previousRole) : 'admin';

  console.log(`account : ${row.email} (${row.display_name ?? 'no name'})`);
  console.log(`store   : ${collection}`);
  console.log(`role    : ${row.role} -> ${nextRole}`);

  if (!apply) {
    console.log('\nDry run. Pass --apply to make the change.');
    process.exit(0);
  }

  const set = { role: nextRole, updated_at: new Date() };
  if (!revoke && row.role !== 'admin') set.previous_role = row.role;

  await db.collection(collection).updateOne({ user_id: row.user_id }, { $set: set });

  console.log(`\nDone. ${row.email} is now ${nextRole}.`);
  console.log('The role is read from this record on every request, so it takes');
  console.log('effect immediately -- no need to sign out and back in.');
  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
