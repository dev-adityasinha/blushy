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
export async function aiFetch(url, options = {}, meta = {}) {
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

  // Most calls want the shared budget. Discover does not: it is capped at
  // 16,000 output tokens and was measured taking 55 seconds, so the default
  // 30s would abort a request that was working. Callers that legitimately run
  // long pass their own budget rather than the helper having no limit at all.
  const timeoutMs = Number(meta.timeoutMs) > 0 ? Number(meta.timeoutMs) : env.aiRequestTimeoutMs;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, { ...options, body, signal: controller.signal });
    // Read the usage block off a clone. The caller still gets an unread body;
    // a Response can only be consumed once, so measuring must not be the thing
    // that consumes it. Deliberately not awaited -- recording a measurement
    // must never delay or fail the request being measured.
    recordUsageFrom(response.clone(), meta);
    return response;
  } catch (error) {
    if (error?.name === 'AbortError') {
      logger.warn(`AI request timed out after ${timeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Records what a completed call consumed, from a cloned response.
 *
 * Swallows everything. A provider that answers without a `usage` block, a body
 * that will not parse, an unreachable database -- none of those are reasons to
 * disturb a request that already succeeded.
 */
async function recordUsageFrom(clone, meta) {
  try {
    const payload = await clone.json();
    const usage = payload?.usage;
    if (!usage) return;

    // Imported here rather than at the top of the file. The repository pulls in
    // utils/db.js, which opens a MongoDB connection the moment it is loaded --
    // so a static import made every consumer of aiFetch, including the unit
    // tests that only stub fetch, connect to a database and then hang on an
    // open handle. Loaded only when there is something to record.
    const { recordAiUsage } = await import('../repositories/aiUsageRepository.js');

    await recordAiUsage({
      userId: meta.userId ?? null,
      feature: meta.feature ?? 'unknown',
      model: payload.model ?? meta.model ?? null,
      promptTokens: usage.prompt_tokens,
      completionTokens: usage.completion_tokens,
      totalTokens: usage.total_tokens,
    });
  } catch {
    // Measurement is best-effort by design.
  }
}
