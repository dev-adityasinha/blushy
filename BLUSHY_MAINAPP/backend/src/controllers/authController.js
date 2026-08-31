import { emailAuthService } from '../services/emailAuthService.js';
import { analyseOnboarding } from '../services/onboardingAnalysisService.js';
import { googleAuthService } from '../services/googleAuthService.js';
import { createHttpError } from '../utils/httpError.js';
import { userRepository } from '../repositories/userRepository.js';
import { dailyMoodRepository } from '../repositories/dailyMoodRepository.js';
import { sleepRepository } from '../repositories/sleepRepository.js';
import { nutritionRepository } from '../repositories/nutritionRepository.js';
import { partnerRepository } from '../repositories/partnerRepository.js';
import { journalRepository } from '../repositories/journalRepository.js';
import { aiHistoryRepository } from '../repositories/aiHistoryRepository.js';
import { publishToUsers } from '../utils/realtimeHub.js';
import { aiChatService } from '../services/aiChatService.js';
import { nutritionPlanService } from '../services/nutritionPlanService.js';
import { emailService } from '../services/emailService.js';
import { env } from '../utils/env.js';
import { logger } from '../utils/logger.js';
import { isWomanRole, normalizeRole as normalizeRoleValue } from '../utils/role.js';

function serializeProfile(user) {
  return {
    userId: user.user_id,
    email: user.email ?? null,
    phoneNumber: user.phoneNumber ?? null,
    displayName: user.displayName ?? null,
    role: normalizeRoleValue(user.role, 'woman'),
    cycleStartDate: user.cycleStartDate ?? null,
    weight: user.weight ?? user.onboardingAnswers?.weight_current ?? user.onboardingAnswers?.weight ?? null,
    onboardingCompleted: Boolean(user.onboardingCompletedAt || (user.onboardingAnswers && Object.keys(user.onboardingAnswers).length > 0) || user.cycleStartDate),
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function isLocalAddress(value) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return false;
  }

  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase();
    return host === 'localhost' || host === '127.0.0.1' || host === '::1';
  } catch (_) {
    const normalized = value.toLowerCase();
    return normalized.includes('localhost') || normalized.includes('127.0.0.1');
  }
}

function resolvePublicBaseUrl(req) {
  const configured = typeof env.appPublicUrl === 'string' ? env.appPublicUrl.trim() : '';
  if (configured && !isLocalAddress(configured)) {
    return configured.replace(/\/$/, '');
  }

  const originHeader = typeof req.get('origin') === 'string' ? req.get('origin').trim() : '';
  if (originHeader && /^https?:\/\//i.test(originHeader) && !isLocalAddress(originHeader)) {
    return originHeader.replace(/\/$/, '');
  }

  const forwardedHost = typeof req.get('x-forwarded-host') === 'string'
    ? req.get('x-forwarded-host').split(',')[0].trim()
    : '';
  const host = forwardedHost || (typeof req.get('host') === 'string' ? req.get('host').trim() : '');

  if (!host) {
    return configured.replace(/\/$/, '');
  }

  const forwardedProto = typeof req.get('x-forwarded-proto') === 'string'
    ? req.get('x-forwarded-proto').split(',')[0].trim()
    : '';
  const protocol = forwardedProto || req.protocol || 'https';
  return `${protocol}://${host}`.replace(/\/$/, '');
}

function buildDeepLink(result) {
  const base = env.mobileAppDeepLinkBase || 'blushy://auth/email-verified';
  const params = new URLSearchParams({
    status: 'verified',
    token: result.token,
    userId: result.userId,
    role: result.role,
    tokenType: result.tokenType,
    expiresIn: String(result.expiresIn),
  });

  if (result.email) {
    params.set('email', result.email);
  }

  if (result.cycleStartDate) {
    params.set('cycleStartDate', result.cycleStartDate);
  }

  const separator = base.includes('?') ? '&' : '?';
  return `${base}${separator}${params.toString()}`;
}

