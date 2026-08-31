import { friendRepository } from '../repositories/friendRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { createHttpError } from '../utils/httpError.js';

async function requireAuthUserAsync(req) {
  const userId = req.user?.userId;
  if (!userId) {
    throw createHttpError(401, 'Authentication required.');
  }

  // The auth middleware already read this record and checked it exists, so
  // this lookup was the same query a second time on every request. Only the
  // existence matters here, and that has been established.
  if (req.user?.verifiedAgainstDb) {
    return { userId };
  }

  const user = await userRepository.getUserById(userId);
  if (!user) {
    throw createHttpError(404, 'User not found.');
  }

  return { userId };
}

export async function searchUsers(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const queryText = String(req.query?.q ?? '').trim();
    if (queryText.length === 0) {
      return res.status(200).json({ users: [] });
    }

    const users = await friendRepository.searchUsers(queryText, auth.userId);
    res.status(200).json({ users });
  } catch (error) {
    next(error);
  }
}

export async function sendFriendRequest(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const recipientId = String(req.params?.recipientId ?? '').trim();

    if (auth.userId === recipientId) {
      throw createHttpError(400, 'You cannot send a friend request to yourself.');
    }

    const success = await friendRepository.sendFriendRequest(auth.userId, recipientId);
    if (!success) {
      throw createHttpError(400, 'Friend request already sent or users are already friends.');
    }

    res.status(200).json({ message: 'Friend request sent successfully.' });
  } catch (error) {
    next(error);
  }
}

export async function acceptFriendRequest(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const senderId = String(req.params?.senderId ?? '').trim();

    const success = await friendRepository.acceptFriendRequest(auth.userId, senderId);
    if (!success) {
      throw createHttpError(400, 'Friend request not found or already accepted.');
    }

    res.status(200).json({ message: 'Friend request accepted successfully.' });
  } catch (error) {
    next(error);
  }
}

export async function rejectFriendRequest(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const senderId = String(req.params?.senderId ?? '').trim();

    const success = await friendRepository.rejectFriendRequest(auth.userId, senderId);
    if (!success) {
      throw createHttpError(400, 'Friend request not found.');
    }

    res.status(200).json({ message: 'Friend request declined successfully.' });
  } catch (error) {
    next(error);
  }
}

export async function listFriends(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const friends = await friendRepository.listFriends(auth.userId);
    res.status(200).json({ friends });
  } catch (error) {
    next(error);
  }
}

export async function listPendingRequests(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const requests = await friendRepository.listPendingRequests(auth.userId);
    res.status(200).json({ requests });
  } catch (error) {
    next(error);
  }
}
