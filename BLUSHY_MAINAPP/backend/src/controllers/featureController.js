import { featureRepository } from '../repositories/featureRepository.js';
import { createHttpError } from '../utils/httpError.js';
import { logger } from '../utils/logger.js';

function requireAuthUser(req) {
  const userId = req.user?.userId;
  if (!userId) {
    throw createHttpError(401, 'Authentication required.');
  }
  return userId;
}

export async function trackFeatureClick(req, res, next) {
  try {
    const userId = requireAuthUser(req);
    const featureKey = String(req.params?.featureKey ?? '').trim().toLowerCase();

    const tracked = await featureRepository.incrementFeatureClick(featureKey, userId);
    if (!tracked) {
      throw createHttpError(400, 'Invalid feature key. Use shopping or doctor.');
    }

    const totalClicks = await featureRepository.getFeatureTotalClicks(featureKey);
    logger.info(
      `Feature click tracked: feature=${tracked.featureKey} userId=${tracked.userId} userClicks=${tracked.userClickCount} overallClicks=${totalClicks ?? 0}`,
    );

    res.status(200).json({ tracked });
  } catch (error) {
    next(error);
  }
}

export async function getFeatureClickStats(req, res, next) {
  try {
    requireAuthUser(req);
    const features = await featureRepository.getFeatureClickStats();
    
    // Log stats to terminal
    console.log('\n========== FEATURE CLICK STATISTICS ==========');
    for (const feature of features) {
      console.log(`\n📊 Feature: ${feature.featureKey.toUpperCase()}`);
      console.log(`   Total Clicks: ${feature.totalClicks}`);
      console.log(`   Unique Users: ${feature.users.length}`);
      if (feature.users.length > 0) {
        console.log('   User Breakdown:');
        feature.users.forEach((user, idx) => {
          console.log(`     ${idx + 1}. User ${user.userId}: ${user.clickCount} clicks`);
        });
      }
    }
    console.log('\n==============================================\n');
    
    res.status(200).json({ features });
  } catch (error) {
    next(error);
  }
}

export async function getUserActivityStats(req, res, next) {
  try {
    requireAuthUser(req);
    const report = await featureRepository.getUserActivityReport();
    res.status(200).json({ report });
  } catch (error) {
    next(error);
  }
}
