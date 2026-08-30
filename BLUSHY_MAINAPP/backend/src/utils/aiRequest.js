import { env } from './env.js';
import { logger } from './logger.js';

/**
 * Drop-in replacement for `fetch` against the chat-completions endpoint.
 *
 * Two things every call needs and none of the six call sites had:
 *
 * 1. A timeout. There was none, so a provider that accepted the connection and
 *    then stalled held the request open indefinitely, tying up a worker. On a
 *    single free-tier instance that is an availability problem, not just a
 *    slow reply.
 *
 * 2. A reasoning setting. Grok 4.3 reasons by default, and measured against
 *    the real system prompt it spent roughly 260 of 320 tokens thinking before
 *    writing a chat reply -- 4.1s versus 1.3s, and up to 8.7s on the symptom
 *    path. Turning it off was consistently as informative or better: the
 *    clinical answers came back citing actual values and naming specific
 *    causes, where the reasoning replies hedged.
 *
 * Kept behind AI_REASONING_ENABLED so it can be turned back on from the
 * environment without a deploy, per model or per incident.
 */
export async function aiFetch(url, options = {}) {
  let body = options.body;

  if (!env.aiReasoningEnabled && typeof body === 'string') {
    try {
      const parsed = JSON.parse(body);
      // `enabled: false` rather than `effort: 'low'`: low was measured and
      // barely honoured -- 274 reasoning tokens against 263 for the default.
      parsed.reasoning = { enabled: false };
      body = JSON.stringify(parsed);
    } catch {
      // A body we cannot parse is passed through untouched rather than dropped.
    }
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), env.aiRequestTimeoutMs);

  try {
    return await fetch(url, { ...options, body, signal: controller.signal });
  } catch (error) {
    if (error?.name === 'AbortError') {
      logger.warn(`AI request timed out after ${env.aiRequestTimeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}
