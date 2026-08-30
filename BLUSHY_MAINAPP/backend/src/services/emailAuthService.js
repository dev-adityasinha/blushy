import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';

import { emailVerificationRepository } from '../repositories/emailVerificationRepository.js';
import { passwordResetRepository } from '../repositories/passwordResetRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { emailService } from './emailService.js';
import { env } from '../utils/env.js';
import { createHttpError } from '../utils/httpError.js';
import { logger } from '../utils/logger.js';
import { signAccessToken, signRefreshToken, verifyRefreshToken, signVerificationToken, verifyVerificationToken } from './tokenService.js';
import { normalizeRole as normalizeRoleValue } from '../utils/role.js';
import { normalizePhoneNumber } from '../utils/phone.js';
import { validateEmailBeforeSend } from '../utils/emailValidator.js';

const VERIFICATION_EXPIRY_MS = 10 * 60 * 1000;
const RESET_CODE_EXPIRY_MS = 15 * 60 * 1000;
const RESET_MAX_ATTEMPTS = 5;

function normalizeEmail(email) {
  if (typeof email !== 'string') {
    return null;
  }

  const normalized = email.trim().toLowerCase();
  return normalized.length > 0 ? normalized : null;
}

function hashEmail(email) {
  return crypto.createHash('sha256').update(email).digest('hex');
}

function generateUnusedCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function sanitizeRole(role) {
  return normalizeRoleValue(role, 'woman');
}

function sanitizeCycleStartDate(value) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return null;
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw createHttpError(400, 'Cycle start date must be a valid date.');
  }

  return parsed.toISOString();
}

function normalizePhoneNumberValue(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function normalizePhoneNumberForComparison(value) {
  const normalized = normalizePhoneNumberValue(value);
  if (!normalized) {
    return null;
  }

  return normalized.replace(/[^\d]/g, '');
}

function normalizePhoneNumberForResetComparison(value) {
  const canonical = normalizePhoneNumber(value);
  if (canonical) {
    return canonical;
  }

  return normalizePhoneNumberForComparison(value);
}

function isLocalPublicUrl(value) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return false;
  }

  try {
    const parsed = new URL(value);
    const host = parsed.hostname.toLowerCase();
    return host === 'localhost' || host === '127.0.0.1' || host === '::1';
  } catch (_) {
    const normalized = value.toLowerCase();
    return normalized.includes('localhost') || normalized.includes('127.0.0.1');
  }
}

function resolveVerificationBaseUrl(context = {}) {
  const contextual = typeof context.publicBaseUrl === 'string' ? context.publicBaseUrl.trim() : '';
  const configured = typeof env.appPublicUrl === 'string' ? env.appPublicUrl.trim() : '';

  if (contextual) {
    return contextual.replace(/\/$/, '');
  }
  if (configured) {
    return configured.replace(/\/$/, '');
  }

  throw createHttpError(500, 'Verification link is not configured. Please contact support.');
}

async function finalizePendingSignup(record) {
  if (!record) {
    throw createHttpError(404, 'Verification record not found.');
  }

  if (record.verifiedAt) {
    throw createHttpError(409, 'This email has already been verified. Please login.');
  }

  const existingUser = await userRepository.getUserByEmail(record.email);
  if (existingUser) {
    await emailVerificationRepository.deleteByEmailHash(record.emailHash);
    throw createHttpError(409, 'Account already exists. Please login.');
  }

  const user = await userRepository.createUser({
    email: record.email,
    phoneNumber: record.phoneNumber,
    passwordHash: record.passwordHash,
    role: sanitizeRole(record.role),
    cycleStartDate: record.cycleStartDate,
    emailVerifiedAt: new Date().toISOString(),
  });

  await emailVerificationRepository.deleteByEmailHash(record.emailHash);
  const tokenVersion = user.tokenVersion ?? 1;
  const token = signAccessToken({ userId: user.user_id, tokenVersion });
  const refreshToken = signRefreshToken({ userId: user.user_id, tokenVersion });

  return {
    message: 'Signup completed successfully.',
    token,
    refreshToken,
    tokenType: 'Bearer',
    expiresIn: 3600,
    userId: user.user_id,
    role: normalizeRoleValue(user.role, 'woman'),
    email: user.email,
    cycleStartDate: user.cycleStartDate,
    onboardingCompleted: Boolean(user.onboardingCompletedAt || (user.onboardingAnswers && Object.keys(user.onboardingAnswers).length > 0) || user.cycleStartDate),
  };
}

