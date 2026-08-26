import { env } from '../utils/env.js';
import { createHttpError } from '../utils/httpError.js';
import { logger } from '../utils/logger.js';

export function verifyCaptchaTokenPlaceholder(captchaToken) {
  if (!env.captchaEnabled) {
    return true;
  }

  if (!captchaToken) {
    throw createHttpError(400, 'CAPTCHA token is required when CAPTCHA is enabled.');
  }

  // Placeholder integration point for reCAPTCHA / hCaptcha / Turnstile.
  logger.info(`CAPTCHA placeholder accepted for provider=${env.captchaProvider}`);
  return true;
}