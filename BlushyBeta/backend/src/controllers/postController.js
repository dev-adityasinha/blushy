import { postRepository } from '../repositories/postRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { createHttpError } from '../utils/httpError.js';

async function requireAuthUserAsync(req) {
  const userId = req.user?.userId;
  if (!userId) {
    throw createHttpError(401, 'Authentication required.');
  }

  const user = await userRepository.getUserById(userId);
  if (!user) {
    throw createHttpError(404, 'User not found.');
  }

  return { userId };
}

export async function createPost(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
    const rawImageUrl = typeof req.body?.imageUrl === 'string' ? req.body.imageUrl.trim() : '';
    const privacy = typeof req.body?.privacy === 'string' ? req.body.privacy.trim().toLowerCase() : 'public';
    const uploadedImage = req.file;

    if (text.length === 0 && !rawImageUrl && !uploadedImage) {
      throw createHttpError(400, 'Post content cannot be empty.');
    }

    const uploadedImageUrl = uploadedImage
      ? `${req.protocol}://${req.get('host')}/uploads/posts/${uploadedImage.filename}`
      : null;

    const post = await postRepository.createPost({
      authorId: auth.userId,
      text,
      imageUrl: uploadedImageUrl ?? (rawImageUrl.length > 0 ? rawImageUrl : null),
      privacy: privacy === 'private' ? 'private' : 'public',
    });

    res.status(201).json({ post });
  } catch (error) {
    next(error);
  }
}

export async function listFeed(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const posts = await postRepository.listFeed(auth.userId);
    res.status(200).json({ posts });
  } catch (error) {
    next(error);
  }
}
