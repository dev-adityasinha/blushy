/**
 * What a model charges, and what a recorded call therefore cost.
 *
 * Token counts are facts the provider returns; prices are not, and they change.
 * So the ledger stores counts and this turns them into money at read time --
 * correcting a stale price here re-prices history rather than leaving wrong
 * numbers baked into stored rows.
 *
 * Dependency-free like the rest of `domain/`, so the arithmetic is testable
 * without a database or a network call.
 */

/**
 * US dollars per million tokens.
 *
 * Verified against the OpenRouter model list on 10 September 2026. **Re-check
 * before quoting these figures**: providers reprice without notice, and a
 * number that is merely plausible is worse than no number at all.
 */
export const MODEL_PRICES_USD_PER_MILLION = Object.freeze({
  'x-ai/grok-4.3': { input: 1.25, output: 2.50 },
  'x-ai/grok-4.3:batch': { input: 1.00, output: 2.00 },
  'x-ai/grok-4.5': { input: 2.00, output: 6.00 },
  'x-ai/grok-4.6': { input: 2.00, output: 6.00 },
});

export const PRICES_VERIFIED_ON = '2026-09-10';

/**
 * The cost of one recorded call, or null when the model has no price here.
 *
 * Null rather than zero on purpose: an unpriced model is unknown, and folding
 * it in as free would quietly understate the bill.
 */
export function estimateCostUsd({ model, promptTokens = 0, completionTokens = 0 }) {
  const price = MODEL_PRICES_USD_PER_MILLION[model];
  if (!price) return null;

  const input = (Number(promptTokens) || 0) / 1_000_000 * price.input;
  const output = (Number(completionTokens) || 0) / 1_000_000 * price.output;
  return input + output;
}

/**
 * Totals a set of usage rows, keeping unpriced calls visible.
 *
 * @param {Array<{model: string, prompt_tokens: number, completion_tokens: number}>} rows
 */
export function summariseUsage(rows = []) {
  let promptTokens = 0;
  let completionTokens = 0;
  let costUsd = 0;
  let unpricedCalls = 0;

  for (const row of rows) {
    const p = Number(row?.prompt_tokens) || 0;
    const c = Number(row?.completion_tokens) || 0;
    promptTokens += p;
    completionTokens += c;

    const cost = estimateCostUsd({ model: row?.model, promptTokens: p, completionTokens: c });
    if (cost === null) unpricedCalls += 1;
    else costUsd += cost;
  }

  return {
    calls: rows.length,
    promptTokens,
    completionTokens,
    totalTokens: promptTokens + completionTokens,
    costUsd,
    unpricedCalls,
    pricesVerifiedOn: PRICES_VERIFIED_ON,
  };
}
