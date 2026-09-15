import { db } from '../utils/db.js';
import { logger } from '../utils/logger.js';
import { summariseUsage } from '../domain/aiPricing.js';

/**
 * What each AI call actually consumed.
 *
 * Every chat-completions response carries a `usage` block -- `prompt_tokens`,
 * `completion_tokens`, `total_tokens` -- and nothing read it. The provider
 * dashboard held one aggregate number that could not be attributed to a user, a
 * feature or an endpoint, so there was no way to answer "what does Discover
 * cost us" or "which user is expensive" short of guessing.
 *
 * Counts only. No prompt, no reply, no health content -- the same rule
 * `auditRepository` follows: record that something happened and how big it was,
 * never what was in it.
 */

const COLLECTION = 'ai_usage_events';

function cleanUserId(userId) {
  return typeof userId === 'string' ? userId.replace(/^user:/, '') : userId;
}

/**
 * Records one call.
 *
 * Never throws and never awaits anything the caller depends on: failing to
 * record a measurement must not fail the request being measured.
 */
export async function recordAiUsage({
  userId = null,
  feature = 'unknown',
  model = null,
  promptTokens = 0,
  completionTokens = 0,
  totalTokens = null,
}) {
  try {
    const prompt = Number(promptTokens) || 0;
    const completion = Number(completionTokens) || 0;

    await db.collection(COLLECTION).insertOne({
      user_id: cleanUserId(userId),
      feature,
      model,
      prompt_tokens: prompt,
      completion_tokens: completion,
      total_tokens: Number(totalTokens) || prompt + completion,
      created_at: new Date(),
    });
  } catch (error) {
    logger.warn(`AI usage record failed (${feature}): ${error.message}`);
  }
}

/**
 * Spend since [since], broken down by feature.
 *
 * Sorted by cost so the expensive surface is the first thing read.
 */
export async function usageByFeature({ since = null, userId = null } = {}) {
  const query = {};
  if (since) query.created_at = { $gte: since };
  if (userId) query.user_id = cleanUserId(userId);

  try {
    const rows = await db.collection(COLLECTION).find(query).toArray();

    const byFeature = new Map();
    for (const row of rows) {
      const key = row.feature ?? 'unknown';
      if (!byFeature.has(key)) byFeature.set(key, []);
      byFeature.get(key).push(row);
    }

    const features = [...byFeature.entries()]
      .map(([feature, featureRows]) => ({ feature, ...summariseUsage(featureRows) }))
      .sort((a, b) => b.costUsd - a.costUsd);

    return { total: summariseUsage(rows), features };
  } catch (error) {
    logger.warn(`AI usage query failed: ${error.message}`);
    return { total: summariseUsage([]), features: [] };
  }
}
