import { MEDICAL_CONTENT_SEED, PARTNER_LEARN_SEED } from '../config/medicalContentSeed.js';
import { RECOVERY_SESSION_SEED } from '../config/recoverySessionSeed.js';
import { STAGE_EDUCATION_SEED } from '../config/stageEducationSeed.js';
import { seedContentIfMissing, CONTENT_STATES } from '../repositories/medicalContentRepository.js';
import { env } from '../utils/env.js';

/**
 * Idempotent medical content bootstrap (spec §17, §31).
 *
 * Seeds are written in `clinical_review` status by default: content is only
 * served once a named reviewer approves it, which is the whole point of the
 * review workflow. SEED_CONTENT_AUTO_APPROVE exists so a local or CI
 * environment can render the full app without a manual approval pass, and is
 * refused in production.
 */

export async function bootstrapMedicalContent() {
  const autoApprove = String(process.env.SEED_CONTENT_AUTO_APPROVE ?? 'false').toLowerCase() === 'true';

  if (autoApprove && env.nodeEnv === 'production') {
    throw new Error(
      'FATAL: SEED_CONTENT_AUTO_APPROVE cannot be enabled in production. Clinical content requires a named reviewer.',
    );
  }

  const status = autoApprove ? CONTENT_STATES.APPROVED : CONTENT_STATES.CLINICAL_REVIEW;
  const reviewer = autoApprove ? 'AUTO_APPROVED_NON_PRODUCTION' : null;
  const reviewDate = autoApprove ? new Date().toISOString().slice(0, 10) : null;

  // Recovery sessions go through the same gate as everything else: they sit in
  // clinical_review and are not served until a named reviewer approves them.
  const entries = [...MEDICAL_CONTENT_SEED, ...PARTNER_LEARN_SEED, ...RECOVERY_SESSION_SEED, ...STAGE_EDUCATION_SEED].map((entry) => ({
    ...entry,
    status,
    reviewer,
    reviewDate,
    version: entry.version ?? '1.0.0',
    locale: entry.locale ?? 'en',
  }));

  const created = await seedContentIfMissing(entries, 'system_seed');

  if (created > 0) {
    console.log(
      `Seeded ${created} medical content entries in "${status}" status.` +
      (autoApprove ? ' Auto-approved for non-production use.' : ' Awaiting clinical review before they are served.'),
    );
  }

  return { created, status, autoApprove };
}