function enforceStringPayload(payload, fields) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw createHttpError(400, 'Invalid JSON payload format.');
  }

  for (const field of fields) {
    if (payload[field] !== undefined && typeof payload[field] !== 'string') {
      throw createHttpError(400, `Invalid input type for ${field}. Expected string.`);
    }
  }
}

async function checkPasswordBreached(password) {
  try {
    const sha1Hash = crypto.createHash('sha1').update(password).digest('hex').toUpperCase();
    const prefix = sha1Hash.slice(0, 5);
    const suffix = sha1Hash.slice(5);

    const response = await fetch(`https://api.pwnedpasswords.com/range/${prefix}`, {
      headers: { 'User-Agent': 'Blushy-Auth-Security-Checker' },
    });

    if (!response.ok) {
      logger.warn('HIBP password breach API returned non-ok status; failing open', { status: response.status });
      return;
    }

    const text = await response.text();
    const lines = text.split('\n');
    for (const line of lines) {
      const [lineSuffix] = line.split(':');
      if (lineSuffix && lineSuffix.trim() === suffix) {
        throw createHttpError(
          400,
          'This password has appeared in a known data breach. Please choose a safer, unique password.'
        );
      }
    }
  } catch (error) {
    if (error.statusCode === 400) {
      throw error;
    }
    logger.warn('HIBP password breach check unreachable or failed; failing open', {
      error: error.message || String(error),
    });
  }
}

export async function sendEmailVerification(payload, context = {}) {
  enforceStringPayload(payload, ['email', 'password', 'role', 'phoneNumber', 'cycleStartDate', 'mode']);

  const email = normalizeEmail(payload?.email);
  if (!email) {
    throw createHttpError(400, 'Valid email is required.');
  }

  // Validate email format and MX records before proceeding
  logger.info(`sendEmailVerification: starting validation for ${email} at ${new Date().toISOString()}`);
  await validateEmailBeforeSend(email);
  logger.info(`sendEmailVerification: validation passed for ${email} at ${new Date().toISOString()}`);

  const password = typeof payload?.password === 'string' ? payload.password : '';
  const role = sanitizeRole(payload?.role);
  const phoneNumber = normalizePhoneNumberValue(payload?.phoneNumber);
  const cycleStartDate = sanitizeCycleStartDate(payload?.cycleStartDate);
  const mode = payload?.mode === 'signup' ? 'signup' : 'login';

  if (mode !== 'signup') {
    throw createHttpError(400, 'Email verification is only required for signup.');
  }

  const existingUser = await userRepository.getUserByEmail(email);
  if (existingUser) {
    throw createHttpError(409, 'Account already exists for this email. Use login.');
  }

  if (password.trim().length < 8) {
    throw createHttpError(400, 'Password must be at least 8 characters.');
  }

  await checkPasswordBreached(password.trim());

  const emailHash = hashEmail(email);
  const rawCode = generateUnusedCode();
  const verificationToken = signVerificationToken({
    emailHash,
    purpose: 'email-signup',
  });
  const expiry = Date.now() + VERIFICATION_EXPIRY_MS;

  const HASH_ROUNDS = 10;
  const [codeHash, verificationTokenHash, passwordHash] = await Promise.all([
    bcrypt.hash(rawCode, HASH_ROUNDS),
    bcrypt.hash(verificationToken, HASH_ROUNDS),
    bcrypt.hash(password.trim(), HASH_ROUNDS),
  ]);

  await emailVerificationRepository.upsertRecord({
    emailHash,
    email,
    phoneNumber,
    passwordHash,
    role,
    cycleStartDate,
    codeHash,
    verificationTokenHash,
    expiry,
    attempts: 0,
    blockedUntil: null,
    verifiedAt: null,
    metadata: {
      requestedAt: new Date().toISOString(),
      ip: context.ip,
      userAgent: context.userAgent,
    },
  });

  const verificationBaseUrl = resolveVerificationBaseUrl(context);
  const verificationLink = `${verificationBaseUrl}/auth/confirm-email?token=${encodeURIComponent(verificationToken)}`;

  try {
    logger.info(`sendEmailVerification: sending email to ${email} at ${new Date().toISOString()}`);
    await emailService.sendVerificationLink(email, verificationLink, rawCode);
    logger.info(`Verification email sent for ${email} at ${new Date().toISOString()}`);
  } catch (err) {
    logger.error(`Failed to send verification email for ${email}`, {
      message: err?.message,
      name: err?.name,
      stack: err?.stack,
    });

    if (env.emailDeliveryFallbackEnabled) {
      logger.warn(`Email delivery fallback enabled; returning verification link directly for ${email}`);
      return {
        message: `Email delivery is delayed. Check your inbox or enter code ${rawCode}.`,
        expiresIn: 600,
        mode,
        verificationLink,
        code: rawCode,
        deliveryFallbackUsed: true,
      };
    }

    throw createHttpError(502, 'Unable to send verification email. Please try again later.');
  }

  return {
    message: 'Verification email sent successfully.',
    expiresIn: 600,
    mode,
    // The link carries a signed token that verifies the address on its own, so
    // handing it back to the caller defeats the whole point of emailing it:
    // anyone could register an address they do not control. It is exposed only
    // where the delivery fallback is deliberately on, which is never in
    // production.
    ...(env.emailDeliveryFallbackEnabled ? { verificationLink } : {}),
    deliveryFallbackUsed: false,
  };
}

