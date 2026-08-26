import { feedbackRepository } from '../repositories/feedbackRepository.js';
import { createHttpError } from '../utils/httpError.js';
import { userRepository } from '../repositories/userRepository.js';

export async function submitFeedback(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const message = req.body?.message;
    if (typeof message !== 'string' || message.trim().length === 0) {
      throw createHttpError(400, 'Message is required.');
    }

    if (message.length > 2000) {
      throw createHttpError(400, 'Message cannot exceed 2000 characters.');
    }

    const feedback = await feedbackRepository.insertFeedback(userId, message.trim());
    
    res.status(200).json({
      success: true,
      feedback,
    });
  } catch (error) {
    next(error);
  }
}
