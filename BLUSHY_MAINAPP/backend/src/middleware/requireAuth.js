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

    // Role is taken from the user record, not the token.
    //
    // Login signs `{userId, tokenVersion}` with no role, so `req.user.role`
    // was undefined for every normally signed-in user and `requireRole` could
    // never pass -- the admin surfaces were unreachable no matter what the
    // database said. Reading it here also means a role change takes effect on
    // the next request rather than waiting for a new token, which matters more
    // for revoking an admin than granting one.
    // verifiedAgainstDb tells handlers the record has already been read and
    // checked, so they need not read it again.
    req.user = { ...decoded, role: dbUser.role ?? decoded.role ?? null, verifiedAgainstDb: true };
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