async function verifyEmailCode(payload, context = {}) {
  enforceStringPayload(payload, ['email', 'code']);

  const email = normalizeEmail(payload?.email);
  const code = typeof payload?.code === 'string' ? payload.code.trim() : '';

  if (!email || !code) {
    throw createHttpError(400, 'Email and 6-digit verification code are required.');
  }

  const emailHash = hashEmail(email);
  const pendingRecord = await emailVerificationRepository.getByEmailHash(emailHash);
  if (!pendingRecord) {
    throw createHttpError(400, 'Verification record not found or expired. Please request a new verification email.');
  }

  if (pendingRecord.expiry <= Date.now()) {
    await emailVerificationRepository.deleteByEmailHash(emailHash);
    throw createHttpError(400, 'Verification code expired. Please request a new verification email.');
  }

  const isCodeValid = await bcrypt.compare(code, pendingRecord.codeHash);
  if (!isCodeValid) {
    throw createHttpError(401, 'Invalid 6-digit verification code. Please check and try again.');
  }

  const signupResult = await finalizePendingSignup(pendingRecord);
  logger.info(`Email OTP verification completed for ${email} from ${context.ip ?? 'unknown-ip'}`);
  return signupResult;
}

async function confirmEmailSignup(token, context = {}) {
  const verificationToken = typeof token === 'string' ? token.trim() : '';
  if (!verificationToken) {
    throw createHttpError(400, 'Verification token is required.');
  }

  const decoded = verifyVerificationToken(verificationToken);
  if (decoded?.purpose !== 'email-signup' || typeof decoded?.emailHash !== 'string' || decoded.emailHash.length === 0) {
    throw createHttpError(401, 'Verification link expired or invalid. Please request a new link.');
  }

  const pendingRecord = await emailVerificationRepository.getByEmailHash(decoded.emailHash);
  if (!pendingRecord) {
    throw createHttpError(400, 'Verification link expired or invalid. Please request a new link.');
  }

  const tokenMatches = await bcrypt.compare(verificationToken, pendingRecord.verificationTokenHash);
  if (!tokenMatches) {
    throw createHttpError(401, 'Verification link expired or invalid. Please request a new link.');
  }

  if (pendingRecord.expiry <= Date.now()) {
    await emailVerificationRepository.deleteByEmailHash(pendingRecord.emailHash);
    throw createHttpError(400, 'Verification link expired. Please request a new link.');
  }

  const signupResult = await finalizePendingSignup(pendingRecord);

  logger.info(`Email link verification completed for ${pendingRecord.email} from ${context.ip ?? 'unknown-ip'}`);

  return signupResult;
}

async function completeEmailSignup(payload, context = {}) {
  const verificationToken = typeof payload?.verificationToken === 'string' ? payload.verificationToken : '';
  return confirmEmailSignup(verificationToken, context);
}

const DUMMY_HASH = '$2b$10$e8wV4f8k0/E8wV4f8k0/E8wV4f8k0/E8wV4f8k0/E8wV4f8k0/E8w';

