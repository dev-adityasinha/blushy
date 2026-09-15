import { db } from '../utils/db.js';

const ALLOWED_FEATURES = new Set(['shopping', 'doctor']);

function normalizeFeatureKey(featureKey) {
  const normalized = String(featureKey ?? '').trim().toLowerCase();
  return ALLOWED_FEATURES.has(normalized) ? normalized : null;
}

async function incrementFeatureClick(featureKey, userId) {
  const safeFeatureKey = normalizeFeatureKey(featureKey);
  if (!safeFeatureKey) {
    return null;
  }

  await db.collection('feature_click_counts').updateOne(
    { feature_key: safeFeatureKey, user_id: userId },
    {
      $inc: { click_count: 1 },
      $setOnInsert: { created_at: new Date() },
      $set: { updated_at: new Date() }
    },
    { upsert: true }
  );

  const row = await db.collection('feature_click_counts').findOne({
    feature_key: safeFeatureKey,
    user_id: userId
  });

  if (!row) {
    return null;
  }

  return {
    featureKey: row.feature_key,
    userId: row.user_id,
    userClickCount: Number(row.click_count ?? 0),
  };
}

async function getFeatureClickStats() {
  const totalsResult = await db.collection('feature_click_counts').aggregate([
    {
      $group: {
        _id: '$feature_key',
        total_clicks: { $sum: '$click_count' }
      }
    }
  ]).toArray();

  const usersResult = await db.collection('feature_click_counts')
    .find({})
    .sort({ feature_key: 1, click_count: -1, updated_at: -1 })
    .toArray();

  const stats = {
    shopping: { featureKey: 'shopping', totalClicks: 0, users: [] },
    doctor: { featureKey: 'doctor', totalClicks: 0, users: [] },
  };

  for (const doc of totalsResult) {
    const key = doc._id;
    if (stats[key]) {
      stats[key].totalClicks = Number(doc.total_clicks ?? 0);
    }
  }

  for (const doc of usersResult) {
    const key = doc.feature_key;
    if (stats[key]) {
      stats[key].users.push({
        userId: doc.user_id,
        clickCount: Number(doc.click_count ?? 0),
      });
    }
  }

  return Object.values(stats);
}

async function getFeatureTotalClicks(featureKey) {
  const safeFeatureKey = normalizeFeatureKey(featureKey);
  if (!safeFeatureKey) {
    return null;
  }

  const result = await db.collection('feature_click_counts').aggregate([
    { $match: { feature_key: safeFeatureKey } },
    {
      $group: {
        _id: null,
        total_clicks: { $sum: '$click_count' }
      }
    }
  ]).toArray();

  return Number(result[0]?.total_clicks ?? 0);
}

async function getUserActivityReport() {
  const totalUsers = await db.collection('users_man').countDocuments({}) + await db.collection('users_woman').countDocuments({});
  const onboardedUsers = await db.collection('users_man').countDocuments({ onboarding_completed_at: { $ne: null } }) + await db.collection('users_woman').countDocuments({ onboarding_completed_at: { $ne: null } });

  const featureColl = db.collection('feature_click_counts');
  const featureStats = await featureColl.aggregate([
    {
      $group: {
        _id: "$feature_key",
        totalClicks: { $sum: "$click_count" },
        uniqueUsers: { $addToSet: "$user_id" }
      }
    },
    { $project: { feature: "$_id", totalClicks: 1, uniqueUsersCount: { $size: "$uniqueUsers" } } },
    { $sort: { totalClicks: -1 } }
  ]).toArray();

  const totalMoodLogs = await db.collection('user_daily_moods_man').countDocuments({}) + await db.collection('user_daily_moods_woman').countDocuments({});
  const totalSleepLogs = await db.collection('user_sleep_logs_man').countDocuments({}) + await db.collection('user_sleep_logs_woman').countDocuments({});
  const totalNutritionPlans = await db.collection('user_nutrition_plans_man').countDocuments({}) + await db.collection('user_nutrition_plans_woman').countDocuments({});
  const partnerMessages = await db.collection('partner_chat_messages').countDocuments({});
  const communityFollowers = await db.collection('community_followers').countDocuments({});
  const feedbacks = await db.collection('user_feedbacks').countDocuments({});

  return {
    totalUsers,
    onboardedUsers,
    featureStats: featureStats.map(f => ({
      featureKey: f.feature,
      totalClicks: f.totalClicks,
      uniqueUsersCount: f.uniqueUsersCount
    })),
    totalMoodLogs,
    totalSleepLogs,
    totalNutritionPlans,
    partnerMessages,
    communityFollowers,
    feedbacks
  };
}

export const featureRepository = {
  incrementFeatureClick,
  getFeatureClickStats,
  getFeatureTotalClicks,
  normalizeFeatureKey,
  getUserActivityReport,
};
