import { OAuth2Client } from 'google-auth-library';
import createHttpError from 'http-errors';
import { env } from '../utils/env.js';
import { userRepository } from '../repositories/userRepository.js';
import { signAccessToken } from './tokenService.js';
import { normalizeRole } from '../utils/role.js';

const clients = [];
if (env.googleClientIdWeb) {
  clients.push(new OAuth2Client(env.googleClientIdWeb));
}
if (env.googleClientIdAndroid) {
  clients.push(new OAuth2Client(env.googleClientIdAndroid));
}
if (env.googleClientIdIos) {
  clients.push(new OAuth2Client(env.googleClientIdIos));
}

if (clients.length === 0) {
  clients.push(new OAuth2Client());
}

async function verifyToken(token) {
  // If it's a JWT (has 3 parts):
  if (typeof token === 'string' && token.split('.').length === 3) {
    let payload = null;
    let error = null;

    for (const client of clients) {
      try {
        const ticket = await client.verifyIdToken({
          idToken: token,
          audience: [
            env.googleClientIdWeb,
            env.googleClientIdAndroid,
            env.googleClientIdIos
          ].filter(Boolean)
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
      return {
        sub: data.sub || data.user_id,
        email: data.email,
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

  let user = await userRepository.getUserByGoogleId(googleId);

  if (!user && email) {
    const existingUser = await userRepository.getUserByEmail(email);
    if (existingUser) {
      user = await userRepository.linkGoogleId(existingUser.user_id, googleId);
    }
  }

  if (!user) {
    const userRole = normalizeRole(role, 'woman');
    user = await userRepository.createUser({
      email,
      displayName,
      role: userRole,
      googleId,
      emailVerifiedAt: new Date().toISOString(),
    });
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