async function loginWithEmail(payload, context = {}) {
  enforceStringPayload(payload, ['email', 'password', 'role']);

  const email = normalizeEmail(payload?.email);
  const password = typeof payload?.password === 'string' ? payload.password : '';
  const requestedRole = sanitizeRole(payload?.role);

  if (!email) {
    throw createHttpError(400, 'Email is required.');
  }

  if (password.trim().length < 8) {
    throw createHttpError(400, 'Password must be at least 8 characters.');
  }

  const user = await userRepository.getUserByEmail(email);
  if (!user) {
    // Perform dummy bcrypt comparison to ensure constant response time (~60ms) and prevent timing attacks
    await bcrypt.compare(password.trim(), DUMMY_HASH);
    throw createHttpError(401, 'Invalid email or password.');
  }

  const accountRole = normalizeRoleValue(user.role, 'woman');

  // Enforce strict role validation in production
  if (requestedRole && requestedRole !== accountRole) {
    const accountRoleLabel = accountRole === 'woman' ? "a Woman's" : "a Partner/Man's";
    const correctExperience = accountRole === 'woman' ? "Woman" : "Partner";
    throw createHttpError(
      403,
      `This email is registered as ${accountRoleLabel} account. Please switch to the ${correctExperience} experience to sign in.`,
      { accountRole, requestedRole },
    );
  }

  if (!user.emailVerifiedAt) {
    throw createHttpError(403, 'Email is not verified yet. Please verify your email before logging in.');
  }

  if (!user.passwordHash) {
    throw createHttpError(401, 'Account password is not set. Please signup again.');
  }

  const isPasswordValid = await bcrypt.compare(password.trim(), user.passwordHash);
  if (!isPasswordValid) {
    throw createHttpError(401, 'Invalid email or password.');
  }

  const tokenVersion = user.tokenVersion ?? 1;
  const token = signAccessToken({ userId: user.user_id, tokenVersion });
  const refreshToken = signRefreshToken({ userId: user.user_id, tokenVersion });

  logger.info(`Email login completed for ${email} from ${context.ip ?? 'unknown-ip'}`);

  return {
    message: 'Login completed successfully.',
    token,
    refreshToken,
    tokenType: 'Bearer',
    expiresIn: 3600,
    userId: user.user_id,
    role: normalizeRoleValue(user.role, 'woman'),
    email: user.email,
    cycleStartDate: user.cycleStartDate,
    onboardingCompleted: Boolean(user.onboardingCompletedAt || (user.onboardingAnswers && Object.keys(user.onboardingAnswers).length > 0) || user.cycleStartDate),
  };
}

/**
 * Step 1 of a password reset: email a single-use code.
 *
 * Always reports success. Saying "no account for that email" here would turn
 * the endpoint into a membership oracle for a women's health app, where being
 * a user is itself sensitive.
 */
async function sendPasswordResetCode(payload, context = {}) {
  enforceStringPayload(payload, ['email']);

  const email = normalizeEmail(payload?.email);
  if (!email) {
    throw createHttpError(400, 'Valid email is required.');
  }

  const generic = { message: 'If an account exists for that email, a reset code has been sent.' };

  const user = await userRepository.getUserByEmail(email);
  // A Google-only account has no password to reset; sending a code would let
  // someone convert it into a password account they control.
  if (!user || !user.passwordHash || !user.emailVerifiedAt) {
    logger.info(`Password reset code requested for a non-resettable address from ${context.ip ?? 'unknown-ip'}`);
    return generic;
  }

  const rawCode = generateUnusedCode();
  const codeHash = await bcrypt.hash(rawCode, 10);

  await passwordResetRepository.upsertCode({
    emailHash: hashEmail(email),
    codeHash,
    expiry: Date.now() + RESET_CODE_EXPIRY_MS,
  });

  try {
    await emailService.sendVerificationLink(email, null, rawCode);
    logger.info(`Password reset code sent for ${email} from ${context.ip ?? 'unknown-ip'}`);
  } catch (error) {
    // The same generic message is returned on a delivery failure as on an
    // address with no account. Letting this throw would answer the question
    // the generic message exists to avoid: an unknown address returns 200 and
    // a real one returns 500, which tells an attacker who has an account here.
    //
    // No code is handed back either way -- the reset simply does not arrive.
    logger.error(`Failed to send password reset code for ${email}`, {
      message: error?.message,
      name: error?.name,
    });
  }

  return generic;
}

/**
 * Step 2: reset the password, proving control of the mailbox with the code.
 *
 * The phone number stays as a second factor where we hold one, but it can no
 * longer stand alone. It used to: when an account had no phone on record the
 * comparison was skipped entirely, so knowing the email address was enough to
 * take the account over -- and the attacker's number was then saved to it,
 * locking the real owner out of this same path.
 */
