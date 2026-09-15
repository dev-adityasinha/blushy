import { db } from '../src/utils/db.js';
import { createOrUpdatePeriodEntry } from '../src/repositories/periodRepository.js';

function formatDateOnly(value) {
  if (!value) return null;
  if (value instanceof Date) {
    const y = value.getFullYear();
    const m = String(value.getMonth() + 1).padStart(2, '0');
    const d = String(value.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return trimmed;
    const parsed = new Date(trimmed);
    if (!Number.isNaN(parsed.getTime())) {
      const y = parsed.getFullYear();
      const m = String(parsed.getMonth() + 1).padStart(2, '0');
      const d = String(parsed.getDate()).padStart(2, '0');
      return `${y}-${m}-${d}`;
    }
  }
  return null;
}

export async function runPeriodHistoryMigration() {
  console.log('======================================================================');
  console.log('🔄 RUNNING IDEMPOTENT PERIOD HISTORY BACKFILL MIGRATION');
  console.log('======================================================================\n');

  let processedUsers = 0;
  let backfilledEntries = 0;
  let skippedDuplicates = 0;

  const women = await db.collection('users_woman').find({}).toArray();
  console.log(`[Migration] Found ${women.length} female user documents in MongoDB.`);

  for (const user of women) {
    processedUsers++;
    const userId = user.user_id;
    const answers = user.onboarding_answers || {};

    const candidateDates = [
      formatDateOnly(answers.last_period),
      formatDateOnly(answers.last_period_date),
      formatDateOnly(answers.period_last_start_date),
      formatDateOnly(answers.cycle_start_date),
      formatDateOnly(user.cycle_start_date),
      formatDateOnly(answers.period_last_month_1_start),
      formatDateOnly(answers.period_last_month_2_start),
      formatDateOnly(answers.period_last_month_3_start),
    ].filter((d, idx, arr) => d !== null && arr.indexOf(d) === idx);

    if (Array.isArray(answers.period_history)) {
      for (const d of answers.period_history) {
        const formatted = formatDateOnly(d);
        if (formatted && !candidateDates.includes(formatted)) {
          candidateDates.push(formatted);
        }
      }
    }

    for (const dateStr of candidateDates) {
      const existing = await db.collection('user_period_logs_woman').findOne({
        user_id: userId,
        period_start_date: dateStr,
      });

      if (!existing) {
        await createOrUpdatePeriodEntry(userId, {
          periodStartDate: dateStr,
          source: 'migration_backfill',
        });
        backfilledEntries++;
      } else {
        skippedDuplicates++;
      }
    }
  }

  console.log('\n[Migration Summary]');
  console.log(`- Users processed: ${processedUsers}`);
  console.log(`- New period entries backfilled: ${backfilledEntries}`);
  console.log(`- Existing entries skipped (idempotent): ${skippedDuplicates}`);
  console.log('======================================================================');
  console.log('✅ PERIOD HISTORY MIGRATION COMPLETED SUCCESSFULLY');
  console.log('======================================================================\n');

  return {
    processedUsers,
    backfilledEntries,
    skippedDuplicates,
  };
}

// If run directly via CLI
if (process.argv[1]?.endsWith('migrate_period_history.js')) {
  runPeriodHistoryMigration()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('❌ Migration failed:', err);
      process.exit(1);
    });
}
