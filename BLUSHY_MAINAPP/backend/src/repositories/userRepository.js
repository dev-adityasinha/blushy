import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';
import { normalizeRole as normalizeRoleValue } from '../utils/role.js';
import { batchCreateOnboardingEntries } from './periodRepository.js';

function normalizeCycleStartDate(cycleStartDate) {
  if (typeof cycleStartDate !== 'string' || cycleStartDate.trim().length === 0) {
    return null;
  }

  const parsed = new Date(cycleStartDate);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return formatDateOnly(parsed);
}

function formatDateOnly(value) {
  if (!value) return null;
  
  if (typeof value === 'string') {
    if (value.match(/^\d{4}-\d{2}-\d{2}$/)) {
      return `${value}T00:00:00.000Z`;
    }
    if (value.length >= 10) return `${value.slice(0, 10)}T00:00:00.000Z`;
  }
  
  if (value instanceof Date) {
    return new Date(Date.UTC(
      value.getUTCFullYear(),
      value.getUTCMonth(),
      value.getUTCDate()
    )).toISOString();
  }
  return null;
}

function mapRow(row) {
  if (!row) {
    return null;
  }

  return {
    user_id: row.user_id,
    userId: row.user_id,
    email: row.email ?? null,
    displayName: row.display_name ?? null,
    phoneNumber: row.phone_number ?? null,
    passwordHash: row.password_hash,
    role: row.role,
    cycleStartDate: formatDateOnly(row.cycle_start_date || row.onboarding_answers?.last_period || row.onboarding_answers?.last_period_date || row.onboarding_answers?.cycle_start_date),
    emailVerifiedAt: row.email_verified_at ? new Date(row.email_verified_at).toISOString() : null,
    onboardingAnswers: row.onboarding_answers ?? null,
    onboardingCompletedAt: row.onboarding_completed_at ? new Date(row.onboarding_completed_at).toISOString() : null,
    tokenVersion: Number(row.token_version) || 1,
    token_version: Number(row.token_version) || 1,
    weight: row.weight ?? row.onboarding_answers?.weight_current ?? row.onboarding_answers?.weight ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
    googleId: row.google_id ?? null,
  };
}

function normalizeEmail(email) {
  if (typeof email !== 'string') {
    return null;
  }

  const normalized = email.trim().toLowerCase();
  return normalized.length > 0 ? normalized : null;
}

function normalizePreferredName(name) {
  if (typeof name !== 'string') {
    return null;
  }

  const normalized = name.trim();
  return normalized.length > 0 ? normalized : null;
}

async function getCollectionByUserId(userId) {
  const isMan = await db.collection('users_man').findOne({ user_id: userId });
  return isMan ? 'users_man' : 'users_woman';
}

async function createUser({ email = null, phoneNumber = null, passwordHash = null, role, cycleStartDate = null, emailVerifiedAt = null, googleId = null, displayName = null }) {
  const userRole = normalizeRoleValue(role, 'woman');
  const collectionName = userRole === 'man' ? 'users_man' : 'users_woman';

  const user = {
    user_id: randomUUID(),
    email: normalizeEmail(email),
    display_name: normalizePreferredName(displayName),
    phone_number: typeof phoneNumber === 'string' && phoneNumber.trim().length > 0 ? phoneNumber.trim() : null,
    password_hash: passwordHash,
    role: userRole,
    cycle_start_date: normalizeCycleStartDate(cycleStartDate),
    email_verified_at: emailVerifiedAt ? new Date(emailVerifiedAt) : null,
    google_id: typeof googleId === 'string' && googleId.trim().length > 0 ? googleId.trim() : null,
    onboarding_answers: null,
    onboarding_completed_at: null,
    created_at: new Date(),
    updated_at: new Date(),
  };

  await db.collection(collectionName).insertOne(user);
  return mapRow(user);
}

async function getUserByGoogleId(googleId) {
  if (typeof googleId !== 'string' || googleId.trim().length === 0) {
    return null;
  }
  const cleanId = googleId.trim();
  let user = await db.collection('users_man').findOne({ google_id: cleanId });
  if (!user) {
    user = await db.collection('users_woman').findOne({ google_id: cleanId });
  }
  return mapRow(user);
}

async function linkGoogleId(userId, googleId) {
  if (typeof googleId !== 'string' || googleId.trim().length === 0) {
    return null;
  }
  const cleanId = googleId.trim();
  const collectionName = await getCollectionByUserId(userId);
  await db.collection(collectionName).updateOne(
    { user_id: userId },
    {
      $set: {
        google_id: cleanId,
        updated_at: new Date(),
      }
    }
  );
  const updatedUser = await db.collection(collectionName).findOne({ user_id: userId });
  return mapRow(updatedUser);
}

async function getUserByEmail(email) {
  const normalizedEmail = normalizeEmail(email);
  if (!normalizedEmail) {
    return null;
  }

  let user = await db.collection('users_man').findOne({ email: normalizedEmail });
  if (!user) {
    user = await db.collection('users_woman').findOne({ email: normalizedEmail });
  }
  return mapRow(user);
}

