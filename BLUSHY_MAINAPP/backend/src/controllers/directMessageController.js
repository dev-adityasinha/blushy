import { directMessageRepository } from '../repositories/directMessageRepository.js';
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

export async function listConversations(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const conversations = await directMessageRepository.listConversations(auth.userId);
    res.status(200).json({ conversations });
  } catch (error) {
    next(error);
  }
}

export async function listMessages(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const friendId = String(req.params?.friendId ?? '').trim();

    const messages = await directMessageRepository.listMessages(auth.userId, friendId);
    res.status(200).json({ messages });
  } catch (error) {
    next(error);
  }
}

export async function sendMessage(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const recipientId = String(req.params?.recipientId ?? '').trim();
    const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
    const rawImageUrl = typeof req.body?.imageUrl === 'string' ? req.body.imageUrl.trim() : '';
    const uploadedImage = req.file;

    if (text.length === 0 && !rawImageUrl && !uploadedImage) {
      throw createHttpError(400, 'Message content cannot be empty.');
    }

    const uploadedImageUrl = uploadedImage
      ? uploadedImage.storedUrl
      : null;

    const message = await directMessageRepository.addMessage({
      senderId: auth.userId,
      recipientId,
      text,
      imageUrl: uploadedImageUrl ?? (rawImageUrl.length > 0 ? rawImageUrl : null),
    });

    res.status(201).json({ message });
  } catch (error) {
    next(error);
  }
}