async function resetPasswordWithEmail(payload, context = {}) {
  enforceStringPayload(payload, ['email', 'phoneNumber', 'code', 'newPassword', 'confirmPassword']);

  const email = normalizeEmail(payload?.email);
  const providedPhone = normalizePhoneNumberValue(payload?.phoneNumber);
  const code = typeof payload?.code === 'string' ? payload.code.trim() : '';
  const newPassword = typeof payload?.newPassword === 'string' ? payload.newPassword.trim() : '';
  const confirmPassword = typeof payload?.confirmPassword === 'string' ? payload.confirmPassword.trim() : '';

  if (!email) {
    throw createHttpError(400, 'Email is required.');
  }

  if (!code) {
    throw createHttpError(400, 'Reset code is required. Request one by email first.');
  }

  if (newPassword.length < 8) {
    throw createHttpError(400, 'Password must be at least 8 characters.');
  }

  if (newPassword !== confirmPassword) {
    throw createHttpError(400, 'New password and confirm password must match.');
  }

  await checkPasswordBreached(newPassword);

  const emailHash = hashEmail(email);
  const pending = await passwordResetRepository.getByEmailHash(emailHash);
  if (!pending) {
    throw createHttpError(400, 'No reset in progress for this email. Request a code first.');
  }

  if (pending.expiry <= Date.now()) {
    await passwordResetRepository.deleteByEmailHash(emailHash);
    throw createHttpError(400, 'Reset code expired. Please request a new one.');
  }

  if (pending.attempts >= RESET_MAX_ATTEMPTS) {
    await passwordResetRepository.deleteByEmailHash(emailHash);
    throw createHttpError(429, 'Too many incorrect attempts. Please request a new code.');
  }

  const codeMatches = await bcrypt.compare(code, pending.codeHash);
  if (!codeMatches) {
    await passwordResetRepository.incrementAttempts(emailHash);
    throw createHttpError(401, 'Invalid reset code.');
  }

  const user = await userRepository.getUserByEmail(email);
  if (!user) {
    throw createHttpError(404, 'Account not found. Please signup first.');
  }

  if (!user.emailVerifiedAt) {
    throw createHttpError(403, 'Email is not verified yet. Please verify your email first.');
  }

  if (!user.passwordHash) {
    throw createHttpError(401, 'Account password is not set. Please signup again.');
  }

  const storedPhone = normalizePhoneNumberValue(user.phoneNumber);
  const normalizedStoredPhone = normalizePhoneNumberForResetComparison(storedPhone);
  const normalizedProvidedPhone = normalizePhoneNumberForResetComparison(providedPhone);

  // Only checked when we hold a number to check against, and only as an extra
  // hurdle on top of the code -- never as the sole proof of identity.
  if (normalizedStoredPhone && normalizedProvidedPhone && normalizedStoredPhone !== normalizedProvidedPhone) {
    throw createHttpError(401, 'Invalid Phone number.');
  }

  const isSamePassword = await bcrypt.compare(newPassword, user.passwordHash);
  if (isSamePassword) {
    throw createHttpError(400, 'New password must be different from your current password.');
  }

  const passwordHash = await bcrypt.hash(newPassword, 10);
  await userRepository.updatePasswordAndPhone(user.user_id, {
    passwordHash,
    // Only fill in a missing number when the reset was proven by code and the
    // caller supplied one; never overwrite a number already on the account.
    phoneNumber: storedPhone ? null : (providedPhone ? normalizePhoneNumber(providedPhone) ?? providedPhone : null),
  });
  await userRepository.incrementTokenVersion(user.user_id);
  await passwordResetRepository.deleteByEmailHash(emailHash);

  logger.info(`Password reset completed for ${email} from ${context.ip ?? 'unknown-ip'}`);

  return {
    message: !storedPhone && providedPhone
      ? 'Password reset successful. Phone number saved to your account.'
      : 'Password reset successful.',
  };
}

async function refreshAuthToken(providedRefreshToken) {
  const tokenString = typeof providedRefreshToken === 'string' ? providedRefreshToken.trim() : '';
  if (!tokenString) {
    throw createHttpError(400, 'Refresh token is required.');
  }

  const decoded = verifyRefreshToken(tokenString);
  if (!decoded?.userId) {
    throw createHttpError(401, 'Invalid refresh token.');
  }

  const user = await userRepository.getUserById(decoded.userId);
  if (!user) {
    throw createHttpError(401, 'User account not found.');
  }

  const tokenVersion = user.tokenVersion ?? 1;
  if (decoded.tokenVersion && decoded.tokenVersion !== tokenVersion) {
    throw createHttpError(401, 'Session revoked. Please sign in again.');
  }

  const newToken = signAccessToken({ userId: user.user_id, tokenVersion });
  const newRefreshToken = signRefreshToken({ userId: user.user_id, tokenVersion });

  return {
    message: 'Token refreshed successfully.',
    token: newToken,
    refreshToken: newRefreshToken,
    tokenType: 'Bearer',
    expiresIn: 3600,
    userId: user.user_id,
    role: normalizeRoleValue(user.role, 'woman'),
  };
}

export const emailAuthService = {
  sendEmailVerification,
  verifyEmailCode,
  completeEmailSignup,
  confirmEmailSignup,
  loginWithEmail,
  sendPasswordResetCode,
  resetPasswordWithEmail,
  refreshAuthToken,
};