import jwt from 'jsonwebtoken';

import { env } from '../utils/env.js';
import { createHttpError } from '../utils/httpError.js';
import { userRepository } from '../repositories/userRepository.js';

export async function requireAuth(req, _res, next) {
  const authorization = req.get('authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) {
    return next(createHttpError(401, 'Authentication token required.'));
  }

  const token = authorization.slice('Bearer '.length).trim();
  if (!token) {
    return next(createHttpError(401, 'Authentication token required.'));
  }

  try {
    const decoded = jwt.verify(token, env.jwtSecret, {
      algorithms: ['HS256'],
    });

    if (!decoded?.userId) {
      return next(createHttpError(401, 'Invalid authentication token.'));
    }

    const dbUser = await userRepository.getUserById(decoded.userId);
    if (!dbUser) {
      return next(createHttpError(401, 'User account not found.'));
    }

    if (decoded.tokenVersion && decoded.tokenVersion !== dbUser.tokenVersion) {
      return next(createHttpError(401, 'Session revoked. Please sign in again.'));
    }

    req.user = decoded;
    return next();
  } catch {
    return next(createHttpError(401, 'Authentication session expired or invalid.'));
  }
}

export function requireRole(role) {
  return (req, _res, next) => {
    if (req.user?.role !== role) {
      return next(createHttpError(403, 'Insufficient permissions.'));
    }

    return next();
  };
}
