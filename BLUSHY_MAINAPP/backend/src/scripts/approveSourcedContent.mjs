/**
 * Approves only the content that carries a real citation.
 *
 * The 159 pending items are not one batch. 52 cite an actual guideline — NICE
 * NG201, NICE NG23, WHO antenatal and postnatal recommendations, RCOG Green-top
 * — and a reviewer can meaningfully check those against the source. The other
 * 107 carry a placeholder that says, in the source field itself:
 *
 *   "Blushy editorial copy. Awaiting clinical review and sourcing."
 *   "Blushy partner education, authored in-app and pending clinical review"
 *
 * Approving those would stamp a reviewer's name on text whose own record says
 * it has not been sourced. The gate exists precisely to stop that, so this
 * script refuses to touch them.
 *
 * Run:
 *   node src/scripts/approveSourcedContent.mjs --reviewer "Name, credentials"
 *   node src/scripts/approveSourcedContent.mjs --reviewer "..." --apply
 */
import 'dotenv/config';
import { setContentStatus, CONTENT_STATES } from '../repositories/medicalContentRepository.js';
import { db } from '../utils/db.js';

const PLACEHOLDER = /awaiting clinical review|pending clinical review/i;

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? null : process.argv[i + 1] ?? null;
}

async function main() {
  const reviewer = arg('reviewer');
  const apply = process.argv.includes('--apply');

  if (!reviewer || reviewer.trim().length < 3) {
    console.error(
      'Refusing to approve without a reviewer.\n\n' +
      '  --reviewer "Name, credentials"\n\n' +
      'This name is written into the content audit trail as the person who\n' +
      'approved these clinical articles. It should be whoever actually read\n' +
      'them against the cited guideline, not whoever is running this script.',
    );
    process.exit(1);
  }

  const pending = await db.collection('medical_content')
    .find({ status: CONTENT_STATES.CLINICAL_REVIEW })
    .toArray();

  const sourced = pending.filter((r) => !PLACEHOLDER.test(String(r.source ?? '')));
  const unsourced = pending.filter((r) => PLACEHOLDER.test(String(r.source ?? '')));

  console.log(`reviewer: ${reviewer}`);
  console.log(`pending total      : ${pending.length}`);
  console.log(`carries a citation : ${sourced.length}   <- these are approved`);
  console.log(`unsourced          : ${unsourced.length}   <- left in review\n`);

  const byType = {};
  for (const r of sourced) {
    const key = `${r.content_type} / ${r.audience}`;
    byType[key] = (byType[key] ?? 0) + 1;
  }
  for (const [key, n] of Object.entries(byType).sort((a, b) => b[1] - a[1])) {
    console.log(`  ${key.padEnd(32)} ${n}`);
  }

  if (!apply) {
    console.log('\nDry run. Pass --apply to approve the sourced items.');
    process.exit(0);
  }

  let approved = 0;
  const failures = [];
  for (const row of sourced) {
    const result = await setContentStatus(
      row.content_id,
      CONTENT_STATES.APPROVED,
      `reviewer:${reviewer}`,
      { reviewer },
    );
    if (result.ok) approved += 1;
    else failures.push(`${row.content_id}: ${result.error ?? 'not found'}`);
  }

  console.log(`\napproved=${approved} failed=${failures.length}`);
  for (const f of failures) console.log('  ' + f);
  console.log(`\n${unsourced.length} items remain in clinical_review. They need a real`);
  console.log('source before anyone can honestly approve them.');
  process.exit(failures.length > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
