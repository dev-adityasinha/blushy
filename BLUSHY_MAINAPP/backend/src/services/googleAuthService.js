import { OAuth2Client } from 'google-auth-library';
import createHttpError from 'http-errors';
import { env } from '../utils/env.js';
import { userRepository } from '../repositories/userRepository.js';
import { signAccessToken } from './tokenService.js';
import { normalizeRole } from '../utils/role.js';
import { emailService } from './emailService.js';
import { logger } from '../utils/logger.js';

/**
 * The client ids this server will accept a Google token for.
 *
 * A token is only proof of identity if it was minted for *us*. Anyone can get
 * a valid Google token for their own app; without an audience check it would
 * sign them in here as whoever it belongs to.
 */
const allowedAudiences = [
  env.googleClientIdWeb,
  env.googleClientIdAndroid,
  env.googleClientIdIos,
].filter(Boolean);

const clients = allowedAudiences.map((id) => new OAuth2Client(id));

/**
 * Refuses to verify anything when nothing is configured.
 *
 * This used to fall back to `new OAuth2Client()` and verify against an empty
 * audience list, which switches the audience check off: with the env vars
 * missing, a Google token issued to any other app in the world would have been
 * accepted. Failing closed turns a silent auth bypass into an obvious
 * misconfiguration.
 */
function assertConfigured() {
  if (allowedAudiences.length === 0) {
    logger.error(
      'Google sign-in is not configured: set GOOGLE_CLIENT_ID_WEB, ' +
      'GOOGLE_CLIENT_ID_ANDROID or GOOGLE_CLIENT_ID_IOS.',
    );
    throw createHttpError(503, 'Google sign-in is not available right now.');
  }
}

async function verifyToken(token) {
  assertConfigured();

  // If it's a JWT (has 3 parts):
  if (typeof token === 'string' && token.split('.').length === 3) {
    let payload = null;
    let error = null;

    for (const client of clients) {
      try {
        const ticket = await client.verifyIdToken({
          idToken: token,
          audience: allowedAudiences,
        });
        payload = ticket.getPayload();
        if (payload) break;
      } catch (e) {
        error = e;
      }
    }

    if (!payload) {
      throw createHttpError(401, `Invalid Google ID Token: ${error ? error.message : 'Unknown verification error'}`);
    }

    return payload;
  } else {
    // If it's a raw Access Token (fallback for web client environments):
    try {
      const response = await fetch(`https://oauth2.googleapis.com/tokeninfo?access_token=${token}`);
      if (!response.ok) {
        throw new Error(`Tokeninfo API returned HTTP status ${response.status}`);
      }
      const data = await response.json();
      if (!data.email) {
        throw new Error('Token payload does not contain a verified email.');
      }
      // tokeninfo reports which client the token was minted for. Without this
      // the fallback accepted an access token issued to any Google app, which
      // is the same bypass the ID token path guards against.
      if (!allowedAudiences.includes(data.aud)) {
        throw new Error('Token was issued for a different application.');
      }
      // Strings, not booleans, from this endpoint.
      if (String(data.email_verified) !== 'true') {
        throw new Error('Google has not verified this email address.');
      }
      return {
        sub: data.sub || data.user_id,
        email: data.email,
        email_verified: true,
        name: data.name || data.given_name || 'Blushy User',
      };
    } catch (e) {
      throw createHttpError(401, `Invalid Google Token: ${e.message}`);
    }
  }
}

export async function signInWithGoogle(idToken, role = 'woman') {
  if (typeof idToken !== 'string' || idToken.trim().length === 0) {
    throw createHttpError(400, 'Google ID Token is required.');
  }

  const payload = await verifyToken(idToken);
  const googleId = payload.sub;
  const email = payload.email;
  const displayName = payload.name || payload.given_name || 'Blushy User';

  if (!googleId) {
    throw createHttpError(400, 'Google ID token payload is missing the user subject ID.');
  }

  const requestedRole = normalizeRole(role, 'woman');

  let user = await userRepository.getUserByGoogleId(googleId);

  // Only an address Google has verified may be matched to an existing account.
  // Otherwise anyone could create a Google account claiming someone else's
  // email and be linked straight into their Blushy account.
  const emailIsVerified = payload.email_verified === true ||
    String(payload.email_verified) === 'true';

  if (!user && email && emailIsVerified) {
    const existingUser = await userRepository.getUserByEmail(email);
    if (existingUser) {
      user = await userRepository.linkGoogleId(existingUser.user_id, googleId);
    }
  }

  if (user) {
    const accountRole = normalizeRole(user.role, 'woman');
    if (requestedRole && requestedRole !== accountRole) {
      const accountRoleLabel = accountRole === 'woman' ? "a Woman's" : "a Partner/Man's";
      const correctExperience = accountRole === 'woman' ? "Woman" : "Partner";
      throw createHttpError(
        403,
        `This email is registered as ${accountRoleLabel} account. Please switch to the ${correctExperience} experience to sign in.`,
        { accountRole, requestedRole },
      );
    }
  } else {
    user = await userRepository.createUser({
      email,
      displayName,
      role: requestedRole,
      googleId,
      emailVerifiedAt: new Date().toISOString(),
    });

    // The other place an account first exists. Google verifies the address
    // itself, so there is no OTP step here to hang this off.
    try {
      await emailService.sendWelcome({ to: email, name: displayName ?? null });
    } catch (error) {
      logger.warn(`googleLogin: welcome email failed for ${email}: ${error?.message ?? error}`);
    }
  }

  const token = signAccessToken({ userId: user.user_id });

  return {
    message: 'Google login successful.',
    token,
    tokenType: 'Bearer',
    expiresIn: 604800,
    userId: user.user_id,
    role: user.role,
    email: user.email,
    displayName: user.displayName,
    cycleStartDate: user.cycleStartDate,
    onboardingCompleted: Boolean(user.onboardingCompletedAt || (user.onboardingAnswers && Object.keys(user.onboardingAnswers).length > 0) || user.cycleStartDate),
  };
}

export const googleAuthService = {
  signInWithGoogle
};