function parseDateOnly(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(trimmed);
  if (!match) {
    return null;
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  // Use Date.UTC to prevent local-timezone shifts (e.g. 2000-01-01 IST → 1999-12-31 UTC)
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (
    Number.isNaN(parsed.getTime()) ||
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    return null;
  }

  return parsed;
}

function calculateAge(dateOfBirth) {
  const today = new Date();
  let age = today.getFullYear() - dateOfBirth.getFullYear();
  const hadBirthdayThisYear =
    today.getMonth() > dateOfBirth.getMonth() ||
    (today.getMonth() === dateOfBirth.getMonth() && today.getDate() >= dateOfBirth.getDate());

  if (!hadBirthdayThisYear) {
    age -= 1;
  }

  return age;
}

const ALLOWED_ENERGY = new Set(['high', 'medium', 'low', 'normal', 'drained', 'exhausted', 'rested', 'energetic', 'moderate']);
const ALLOWED_STRESS = new Set(['low', 'medium', 'high', 'none', 'calm', 'severe', 'moderate', 'overwhelmed']);

function sanitizeMoodValue(value, allowed, fieldName) {
  if (value === null || value === undefined) return undefined;
  const normalized = typeof value === 'string' ? value.trim().toLowerCase() : String(value).trim().toLowerCase();
  if (normalized.length === 0) return undefined;
  if (allowed && allowed.size > 0 && allowed.has(normalized)) {
    return normalized;
  }
  // Allow all custom moods/feelings up to 60 characters
  return normalized.slice(0, 60);
}

function parseTimeOnly(value, fieldName) {
  const normalized = typeof value === 'string' ? value.trim() : '';
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(normalized);
  if (!match) {
    throw createHttpError(400, `${fieldName} must be in HH:mm format.`);
  }

  return normalized;
}

function toMinutes(timeString) {
  const [hours, minutes] = timeString.split(':').map(Number);
  return (hours * 60) + minutes;
}

function minutesToTime(minutesInput) {
  const minutes = ((minutesInput % 1440) + 1440) % 1440;
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}`;
}

function formatDurationText(durationMinutes) {
  const safe = Math.max(0, Math.floor(durationMinutes));
  const hours = Math.floor(safe / 60);
  const minutes = safe % 60;
  if (minutes === 0) {
    return `${hours}h`;
  }
  return `${hours}h ${minutes}m`;
}

function calculateSleepDurationMinutes(sleepTime, wakeTime) {
  const sleepMinutes = toMinutes(sleepTime);
  const wakeMinutes = toMinutes(wakeTime);
  const raw = wakeMinutes - sleepMinutes;
  const duration = raw > 0 ? raw : raw + 1440;

  if (duration < 30 || duration > 960) {
    throw createHttpError(400, 'Sleep duration must be between 30 minutes and 16 hours.');
  }

  return duration;
}

function averageMinutes(values) {
  if (!Array.isArray(values) || values.length === 0) {
    return null;
  }

  const sum = values.reduce((acc, current) => acc + current, 0);
  return Math.round(sum / values.length);
}

function averageSleepStartMinutes(sleepTimes) {
  if (!Array.isArray(sleepTimes) || sleepTimes.length === 0) {
    return null;
  }

  const normalized = sleepTimes.map((time) => {
    const minutes = toMinutes(time);
    return minutes < 720 ? minutes + 1440 : minutes;
  });

  const avg = averageMinutes(normalized);
  if (avg == null) {
    return null;
  }

  return avg % 1440;
}

function buildSleepRecommendation(entries) {
  const validEntries = Array.isArray(entries) ? entries.filter(Boolean) : [];
  if (validEntries.length === 0) {
    return {
      trackedDays: 0,
      averageSleepDurationMinutes: 0,
      recommendedSleepTime: '22:30',
      recommendedWakeTime: '06:30',
      targetSleepDurationMinutes: 480,
      notification: 'Start tracking sleep today. Aim for around 8h tonight.',
    };
  }

  const durations = validEntries.map((entry) => Number(entry.durationMinutes) || 0).filter((n) => n > 0);
  const wakeTimes = validEntries.map((entry) => entry.wakeTime).filter((value) => typeof value === 'string' && value.length >= 5);
  const sleepTimes = validEntries.map((entry) => entry.sleepTime).filter((value) => typeof value === 'string' && value.length >= 5);

  const averageDuration = averageMinutes(durations) ?? 480;
  const averageWake = averageMinutes(wakeTimes.map(toMinutes)) ?? toMinutes('06:30');
  const averageSleep = averageSleepStartMinutes(sleepTimes) ?? toMinutes('22:30');

  let targetDuration = averageDuration;
  if (targetDuration < 450) {
    targetDuration = 480;
  } else if (targetDuration > 540) {
    targetDuration = 510;
  }

  const recommendedWake = averageWake;
  let recommendedSleep = recommendedWake - targetDuration;
  while (recommendedSleep < 0) {
    recommendedSleep += 1440;
  }

  const fallbackSleep = averageSleep;
  const blendedSleep = Math.round((recommendedSleep + fallbackSleep) / 2);

  const recommendedSleepTime = minutesToTime(blendedSleep);
  const recommendedWakeTime = minutesToTime(recommendedWake);

  return {
    trackedDays: validEntries.length,
    averageSleepDurationMinutes: averageDuration,
    recommendedSleepTime,
    recommendedWakeTime,
    targetSleepDurationMinutes: targetDuration,
    notification: `Today sleep by ${recommendedSleepTime} and target ${formatDurationText(targetDuration)}.`,
  };
}

function renderVerificationSuccessPage(deepLink) {
  const safeDeepLink = escapeHtml(deepLink);
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Blushy Email Verified</title>
  <style>
    body { margin: 0; font-family: Arial, sans-serif; background: #fff5f2; color: #2b2b2b; }
    .wrap { max-width: 560px; margin: 0 auto; padding: 56px 20px; text-align: center; }
    .card { background: #ffffff; border-radius: 16px; padding: 28px; box-shadow: 0 10px 28px rgba(0,0,0,0.08); }
    h1 { margin: 0 0 12px; font-size: 28px; color: #b54366; }
    p { margin: 10px 0; line-height: 1.5; }
    a.btn { display: inline-block; margin-top: 16px; padding: 12px 20px; background: #b54366; color: #fff; text-decoration: none; border-radius: 10px; font-weight: 700; }
    .small { font-size: 13px; color: #666; margin-top: 14px; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>Account Verified</h1>
      <p>Your account has been verified successfully.</p>
      <p>This verification page confirms your email in the browser.</p>
      <a class="btn" href="${safeDeepLink}">Open Blushy App</a>
      <p class="small">If you are on web, you can keep this page open as confirmation. If you are on mobile, use the button above to open the app.</p>
    </div>
  </div>
</body>
</html>`;
}

