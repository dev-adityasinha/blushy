import { userStateRepository } from '../repositories/userStateRepository.js';
import { createHttpError } from '../utils/httpError.js';

function requireUserId(req) {
  const userId = req.user?.userId;
  if (!userId) {
    throw createHttpError(401, 'Authentication required.');
  }
  return userId;
}

/** Everything at once: a screen should not need a round trip per key. */
export async function getUserState(req, res, next) {
  try {
    const state = await userStateRepository.listForUser(requireUserId(req));
    res.status(200).json({ state });
  } catch (error) {
    next(error);
  }
}

export async function putUserState(req, res, next) {
  try {
    const userId = requireUserId(req);
    const key = String(req.params?.key ?? '');
    if (!userStateRepository.isValidKey(key)) {
      throw createHttpError(400, 'Invalid state key.');
    }

    if (!Object.prototype.hasOwnProperty.call(req.body ?? {}, 'value')) {
      throw createHttpError(400, 'A value is required.');
    }

    // Bounded: these are small screen documents, not a file store. Measured
    // against the largest of them with room to spare.
    const serialized = JSON.stringify(req.body.value ?? null);
    if (serialized.length > 256 * 1024) {
      throw createHttpError(413, 'That state document is too large (256KB limit).');
    }

    const result = await userStateRepository.putForUser(userId, key, req.body.value);
    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

export async function deleteUserState(req, res, next) {
  try {
    const userId = requireUserId(req);
    const key = String(req.params?.key ?? '');
    const deleted = await userStateRepository.removeForUser(userId, key);
    res.status(200).json({ deleted });
  } catch (error) {
    next(error);
  }
}
