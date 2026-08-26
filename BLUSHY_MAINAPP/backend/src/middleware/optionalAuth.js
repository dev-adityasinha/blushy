import jwt from 'jsonwebtoken';

import { env } from '../utils/env.js';
import { userRepository } from '../repositories/userRepository.js';

export async function optionalAuth(req, _res, next) {
  const authorization = req.get('authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) {
    return next();
  }

  const token = authorization.slice('Bearer '.length).trim();
  if (!token) {
    return next();
  }

  try {
    const decoded = jwt.verify(token, env.jwtSecret, {
      algorithms: ['HS256'],
    });

    if (decoded?.userId) {
      const dbUser = await userRepository.getUserById(decoded.userId);
      if (dbUser && (!decoded.tokenVersion || decoded.tokenVersion === dbUser.tokenVersion)) {
        req.user = decoded;
      } else {
        req.user = null;
      }
    } else {
      req.user = null;
    }
  } catch {
    req.user = null;
  }

  return next();
}
