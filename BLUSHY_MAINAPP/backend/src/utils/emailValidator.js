import { env } from './env.js';
import { createHttpError } from './httpError.js';
import { logger } from './logger.js';

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const DEFAULT_REACHER_URL = 'https://api.reacher.email';
const FALLBACK_MESSAGE = 'Using local format validation because Reacher API is not configured.';

function getReacherBaseUrl() {
  const configured = typeof env.reacherApiUrl === 'string' ? env.reacherApiUrl.trim() : '';
  return configured || DEFAULT_REACHER_URL;
}

function getReacherApiKey() {
  return typeof env.reacherApiKey === 'string' ? env.reacherApiKey.trim() : '';
}

async function validateWithReacher(email) {
  const apiKey = getReacherApiKey();
  if (!apiKey) {
    logger.warn(FALLBACK_MESSAGE);
    return { normalized: email, verified: true, source: 'local-format-only' };
  }

  const controller = new AbortController();
  // Shorter Reacher timeout to fail-fast in hosted environments
  const timeoutId = setTimeout(() => controller.abort(), 5000);

  try {
    const response = await fetch(`${getReacherBaseUrl().replace(/\/$/, '')}/v0/check_email`, {
      method: 'POST',
      headers: {
        Authorization: apiKey,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        to_email: email,
        from_email: env.emailFrom || undefined,
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const bodyText = await response.text().catch(() => '');
      logger.warn(`Reacher API request failed for ${email} with status ${response.status}${bodyText ? `: ${bodyText}` : ''}`);
      return { normalized: email, verified: true, source: 'reacher-service-fallback' };
    }

    const result = await response.json();
    const reachability = typeof result?.is_reachable === 'string' ? result.is_reachable.toLowerCase() : 'unknown';
    const syntaxValid = result?.syntax?.is_valid_syntax !== false;

    if (!syntaxValid || reachability === 'invalid') {
      const reason = result?.syntax?.suggestion || result?.smtp?.error || 'Email address is not reachable.';
      logger.warn(`Reacher rejected ${email}: ${reason}`);
      throw createHttpError(400, `Email address is not valid: ${reason}`);
    }

    logger.info(`Reacher validated ${email} as ${reachability}`);
    return { normalized: email, verified: true, source: 'reacher', result };
  } catch (error) {
    if (error?.name === 'AbortError') {
      logger.warn(`Reacher validation timed out for ${email}`);
      return { normalized: email, verified: true, source: 'timeout-fallback' };
    }

    if (error?.statusCode && error.statusCode < 500) {
      throw error;
    }

    logger.warn(`Reacher validation error for ${email}`, error);
    return { normalized: email, verified: true, source: 'error-fallback' };
  } finally {
    clearTimeout(timeoutId);
  }
}

export async function validateEmailBeforeSend(email) {
  if (!email || typeof email !== 'string') {
    throw createHttpError(400, 'Email is required.');
  }

  const normalized = email.trim().toLowerCase();
  if (!EMAIL_REGEX.test(normalized)) {
    logger.warn(`Email validation failed for ${normalized}: invalid format`);
    throw createHttpError(400, 'Email address format is invalid. Please check and try again.');
  }

  const result = await validateWithReacher(normalized);
  return result.normalized;
}
