import { createHttpError } from '../utils/httpError.js';
import { userRepository } from '../repositories/userRepository.js';
import { dailyMoodRepository } from '../repositories/dailyMoodRepository.js';
import { sleepRepository } from '../repositories/sleepRepository.js';
import { journalRepository } from '../repositories/journalRepository.js';
import { db } from '../utils/db.js';

function serializeUser(user) {
  return {
    userId: user.user_id,
    email: user.email ?? null,
    phoneNumber: user.phoneNumber ?? null,
    role: user.role,
    cycleStartDate: user.cycleStartDate ?? null,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

export async function getAllUsers(req, res, next) {
  try {
    const role = typeof req.query?.role === 'string' ? req.query.role.toLowerCase() : '';
    const limit = Math.min(Number(req.query?.limit ?? 100), 1000);
    const offset = Number(req.query?.offset ?? 0);

    if (!['woman', 'man', 'admin'].includes(role)) {
      throw createHttpError(400, 'Invalid role. Must be woman, man, or admin.');
    }

    const users = await userRepository.getUsersByRole(role, limit, offset);
    const total = await userRepository.countUsersByRole(role);

    res.status(200).json({
      users: users.map(serializeUser),
      total,
      limit,
      offset,
    });
  } catch (error) {
    next(error);
  }
}

export async function getUserById(req, res, next) {
  try {
    const userId = typeof req.params?.userId === 'string' ? req.params.userId.trim() : '';

    if (!userId) {
      throw createHttpError(400, 'User ID is required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    res.status(200).json({
      user: serializeUser(user),
    });
  } catch (error) {
    next(error);
  }
}

export async function getUserMoods(req, res, next) {
  try {
    const userId = typeof req.params?.userId === 'string' ? req.params.userId.trim() : '';
    const limit = Math.min(Number(req.query?.limit ?? 30), 500);

    if (!userId) {
      throw createHttpError(400, 'User ID is required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const moods = await dailyMoodRepository.getMoodsByUserId(userId, limit);

    res.status(200).json({
      moods: moods.map((mood) => ({
        date: mood.date,
        mood: mood.mood,
        energy: mood.energy,
        stress: mood.stress,
      })),
      total: moods.length,
    });
  } catch (error) {
    next(error);
  }
}

export async function getUserSleep(req, res, next) {
  try {
    const userId = typeof req.params?.userId === 'string' ? req.params.userId.trim() : '';
    const limit = Math.min(Number(req.query?.limit ?? 30), 500);

    if (!userId) {
      throw createHttpError(400, 'User ID is required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const sleepEntries = await sleepRepository.getSleepByUserId(userId, limit);

    res.status(200).json({
      sleep: sleepEntries.map((entry) => ({
        date: entry.date,
        sleepTime: entry.sleepTime,
        wakeTime: entry.wakeTime,
        durationMinutes: entry.durationMinutes,
      })),
      total: sleepEntries.length,
    });
  } catch (error) {
    next(error);
  }
}

export async function getUserPartner(req, res, next) {
  try {
    const userId = typeof req.params?.userId === 'string' ? req.params.userId.trim() : '';

    if (!userId) {
      throw createHttpError(400, 'User ID is required.');
    }

    const conn = await db.collection('partner_connections').findOne({
      $or: [{ user_a_id: userId }, { user_b_id: userId }],
      status: { $in: ['active', 'pending_sender_acceptance'] }
    });

    if (!conn) {
      return res.status(200).json({ partner: null });
    }

    const partnerId = conn.user_a_id === userId ? conn.user_b_id : conn.user_a_id;
    const partnerUser = await userRepository.getUserById(partnerId);

    res.status(200).json({
      partner: {
        connectionId: conn.connection_id,
        partnerId: partnerId,
        partnerEmail: partnerUser?.email ?? null,
        partnerPhone: partnerUser?.phoneNumber ?? null,
        partnerRole: partnerUser?.role ?? null,
        status: conn.status,
        connectedSince: conn.created_at ? new Date(conn.created_at).toISOString() : null,
      },
    });
  } catch (error) {
    next(error);
  }
}

export async function getUserAIChatSummary(req, res, next) {
  try {
    const userId = typeof req.params?.userId === 'string' ? req.params.userId.trim() : '';
    const limit = Math.min(Number(req.query?.limit ?? 10), 100);

    if (!userId) {
      throw createHttpError(400, 'User ID is required.');
    }

    const user = await userRepository.getUserById(userId);
    const role = user ? user.role : 'woman';
    const collectionName = `ai_chat_daily_summaries_${role}`;
    const userKey = `user:${userId}`;

    const summaries = await db.collection(collectionName)
      .find({ user_key: { $in: [userId, userKey] } })
      .sort({ summary_date_ist: -1 })
      .limit(limit)
      .toArray();

    res.status(200).json({
      summaries: summaries.map((row) => ({
        id: row.id || row._id.toString(),
        date: row.summary_date_ist,
        messageCount: row.message_count,
        firstMessageAt: row.first_message_at ? new Date(row.first_message_at).toISOString() : null,
        lastMessageAt: row.last_message_at ? new Date(row.last_message_at).toISOString() : null,
        summary: row.summary_text,
      })),
      total: summaries.length,
    });
  } catch (error) {
    next(error);
  }
}

export async function getUserFeedback(req, res, next) {
  try {
    const userId = typeof req.params?.userId === 'string' ? req.params.userId.trim() : '';
    const limit = Math.min(Number(req.query?.limit ?? 50), 500);

    if (!userId) {
      throw createHttpError(400, 'User ID is required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const feedbacks = await db.collection('user_feedbacks')
      .find({ user_id: userId })
      .sort({ created_at: -1 })
      .limit(limit)
      .toArray();

    res.status(200).json({
      feedbacks: feedbacks.map((row) => ({
        id: row.feedback_id || row._id.toString(),
        userId: row.user_id,
        message: row.message,
        createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
      })),
      total: feedbacks.length,
    });
  } catch (error) {
    next(error);
  }
}

export async function getUserJournal(req, res, next) {
  try {
    const userId = typeof req.params?.userId === 'string' ? req.params.userId.trim() : '';
    const limit = Math.min(Number(req.query?.limit ?? 100), 500);

    if (!userId) {
      throw createHttpError(400, 'User ID is required.');
    }

    const user = await userRepository.getUserById(userId);
    if (!user) {
      throw createHttpError(404, 'User not found.');
    }

    const journals = await journalRepository.getJournalsByUserId(userId, limit);

    res.status(200).json({
      journals,
      total: journals.length,
    });
  } catch (error) {
    next(error);
  }
}