async function updateUserEmailVerifiedAt(userId, emailVerifiedAt) {
  const collectionName = await getCollectionByUserId(userId);
  const emailVerifiedDate = emailVerifiedAt ? new Date(emailVerifiedAt) : new Date();
  
  await db.collection(collectionName).updateOne(
    { user_id: userId },
    {
      $set: {
        email_verified_at: emailVerifiedDate,
        updated_at: new Date(),
      }
    }
  );

  const updatedUser = await db.collection(collectionName).findOne({ user_id: userId });
  return mapRow(updatedUser);
}

async function getUserById(userId) {
  let user = await db.collection('users_man').findOne({ user_id: userId });
  if (!user) {
    user = await db.collection('users_woman').findOne({ user_id: userId });
  }
  return mapRow(user);
}

async function updateUser(userId, patch) {
  const current = await getUserById(userId);
  if (!current) {
    return null;
  }

  const collectionName = current.role === 'man' ? 'users_man' : 'users_woman';
  const $set = {
    updated_at: new Date(),
  };

  if (Object.prototype.hasOwnProperty.call(patch, 'cycleStartDate')) {
    $set.cycle_start_date = normalizeCycleStartDate(patch.cycleStartDate);
  }
  if (Object.prototype.hasOwnProperty.call(patch, 'phoneNumber')) {
    $set.phone_number = typeof patch.phoneNumber === 'string' && patch.phoneNumber.trim().length > 0
      ? patch.phoneNumber.trim()
      : null;
  }
  if (Object.prototype.hasOwnProperty.call(patch, 'displayName')) {
    $set.display_name = typeof patch.displayName === 'string' && patch.displayName.trim().length > 0
      ? patch.displayName.trim()
      : null;
  }

  await db.collection(collectionName).updateOne(
    { user_id: userId },
    { $set }
  );

  const updatedUser = await db.collection(collectionName).findOne({ user_id: userId });
  return mapRow(updatedUser);
}

async function updatePasswordAndPhone(userId, { passwordHash, phoneNumber }) {
  const collectionName = await getCollectionByUserId(userId);
  const normalizedPhone = typeof phoneNumber === 'string' && phoneNumber.trim().length > 0
    ? phoneNumber.trim()
    : null;

  const updateDoc = {
    password_hash: passwordHash,
    updated_at: new Date(),
  };

  if (normalizedPhone !== null) {
    updateDoc.phone_number = normalizedPhone;
  }

  await db.collection(collectionName).updateOne(
    { user_id: userId },
    { $set: updateDoc }
  );

  const updatedUser = await db.collection(collectionName).findOne({ user_id: userId });
  return mapRow(updatedUser);
}

async function updateOnboardingAnswers(userId, answers) {
  const collectionName = await getCollectionByUserId(userId);
  const current = await db.collection(collectionName).findOne({ user_id: userId });
  if (!current) {
    return null;
  }

  const existingAnswers = current.onboarding_answers || {};
  const mergedAnswers = { ...existingAnswers, ...(answers ?? {}) };

  // ── Strip derived & legacy duplicate fields ──
  // Deleting legacy aliases prevents contradictory data (e.g. cycle_length=28 vs cycle_frequency_days=30)
  // and keeps MongoDB payloads clean and concise.
  const legacyAndDerivedFieldsToStrip = [
    'cycle_current_day',
    'cycle_predicted_next_start_date',
    'cycle_predicted_next_end_date',
    'cycle_predicted_fertile_start_date',
    'cycle_predicted_fertile_end_date',
    'cycle_intervals_used_days',
    'period_last_month_1_start',
    'period_last_month_2_start',
    'period_last_month_3_start',
    'period_last_start_date',
    'cycle_last_period_start',
    'cycle_latest_start_date',
    'period_cycle_length',
    'cycle_usual_length_days',
    'cycle_frequency_days',
    'cycleLength',
  ];
  for (const field of legacyAndDerivedFieldsToStrip) {
    delete mergedAnswers[field];
  }

  // ── Set canonical inputs explicitly ──
  const canonicalCycleLength = answers?.cycle_length ?? mergedAnswers.cycle_length;
  if (canonicalCycleLength != null) {
    const numLen = Number(canonicalCycleLength);
    if (Number.isFinite(numLen) && numLen >= 18 && numLen <= 60) {
      mergedAnswers.cycle_length = String(Math.round(numLen));
    }
  }

  const canonicalLastPeriod = answers?.last_period ?? answers?.last_period_date ?? answers?.cycle_start_date;
  if (canonicalLastPeriod) {
    mergedAnswers.last_period = canonicalLastPeriod;
    mergedAnswers.cycle_start_date = canonicalLastPeriod;
  }

  const updateDoc = {
    onboarding_answers: mergedAnswers,
    onboarding_completed_at: new Date(),
    updated_at: new Date(),
  };

  const rawLastPeriod = answers.last_period || answers.last_period_date || answers.cycle_start_date;
  if (rawLastPeriod) {
    const parsedDate = new Date(rawLastPeriod);
    if (!Number.isNaN(parsedDate.getTime())) {
      updateDoc.cycle_start_date = parsedDate;
    }
  }

  if (answers.preferred_name && typeof answers.preferred_name === 'string') {
    updateDoc.display_name = answers.preferred_name.trim();
  }

  await db.collection(collectionName).updateOne(
    { user_id: userId },
    { $set: updateDoc }
  );

  // Sync historical period start dates to periodRepository
  try {
    const datesToSeed = [];
    if (Array.isArray(answers.period_history)) {
      for (const d of answers.period_history) {
        if (typeof d === 'string' && d.trim().length > 0) datesToSeed.push(d.trim());
      }
    }
    if (canonicalLastPeriod && !datesToSeed.includes(canonicalLastPeriod)) {
      datesToSeed.push(canonicalLastPeriod);
    }
    if (datesToSeed.length > 0) {
      await batchCreateOnboardingEntries(userId, datesToSeed, 'onboarding');
    }
  } catch (_) {}

  const updatedUser = await db.collection(collectionName).findOne({ user_id: userId });
  return mapRow(updatedUser);
}

