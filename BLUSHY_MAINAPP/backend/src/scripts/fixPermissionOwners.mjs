/**
 * Repairs connections whose permission owner is the wrong person.
 *
 * Invitations never stored roles, so `resolvePermissionOwner` received
 * `undefined` for both and fell through to "the sender". Any connection where
 * a man sent the invite ended up with him owning the woman's sharing panel:
 * she got 403 reading or changing it, so she could not share anything and
 * every partner feature correctly reported that nothing had been shared.
 *
 * The creation path is fixed; this repairs the rows already written.
 *
 * Run:  node src/scripts/fixPermissionOwners.mjs [--apply]
 * Without --apply it only reports what it would change.
 */
import 'dotenv/config';
import { db, findUserDocument } from '../utils/db.js';

const apply = process.argv.includes('--apply');

async function main() {
  const connections = await db.collection('partner_connections').find({}).toArray();
  let wrong = 0;
  let fixed = 0;

  for (const connection of connections) {
    const [a, b] = await Promise.all([
      findUserDocument({ user_id: connection.user_a_id }),
      findUserDocument({ user_id: connection.user_b_id }),
    ]);

    // The person whose data is shared owns the permissions. With two women,
    // or if a role is missing, leave the row alone rather than guess.
    let expected = null;
    if (a?.role === 'woman' && b?.role === 'man') expected = connection.user_a_id;
    else if (a?.role === 'man' && b?.role === 'woman') expected = connection.user_b_id;

    if (!expected || connection.permission_owner_user_id === expected) continue;

    wrong += 1;
    console.log(
      `connection=${connection.connection_id} owner=${connection.permission_owner_user_id} -> ${expected}`,
    );

    if (apply) {
      await db.collection('partner_connections').updateOne(
        { connection_id: connection.connection_id },
        { $set: { permission_owner_user_id: expected, updated_at: new Date() } },
      );
      fixed += 1;
    }
  }

  console.log(`checked=${connections.length} wrong=${wrong} fixed=${fixed}${apply ? '' : ' (dry run, pass --apply)'}`);
  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
