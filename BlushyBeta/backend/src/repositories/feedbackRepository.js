import crypto from 'node:crypto';
import { db } from '../utils/db.js';

export const feedbackRepository = {
  async insertFeedback(userId, message) {
    const feedbackId = crypto.randomUUID();
    const doc = {
      feedback_id: feedbackId,
      user_id: userId,
      message,
      created_at: new Date(),
    };
    await db.collection('user_feedbacks').insertOne(doc);
    return doc;
  },
};