function renderVerificationErrorPage(message) {
  const safeMessage = escapeHtml(message || 'Verification failed. Please request a new email verification link.');
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Blushy Verification Failed</title>
  <style>
    body { margin: 0; font-family: Arial, sans-serif; background: #fff7f7; color: #2b2b2b; }
    .wrap { max-width: 560px; margin: 0 auto; padding: 56px 20px; text-align: center; }
    .card { background: #ffffff; border-radius: 16px; padding: 28px; box-shadow: 0 10px 28px rgba(0,0,0,0.08); }
    h1 { margin: 0 0 12px; font-size: 28px; color: #a32020; }
    p { margin: 10px 0; line-height: 1.5; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>Verification Failed</h1>
      <p>${safeMessage}</p>
      <p>Please return to the app and request a new verification link.</p>
    </div>
  </div>
</body>
</html>`;
}

export async function sendEmailVerification(req, res, next) {
  try {
    const result = await emailAuthService.sendEmailVerification(req.body ?? {}, {
      ip: req.ip,
      userAgent: req.get('user-agent'),
      publicBaseUrl: resolvePublicBaseUrl(req),
    });

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

export async function verifyEmailCode(req, res, next) {
  try {
    const result = await emailAuthService.verifyEmailCode(req.body ?? {}, {
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

export async function completeEmailSignup(req, res, next) {
  try {
    const result = await emailAuthService.completeEmailSignup(req.body ?? {}, {
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

export async function loginWithEmail(req, res, next) {
  try {
    const result = await emailAuthService.loginWithEmail(req.body ?? {}, {
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

export async function loginWithGoogle(req, res, next) {
  try {
    const { idToken, role } = req.body ?? {};
    const result = await googleAuthService.signInWithGoogle(idToken, role);
    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

export async function sendPasswordResetCode(req, res, next) {
  try {
    const result = await emailAuthService.sendPasswordResetCode(req.body ?? {}, {
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

export async function resetPasswordWithEmail(req, res, next) {
  try {
    const result = await emailAuthService.resetPasswordWithEmail(req.body ?? {}, {
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

export async function confirmEmailSignup(req, res, next) {
  try {
    const token = typeof req.query?.token === 'string'
      ? req.query.token
      : typeof req.body?.token === 'string'
        ? req.body.token
        : '';

    const result = await emailAuthService.confirmEmailSignup(token, {
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });

    const deepLink = buildDeepLink(result);
    res.status(200).type('html').send(renderVerificationSuccessPage(deepLink));
  } catch (error) {
    const statusCode = typeof error?.statusCode === 'number' ? error.statusCode : 400;
    const message = typeof error?.message === 'string' ? error.message : 'Verification failed. Please request a new email verification link.';
    res.status(statusCode).type('html').send(renderVerificationErrorPage(message));
  }
}

export async function adminTestSmtp(req, res, next) {
  try {
    const to = typeof req.body?.email === 'string' && req.body.email.trim().length > 0
      ? req.body.email.trim()
      : env.smtpTestTo || env.emailFrom;

    if (!to) {
      throw createHttpError(400, 'No test recipient configured. Provide `email` in body or set SMTP_TEST_TO/EMAIL_FROM.');
    }

    const verificationLink = `${resolvePublicBaseUrl(req)}/auth/confirm-email?token=test-token`;

    try {
      const result = await emailService.sendVerificationLink(to, verificationLink);
      res.status(200).json({ ok: true, result });
    } catch (err) {
      logger.error(`Admin SMTP test failed for ${to}`, err);
      throw createHttpError(502, 'SMTP send failed. Check server logs for details.');
    }
  } catch (error) {
    next(error);
  }
}





export async function getMe(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    res.status(200).json({
      user: serializeProfile(user),
    });
  } catch (error) {
    next(error);
  }
}

export async function updateMe(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const patch = {};
    const body = req.body ?? {};

    if (Object.prototype.hasOwnProperty.call(body, 'cycleStartDate')) {
      const raw = body.cycleStartDate;
      const val = typeof raw === 'string' && raw.trim().length > 0 ? raw.trim() : null;
      if (!isWomanRole(user.role) && val) {
        throw createHttpError(400, 'Cycle date is only available for woman accounts.');
      }
      patch.cycleStartDate = val;
    }

    if (Object.prototype.hasOwnProperty.call(body, 'phoneNumber')) {
      const raw = body.phoneNumber;
      patch.phoneNumber = typeof raw === 'string' && raw.trim().length > 0 ? raw.trim() : null;
    }

    if (Object.prototype.hasOwnProperty.call(body, 'displayName')) {
      const raw = body.displayName;
      patch.displayName = typeof raw === 'string' && raw.trim().length > 0 ? raw.trim() : null;
    }

    if (Object.keys(patch).length === 0) {
      res.status(200).json({
        user: serializeProfile(user),
      });
      return;
    }

    const updated = await userRepository.updateUser(userId, patch);
    if (!updated) {
      throw createHttpError(404, 'User not found.');
    }

    if (patch.cycleStartDate !== undefined && patch.cycleStartDate !== user.cycleStartDate) {
      await notifyPartnerIfShared({ userId, dataType: 'cycle' });
    }

    res.status(200).json({
      user: serializeProfile(updated),
    });
  } catch (error) {
    next(error);
  }
}

export async function getMyOnboarding(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const onboarding = await userRepository.getOnboardingAnswers(userId);
    res.status(200).json({
      role: user.role,
      onboardingAnswers: onboarding?.onboardingAnswers ?? {},
      onboardingCompletedAt: onboarding?.onboardingCompletedAt ?? null,
    });
  } catch (error) {
    next(error);
  }
}

export async function saveMyOnboarding(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const rawAnswers = req.body?.answers;
    if (!rawAnswers || typeof rawAnswers !== 'object' || Array.isArray(rawAnswers)) {
      throw createHttpError(400, 'answers must be an object of question keys and values.');
    }

    const sanitizedEntries = Object.entries(rawAnswers)
      .filter(([key, value]) => typeof key === 'string' && key.trim().length > 0 && value != null)
      .map(([key, value]) => [
        key.trim(),
        typeof value === 'string' ? value.trim() : JSON.stringify(value),
      ]);

    if (sanitizedEntries.length === 0) {
      throw createHttpError(400, 'At least one onboarding answer is required.');
    }

    const answers = Object.fromEntries(sanitizedEntries);

    const preferredName = typeof answers.preferred_name === 'string' ? answers.preferred_name.trim() : '';
    if (preferredName.length > 0) {
      const existingNameUser = await userRepository.getUserByPreferredName(preferredName, userId);
      if (existingNameUser) {
        throw createHttpError(409, 'That name is already taken. Please choose a different name for the app.');
      }
      answers.preferred_name = preferredName;
    }

    if (answers.date_of_birth) {
      const dateOfBirth = parseDateOnly(answers.date_of_birth);
      if (!dateOfBirth) {
        throw createHttpError(400, 'date_of_birth must be a valid date in YYYY-MM-DD format.');
      }

      if (calculateAge(dateOfBirth) < 18) {
        throw createHttpError(403, 'You are under 18.');
      }

      answers.date_of_birth = dateOfBirth.toISOString().slice(0, 10);
    }

    const updated = await userRepository.updateOnboardingAnswers(userId, answers);

    // Work out how the app should behave for her, from what she just answered.
    //
    // Triggered here rather than from the client so it cannot be skipped by
    // closing the app on the last step, and deliberately not awaited: it calls
    // a model, and onboarding must not wait on that. The result lands in her
    // answers, so it reaches the app through the profile it already fetches.
    //
    // Only on the run that carries a life stage -- every later tracker write
    // comes through this same endpoint, and re-analysing on each one would
    // spend a model call per tap.
    if (answers.life_stage) {
      analyseOnboarding(updated?.onboardingAnswers ?? answers)
        .then((analysis) =>
          userRepository.updateOnboardingAnswers(userId, {
            analysis_summary: analysis.summary,
            analysis_focus_areas: analysis.focusAreas.join(','),
            analysis_source: analysis.source,
            analysis_at: new Date().toISOString(),
          }),
        )
        .catch((error) => {
          logger.warn(`Onboarding analysis failed for ${userId}: ${error.message}`);
        });
    }

    const hasNutritionChanges = Object.keys(answers).some((key) =>
      key === 'diet_changes' || key.startsWith('nutrition_'),
    );

    if (hasNutritionChanges) {
      await notifyPartnerIfShared({ userId, dataType: 'onboarding' });
    }

    res.status(200).json({
      role: updated?.role ?? user.role,
      onboardingAnswers: updated?.onboardingAnswers ?? answers,
      onboardingCompletedAt: updated?.onboardingCompletedAt ?? null,
    });
  } catch (error) {
    next(error);
  }
}

export async function getMyDailyMood(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const entryDate = typeof req.query?.date === 'string' ? req.query.date.trim() : '';
    const row = await dailyMoodRepository.getDailyMood(userId, entryDate || undefined);
    const moodStreakDays = await dailyMoodRepository.getMoodStreakDays(userId, entryDate || undefined);

    res.status(200).json({
      role: user.role,
      dailyMood: row,
      moodStreakDays,
    });
  } catch (error) {
    next(error);
  }
}

async function notifyPartnerIfShared({ userId, dataType, dataValue }) {
  try {
    const connection = await partnerRepository.getActiveConnectionForUser(userId);
    if (!connection) return;

    const permissionKey = dataType === 'mood' ? 'shareMood'
      : dataType === 'sleep' ? 'shareSleep'
      : dataType === 'cycle' ? 'shareCycle'
      : dataType === 'insights' ? 'shareInsights'
      : dataType === 'onboarding' ? 'shareOnboarding'
      : null;

    if (!permissionKey || !connection.permissions?.[permissionKey]) return;

    const recipientUserId = connection.partnerUserId;
    const result = await partnerRepository.createNotification({
      connectionId: connection.connectionId,
      recipientUserId,
      dataType,
    });

    if (result.created) {
      publishToUsers(
        [recipientUserId],
        'partner.notification',
        { connectionId: connection.connectionId, dataType, reason: 'data-updated' },
      );

      if (dataType === 'mood' && (dataValue === 'low' || dataValue === 'bad' || dataValue === 'anxious' || dataValue === 'irritated')) {
        aiChatService.generatePartnerMoodSuggestion(dataValue).then((suggestion) => {
          if (suggestion) {
            publishToUsers(
              [recipientUserId],
              'partner.ai_suggestion',
              { text: suggestion },
            );
          }
        }).catch(() => {});
      }
    }
  } catch {
    // Silently fail so data update is never blocked by notification logic.
  }
}

export async function saveMyDailyMood(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const body = req.body ?? {};
    const mood = sanitizeMoodValue(body.mood ?? body.feeling, null, 'mood') || 'okay';
    const energyLevel = sanitizeMoodValue(body.energyLevel ?? body.energy, ALLOWED_ENERGY, 'energyLevel');
    const stressLevel = sanitizeMoodValue(body.stressLevel ?? body.stress, ALLOWED_STRESS, 'stressLevel');
    const symptoms = Array.isArray(body.symptoms) ? body.symptoms.map(s => String(s).trim()).filter(Boolean) : [];
    const entryDate = typeof body.entryDate === 'string' && body.entryDate.trim().length > 0
      ? body.entryDate.trim()
      : undefined;
    const notes = typeof body.notes === 'string' ? body.notes.trim().slice(0, 500) : '';

    const row = await dailyMoodRepository.upsertDailyMood({
      userId,
      entryDate,
      mood,
      energyLevel,
      stressLevel,
      symptoms,
      notes,
    });
    const moodStreakDays = await dailyMoodRepository.getMoodStreakDays(userId, row?.entryDate);

    // Also update onboardingAnswers checkin cache
    try {
      const checkinPatch = {};
      if (mood) checkinPatch['checkin_feeling'] = mood;
      if (energyLevel) checkinPatch['checkin_energy'] = energyLevel;
      if (symptoms.length > 0) checkinPatch['checkin_symptoms'] = symptoms;
      if (Object.keys(checkinPatch).length > 0) {
        await userRepository.updateOnboardingAnswers(userId, checkinPatch);
      }
    } catch (_) {}

    await notifyPartnerIfShared({ userId, dataType: 'mood', dataValue: mood });

    res.status(200).json({
      role: user.role,
      dailyMood: row,
      moodStreakDays,
    });
  } catch (error) {
    next(error);
  }
}

export async function getMySleep(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const entryDateRaw = typeof req.query?.date === 'string' ? req.query.date.trim() : '';
    const parsedDate = entryDateRaw ? parseDateOnly(entryDateRaw) : null;
    if (entryDateRaw && !parsedDate) {
      throw createHttpError(400, 'date must be in YYYY-MM-DD format.');
    }
    const entryDate = parsedDate ? parsedDate.toISOString().slice(0, 10) : undefined;

    const sleepEntry = await sleepRepository.getSleepByDate(userId, entryDate);
    const history = await sleepRepository.getRecentSleepLogs(userId, 7);
    const recommendation = buildSleepRecommendation(history);

    res.status(200).json({
      role: user.role,
      sleepEntry,
      history,
      recommendation,
    });
  } catch (error) {
    next(error);
  }
}

export async function saveMySleep(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const body = req.body ?? {};
    let durationMinutes = typeof body.durationMinutes === 'number' && Number.isFinite(body.durationMinutes)
      ? body.durationMinutes
      : (typeof body.durationMinutes === 'string' && body.durationMinutes.trim() !== '' && Number.isFinite(Number(body.durationMinutes))
        ? Number(body.durationMinutes)
        : NaN);
    let sleepTime = '';
    let wakeTime = '';

    if (body.sleepQuality !== undefined && body.sleepQuality !== null) {
      if (typeof body.sleepQuality !== 'string' || !['good', 'fair', 'poor'].includes(body.sleepQuality.toLowerCase())) {
        throw createHttpError(400, 'sleepQuality must be one of: good, fair, poor.');
      }
    }

    if (body.sleepTime && body.wakeTime) {
      sleepTime = parseTimeOnly(body.sleepTime, 'sleepTime');
      wakeTime = parseTimeOnly(body.wakeTime, 'wakeTime');
      durationMinutes = calculateSleepDurationMinutes(sleepTime, wakeTime);
    } else if (Number.isFinite(durationMinutes) && durationMinutes >= 30 && durationMinutes <= 960) {
      // Direct duration supplied by client
    } else {
      throw createHttpError(400, 'Either durationMinutes (30-960) or sleepTime and wakeTime (HH:mm) are required.');
    }

    const entryDateRaw = typeof body.entryDate === 'string' ? body.entryDate.trim() : '';
    const parsedDate = entryDateRaw ? parseDateOnly(entryDateRaw) : null;
    if (entryDateRaw && !parsedDate) {
      throw createHttpError(400, 'entryDate must be a valid calendar date in YYYY-MM-DD format.');
    }
    const entryDate = parsedDate ? parsedDate.toISOString().slice(0, 10) : undefined;

    const sleepEntry = await sleepRepository.upsertSleepByDate({
      userId,
      entryDate,
      sleepTime: sleepTime || null,
      wakeTime: wakeTime || null,
      durationMinutes,
    });

    await notifyPartnerIfShared({ userId, dataType: 'sleep' });

    const history = await sleepRepository.getRecentSleepLogs(userId, 7);
    const recommendation = buildSleepRecommendation(history);

    res.status(200).json({
      role: user.role,
      sleepEntry,
      history,
      recommendation,
    });
  } catch (error) {
    next(error);
  }
}

export async function getMySleepHistory(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const daysRaw = typeof req.query?.days === 'string' ? Number(req.query.days) : 7;
    const days = Number.isFinite(daysRaw) && daysRaw > 0 ? Math.min(Math.floor(daysRaw), 7) : 7;
    const history = await sleepRepository.getRecentSleepLogs(userId, days);
    const recommendation = buildSleepRecommendation(history);

    res.status(200).json({
      role: user.role,
      history,
      recommendation,
    });
  } catch (error) {
    next(error);
  }
}

export async function saveNutritionAnswers(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const source = (req.body?.answers && typeof req.body.answers === 'object') ? req.body.answers : req.body;
    const { dietaryPreference, allergies, cookingFrequency, nutritionGoals } = source ?? {};
    if (!dietaryPreference || typeof dietaryPreference !== 'string') {
      throw createHttpError(400, 'dietaryPreference is required and must be a string.');
    }
    if (!cookingFrequency || typeof cookingFrequency !== 'string') {
      throw createHttpError(400, 'cookingFrequency is required and must be a string.');
    }
    if (!Array.isArray(nutritionGoals) || nutritionGoals.length === 0) {
      throw createHttpError(400, 'nutritionGoals must be a non-empty array.');
    }

    const result = await nutritionRepository.saveNutritionAnswers({
      userId,
      dietaryPreference: dietaryPreference.trim(),
      allergies: Array.isArray(allergies) ? allergies : [],
      cookingFrequency: cookingFrequency.trim(),
      nutritionGoals,
    });

    res.status(200).json({ message: 'Nutrition answers saved', nutritionAnswers: result });
  } catch (error) {
    next(error);
  }
}

export async function getNutritionAnswers(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const answers = await nutritionRepository.getNutritionAnswers(userId);
    res.status(200).json({ nutritionAnswers: answers });
  } catch (error) {
    next(error);
  }
}

export async function generateNutritionPlan(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const answers = await nutritionRepository.getNutritionAnswers(userId);
    if (!answers) {
      throw createHttpError(400, 'Please complete nutrition quiz first.');
    }

    const planData = await nutritionPlanService.generateNutritionPlan({
      userId,
      dietaryPreference: answers.dietaryPreference,
      allergies: answers.allergies,
      cookingFrequency: answers.cookingFrequency,
      nutritionGoals: answers.nutritionGoals,
      cyclePhase: user.cycleStartDate ? 'cycle-aware' : null,
      role: user.role,
    });

    const saved = await nutritionRepository.saveNutritionPlan(userId, planData);
    res.status(200).json({ message: 'Nutrition plan generated', plan: saved.planData });
  } catch (error) {
    next(error);
  }
}

export async function getNutritionPlan(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const plan = await nutritionRepository.getNutritionPlan(userId);
    if (!plan) {
      return res.status(200).json({ plan: null, message: 'No nutrition plan generated yet' });
    }

    res.status(200).json({ plan: plan.planData });
  } catch (error) {
    next(error);
  }
}

export async function getMyJournal(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const limit = Math.min(Number(req.query?.limit ?? 100), 500);
    const journals = await journalRepository.getJournalsByUserId(userId, limit);

    res.status(200).json({
      journals,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * Marks one day's journal as shared with a partner, or takes it back.
 *
 * Sharing is per item on purpose. The `journal` permission says a partner may
 * receive journal entries at all; this says which days. Without it, granting
 * the category would release every journal the user has ever written.
 */
export async function setMyJournalShared(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const entryDate = typeof req.params?.entryDate === 'string' ? req.params.entryDate.trim() : '';
    if (!/^\d{4}-\d{2}-\d{2}$/.test(entryDate)) {
      throw createHttpError(400, 'A valid entry date (YYYY-MM-DD) is required.');
    }

    const shared = req.body?.shared;
    if (typeof shared !== 'boolean') {
      throw createHttpError(400, 'shared must be true or false.');
    }

    const result = await journalRepository.setJournalShared({ userId, entryDate, shared });
    if (!result) {
      throw createHttpError(404, 'No journal entry for that date.');
    }

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

/**
 * Marks one Dr. Docsy exchange as shared with a partner, or takes it back.
 */
export async function setMySiaConversationShared(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const conversationId = typeof req.params?.conversationId === 'string'
      ? req.params.conversationId.trim()
      : '';
    if (!conversationId) {
      throw createHttpError(400, 'A conversation id is required.');
    }

    const shared = req.body?.shared;
    if (typeof shared !== 'boolean') {
      throw createHttpError(400, 'shared must be true or false.');
    }

    const result = await aiHistoryRepository.setConversationShared({
      userId,
      conversationId,
      shared,
    });
    if (!result) {
      throw createHttpError(404, 'Conversation not found.');
    }

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

export async function saveMyJournal(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const body = req.body ?? {};
    const entryDate = typeof body.entryDate === 'string' ? body.entryDate.trim() : '';
    const entries = Array.isArray(body.entries) ? body.entries : [];
    const summary = typeof body.summary === 'string' ? body.summary.trim() : '';

    const row = await journalRepository.upsertJournal({
      userId,
      entryDate,
      entries,
      summary,
    });

    res.status(200).json({
      journal: row,
    });
  } catch (error) {
    next(error);
  }
}

export async function refreshAuthToken(req, res, next) {
  try {
    const refreshToken = typeof req.body?.refreshToken === 'string' ? req.body.refreshToken : '';
    const result = await emailAuthService.refreshAuthToken(refreshToken);
    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

export async function saveMyWeight(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const weightKg = Number(req.body?.weightKg ?? req.body?.weight);
    if (!Number.isFinite(weightKg) || weightKg <= 0) {
      throw createHttpError(400, 'Valid weightKg is required.');
    }

    const user = await userRepository.saveWeightLog(userId, weightKg);
    res.status(200).json({ message: 'Weight logged successfully', weightKg, user: serializeProfile(user) });
  } catch (error) {
    next(error);
  }
}

export async function logout(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (userId) {
      await userRepository.incrementTokenVersion(userId);
      logger.info(`User session revoked via logout for user ${userId}`);
    }
    res.status(200).json({ success: true, message: 'Logged out successfully.' });
  } catch (error) {
    next(error);
  }
}


