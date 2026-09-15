/**
 * Approves stage education articles for production.
 *
 * Approval is deliberately not automatic. `setContentStatus` refuses to move
 * anything to `approved` without a reviewer, and writes that name plus the
 * date into the content audit trail. That record is the point: it says who
 * stood behind this text, and it is what makes the difference between "nobody
 * checked" and "someone did".
 *
 * So this script takes the reviewer's name and will not run without it. The
 * name should be the person who actually read the articles, not the operator
 * running the command.
 *
 * Run:
 *   node src/scripts/approveEducationContent.mjs --reviewer "Dr A Sharma, MBBS"
 *   node src/scripts/approveEducationContent.mjs --reviewer "..." --apply
 *
 * Without --apply it lists what it would approve and changes nothing.
 */
import 'dotenv/config';
import {
  setContentStatus,
  CONTENT_STATES,
} from '../repositories/medicalContentRepository.js';
import { STAGE_EDUCATION_SEED } from '../config/stageEducationSeed.js';
import { db } from '../utils/db.js';

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? null : process.argv[i + 1] ?? null;
}

async function main() {
  const reviewer = arg('reviewer');
  const apply = process.argv.includes('--apply');
  const only = arg('stage');

  if (!reviewer || reviewer.trim().length < 3) {
    console.error(
      'Refusing to approve without a reviewer.\n\n' +
      '  --reviewer "Name, credentials"\n\n' +
      'This name is written to the content audit trail as the person who\n' +
      'approved these clinical articles. It should be the person who read\n' +
      'them, not whoever is running this script.',
    );
    process.exit(1);
  }

  const targets = STAGE_EDUCATION_SEED.filter(
    (entry) => !only || (entry.lifeStages ?? []).includes(only),
  );

  const pending = [];
  for (const entry of targets) {
    const row = await db.collection('medical_content').findOne({ content_id: entry.contentId });
    if (!row) continue;
    if (row.status === CONTENT_STATES.APPROVED) continue;
    pending.push({ contentId: entry.contentId, title: entry.title, status: row.status });
  }

  console.log(`reviewer: ${reviewer}`);
  console.log(`articles awaiting approval: ${pending.length} of ${targets.length}\n`);
  for (const p of pending) {
    console.log(`  ${p.status.padEnd(16)} ${p.contentId}  ${p.title}`);
  }

  if (!apply) {
    console.log('\nDry run. Pass --apply to approve these.');
    process.exit(0);
  }

  let approved = 0;
  const failures = [];
  for (const p of pending) {
    const result = await setContentStatus(
      p.contentId,
      CONTENT_STATES.APPROVED,
      `reviewer:${reviewer}`,
      { reviewer },
    );
    if (result.ok) {
      approved += 1;
    } else {
      failures.push(`${p.contentId}: ${result.error ?? 'not found'}`);
    }
  }

  console.log(`\napproved=${approved} failed=${failures.length}`);
  for (const f of failures) console.log('  ' + f);
  process.exit(failures.length > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
