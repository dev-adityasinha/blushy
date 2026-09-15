import {
  acceptConsent,
  getConsentHistory,
  getConsentStatus,
  withdrawUserConsent,
} from '../services/consentService.js';
import { createHttpError } from '../utils/httpError.js';

/**
 * Consent endpoints.
 *
 * All four require a real authenticated user (`requireAuth`, never
 * `optionalAuth`). A consent record that cannot name whose consent it is has
 * no evidential value, so an unauthenticated caller must be refused rather
 * than quietly treated as nobody -- which is how most of the older `/me`
 * routes on this router behave.
 */

function requireUserId(req) {
  const userId = req.user?.userId;
  if (!userId) {
    throw createHttpError(401, 'Authentication required.');
  }
  return userId;
}

/**
 * The circumstances of the acceptance.
 *
 * Recorded because "who agreed, to what, when" is only half of what makes a
 * consent record defensible; the other half is being able to say where the
 * agreement came from. Client-supplied fields are length-capped: they arrive
 * from an app build that could be anything.
 */
function requestContext(req) {
  const cap = (value, max) => (typeof value === 'string' ? value.trim().slice(0, max) : null);

  return {
    ip: req.ip || req.headers['x-forwarded-for'] || req.socket?.remoteAddress || null,
    userAgent: cap(req.get('user-agent'), 300),
    appVersion: cap(req.body?.appVersion, 40),
    platform: cap(req.body?.platform, 20),
  };
}

export async function getMyConsent(req, res, next) {
  try {
    const status = await getConsentStatus(requireUserId(req));
    res.status(200).json({ success: true, ...status });
  } catch (error) {
    next(error);
  }
}

export async function acceptMyConsent(req, res, next) {
  try {
    const userId = requireUserId(req);

    const status = await acceptConsent(userId, {
      documents: req.body?.documents,
      method: typeof req.body?.method === 'string' ? req.body.method : 'onboarding',
      context: requestContext(req),
    });

    res.status(201).json({ success: true, ...status });
  } catch (error) {
    next(error);
  }
}

export async function withdrawMyConsent(req, res, next) {
  try {
    const userId = requireUserId(req);
    const reason = typeof req.body?.reason === 'string' ? req.body.reason.trim().slice(0, 500) : null;

    const status = await withdrawUserConsent(userId, reason || null);

    res.status(200).json({
      success: true,
      message: 'Consent withdrawn. Your data has not been deleted; to delete it, delete your account.',
      ...status,
    });
  } catch (error) {
    next(error);
  }
}

export async function getMyConsentHistory(req, res, next) {
  try {
    const history = await getConsentHistory(requireUserId(req));
    res.status(200).json({ success: true, history });
  } catch (error) {
    next(error);
  }
}