async function getUserByPreferredName(preferredName, excludeUserId = null) {
  const normalizedName = normalizePreferredName(preferredName);
  if (!normalizedName) {
    return null;
  }

  const escapedName = normalizedName.replace(/[/\-\\^$*+?.()|[\]{}]/g, '\\$&');
  const regex = new RegExp(`^\\s*${escapedName}\\s*$`, 'i');

  const query = {
    'onboarding_answers.preferred_name': regex,
  };

  if (excludeUserId) {
    const cleanId = excludeUserId.replace('user:', '');
    query.user_id = { $nin: [cleanId, `user:${cleanId}`] };
  }

  let user = await db.collection('users_man').findOne(query);
  if (!user) {
    user = await db.collection('users_woman').findOne(query);
  }
  return mapRow(user);
}

async function getOnboardingAnswers(userId) {
  const user = await getUserById(userId);
  if (!user) {
    return null;
  }

  return {
    onboardingAnswers: user.onboardingAnswers ?? {},
    onboardingCompletedAt: user.onboardingCompletedAt,
  };
}

async function getPublicUserProfile(userId) {
  const user = await getUserById(userId);
  if (!user) {
    return null;
  }

  return {
    user_id: user.user_id,
    email: user.email ?? null,
    phoneNumber: user.phoneNumber ?? null,
    role: user.role,
    cycleStartDate: user.cycleStartDate ?? null,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

async function getUsersByRole(role, limit = 100, offset = 0) {
  const normalizedRole = normalizeRoleValue(role, 'woman');
  const collectionName = normalizedRole === 'man' ? 'users_man' : 'users_woman';
  
  const users = await db.collection(collectionName)
    .find({})
    .sort({ created_at: -1 })
    .skip(offset)
    .limit(limit)
    .toArray();
  return users.map(mapRow);
}

async function countUsersByRole(role) {
  const normalizedRole = normalizeRoleValue(role, 'woman');
  const collectionName = normalizedRole === 'man' ? 'users_man' : 'users_woman';
  
  const count = await db.collection(collectionName).countDocuments({});
  return count;
}

async function incrementTokenVersion(userId) {
  const collectionName = await getCollectionByUserId(userId);
  await db.collection(collectionName).updateOne(
    { user_id: userId },
    {
      $inc: { token_version: 1 },
      $set: { updated_at: new Date() },
    }
  );
}

async function saveWeightLog(userId, weightKg) {
  const collectionName = await getCollectionByUserId(userId);
  const current = await db.collection(collectionName).findOne({ user_id: userId });
  if (!current) return null;

  const existingAnswers = current.onboarding_answers || {};
  const mergedAnswers = {
    ...existingAnswers,
    weight_current: String(weightKg),
    weight: String(weightKg),
  };

  await db.collection(collectionName).updateOne(
    { user_id: userId },
    {
      $set: {
        weight: Number(weightKg),
        onboarding_answers: mergedAnswers,
        updated_at: new Date(),
      }
    }
  );

  const updatedUser = await db.collection(collectionName).findOne({ user_id: userId });
  return mapRow(updatedUser);
}

const saveOnboardingAnswers = updateOnboardingAnswers;

export {
  createUser,
  getUserById,
  getUserByEmail,
  getUserByGoogleId,
  linkGoogleId,
  updateUserEmailVerifiedAt,
  updateUser,
  updatePasswordAndPhone,
  incrementTokenVersion,
  updateOnboardingAnswers,
  saveOnboardingAnswers,
  getUserByPreferredName,
  getOnboardingAnswers,
  getPublicUserProfile,
  getUsersByRole,
  countUsersByRole,
  saveWeightLog,
};

export const userRepository = {
  createUser,
  getUserById,
  getUserByEmail,
  getUserByGoogleId,
  linkGoogleId,
  updateUserEmailVerifiedAt,
  updateUser,
  updatePasswordAndPhone,
  incrementTokenVersion,
  updateOnboardingAnswers,
  saveOnboardingAnswers,
  getUserByPreferredName,
  getOnboardingAnswers,
  getPublicUserProfile,
  getUsersByRole,
  countUsersByRole,
  saveWeightLog,
};