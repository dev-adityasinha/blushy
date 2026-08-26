import { db } from '../utils/db.js';
import { normalizeRole as normalizeRoleValue } from '../utils/role.js';

function mapRow(row) {
  if (!row) {
    return null;
  }

  return {
    emailHash: row.email_hash,
    email: row.email,
    phoneNumber: row.phone_number,
    passwordHash: row.password_hash,
    role: normalizeRoleValue(row.role, 'woman'),
    cycleStartDate: row.cycle_start_date ? new Date(row.cycle_start_date).toISOString() : null,
    codeHash: row.code_hash,
    verificationTokenHash: row.verification_token_hash,
    expiry: Number(row.expiry),
    attempts: row.attempts,
    blockedUntil: row.blocked_until === null ? null : Number(row.blocked_until),
    verifiedAt: row.verified_at ? new Date(row.verified_at).toISOString() : null,
    metadata: row.metadata,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function upsertRecord(record) {
  await db.collection('auth_email_verifications').updateOne(
    { email_hash: record.emailHash },
    {
      $set: {
        email: record.email,
        phone_number: record.phoneNumber,
        password_hash: record.passwordHash,
        role: normalizeRoleValue(record.role, 'woman'),
        cycle_start_date: record.cycleStartDate ? new Date(record.cycleStartDate) : null,
        code_hash: record.codeHash,
        verification_token_hash: record.verificationTokenHash,
        expiry: record.expiry,
        attempts: record.attempts,
        blocked_until: record.blockedUntil,
        verified_at: record.verifiedAt ? new Date(record.verifiedAt) : null,
        metadata: record.metadata ?? {},
        updated_at: new Date(),
      },
      $setOnInsert: {
        email_hash: record.emailHash,
        created_at: new Date(),
      },
    },
    { upsert: true }
  );
}

async function getByEmailHash(emailHash) {
  const result = await db.collection('auth_email_verifications').findOne({ email_hash: emailHash });
  return mapRow(result);
}

async function incrementAttempts(emailHash) {
  const result = await db.collection('auth_email_verifications').findOneAndUpdate(
    { email_hash: emailHash },
    {
      $inc: { attempts: 1 },
      $set: { updated_at: new Date() },
    },
    { returnDocument: 'after' }
  );

  return result?.attempts ?? 0;
}

async function setBlockedUntil(emailHash, blockedUntil) {
  const result = await db.collection('auth_email_verifications').findOneAndUpdate(
    { email_hash: emailHash },
    {
      $set: {
        blocked_until: blockedUntil,
        updated_at: new Date(),
      },
    },
    { returnDocument: 'after' }
  );

  return mapRow(result);
}

async function deleteByEmailHash(emailHash) {
  await db.collection('auth_email_verifications').deleteOne({ email_hash: emailHash });
}

async function markVerified(emailHash) {
  const result = await db.collection('auth_email_verifications').findOneAndUpdate(
    { email_hash: emailHash },
    {
      $set: {
        verified_at: new Date(),
        updated_at: new Date(),
      },
    },
    { returnDocument: 'after' }
  );

  return mapRow(result);
}

export const emailVerificationRepository = {
  upsertRecord,
  getByEmailHash,
  incrementAttempts,
  setBlockedUntil,
  markVerified,
  deleteByEmailHash,
};