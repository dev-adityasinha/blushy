import jwt from 'jsonwebtoken';

import { env } from '../utils/env.js';
import { createHttpError } from '../utils/httpError.js';

export function signAccessToken(payload) {
  return jwt.sign(payload, env.jwtSecret, {
    algorithm: 'HS256',
    expiresIn: env.jwtExpiresIn,
  });
}

export function signRefreshToken(payload) {
  return jwt.sign({ ...payload, type: 'refresh' }, env.jwtSecret, {
    algorithm: 'HS256',
    expiresIn: env.refreshTokenExpiresIn,
  });
}

export function verifyRefreshToken(token) {
  try {
    const decoded = jwt.verify(token, env.jwtSecret, {
      algorithms: ['HS256'],
    });
    if (decoded?.type !== 'refresh') {
      throw createHttpError(401, 'Invalid refresh token type.');
    }
    return decoded;
  } catch (error) {
    if (error.statusCode === 401) {
      throw error;
    }
    throw createHttpError(401, 'Refresh token expired or invalid. Please sign in again.');
  }
}

export function signVerificationToken(payload) {
  return jwt.sign(payload, env.jwtSecret, {
    algorithm: 'HS256',
    expiresIn: '10m',
  });
}

export function verifyVerificationToken(token) {
  try {
    return jwt.verify(token, env.jwtSecret, {
      algorithms: ['HS256'],
    });
  } catch {
    throw createHttpError(401, 'Verification session expired. Please request a new verification code.');
  }
}
