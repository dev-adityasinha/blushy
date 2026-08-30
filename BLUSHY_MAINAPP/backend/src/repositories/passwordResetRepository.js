import { db } from '../utils/db.js';

/**
 * Password reset codes.
 *
 * Deliberately a separate collection from `auth_email_verifications`: those
 * records carry a pending signup (password hash, role, cycle start date) and
 * are finalised into a real account when their code is confirmed. A reset code
 * sharing that store, keyed by the same email hash, could be mistaken for a
 * pending signup or overwrite one mid-flow.
 */
const COLLECTION = 'auth_password_resets';

function mapRow(row) {
  if (!row) {
    return null;
  }

  return {
    emailHash: row.email_hash,
    codeHash: row.code_hash,
    expiry: Number(row.expiry),
    attempts: Number(row.attempts ?? 0),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function upsertCode({ emailHash, codeHash, expiry }) {
  await db.collection(COLLECTION).updateOne(
    { email_hash: emailHash },
    {
      // Requesting a new code resets the attempt count; the old code is
      // replaced rather than kept alongside, so only one is ever live.
      $set: {
        code_hash: codeHash,
        expiry,
        attempts: 0,
        updated_at: new Date(),
      },
      $setOnInsert: {
        email_hash: emailHash,
        created_at: new Date(),
      },
    },
    { upsert: true },
  );
}

async function getByEmailHash(emailHash) {
  return mapRow(await db.collection(COLLECTION).findOne({ email_hash: emailHash }));
}

async function incrementAttempts(emailHash) {
  const result = await db.collection(COLLECTION).findOneAndUpdate(
    { email_hash: emailHash },
    { $inc: { attempts: 1 }, $set: { updated_at: new Date() } },
    { returnDocument: 'after' },
  );
  return mapRow(result);
}

async function deleteByEmailHash(emailHash) {
  await db.collection(COLLECTION).deleteOne({ email_hash: emailHash });
}

export const passwordResetRepository = {
  upsertCode,
  getByEmailHash,
  incrementAttempts,
  deleteByEmailHash,
};
