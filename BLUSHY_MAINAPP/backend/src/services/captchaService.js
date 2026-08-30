import { env } from '../utils/env.js';
import { createHttpError } from '../utils/httpError.js';
import { logger } from '../utils/logger.js';

/**
 * CAPTCHA is NOT implemented.
 *
 * There is no reCAPTCHA / hCaptcha / Turnstile integration here, and no route
 * calls this. The previous version returned `true` for any token whenever
 * CAPTCHA_ENABLED was set, so turning the flag on bought nothing while looking
 * like bot protection was active -- worse than having no control at all,
 * because it invites you to stop looking.
 *
 * It now fails closed: with the flag on and no provider integrated, requests
 * are refused rather than waved through. `assertCaptchaNotFalselyEnabled()`
 * (called at startup) makes that visible before any user hits it.
 */
export function isCaptchaImplemented() {
  // Flip this to true only alongside a real provider verification call below.
  return false;
}

export function verifyCaptchaToken(captchaToken) {
  if (!env.captchaEnabled) {
    return true;
  }

  if (!isCaptchaImplemented()) {
    logger.error(
      'CAPTCHA_ENABLED is true but no CAPTCHA provider is integrated. ' +
      'Refusing the request rather than accepting an unverified token.',
    );
    throw createHttpError(503, 'CAPTCHA verification is unavailable.', {
      code: 'CAPTCHA_NOT_IMPLEMENTED',
    });
  }

  if (!captchaToken) {
    throw createHttpError(400, 'CAPTCHA token is required when CAPTCHA is enabled.');
  }

  // Real provider verification would go here.
  throw createHttpError(503, 'CAPTCHA verification is unavailable.', {
    code: 'CAPTCHA_NOT_IMPLEMENTED',
  });
}

/**
 * Startup guard, so a misleading configuration is caught at boot rather than
 * by the first person who tries to sign up.
 */
export function assertCaptchaNotFalselyEnabled() {
  if (env.captchaEnabled && !isCaptchaImplemented()) {
    logger.error(
      `CAPTCHA_ENABLED=true with provider="${env.captchaProvider}", but no CAPTCHA ` +
      'provider is integrated. Nothing is being verified. Either integrate one in ' +
      'src/services/captchaService.js or set CAPTCHA_ENABLED=false.',
    );
  }
}
