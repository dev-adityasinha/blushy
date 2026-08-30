import test from 'node:test';
import assert from 'node:assert/strict';

import { aiFetch } from '../src/utils/aiRequest.js';
import { env } from '../src/utils/env.js';

/**
 * Grok reasons by default, and measured against the real system prompt it
 * spent roughly 260 of 320 output tokens thinking before writing a chat reply
 * -- 4.1s against 1.3s, and 8.7s on the symptom path. Turning it off was as
 * informative or better every time, so the request must actually carry the
 * setting. A silently dropped flag would look identical except for being three
 * times slower.
 */
function captureRequest(handler) {
  const realFetch = globalThis.fetch;
  const seen = [];
  globalThis.fetch = async (url, options) => {
    seen.push({ url, options, body: JSON.parse(options.body) });
    return handler ? handler() : new Response('{}', { status: 200 });
  };
  return {
    seen,
    restore: () => {
      globalThis.fetch = realFetch;
    },
  };
}

test('ai request: reasoning is switched off by default', async () => {
  const cap = captureRequest();
  const previous = env.aiReasoningEnabled;
  env.aiReasoningEnabled = false;

  try {
    await aiFetch('https://example.test/v1/chat/completions', {
      method: 'POST',
      body: JSON.stringify({ model: 'x-ai/grok-4.3', messages: [] }),
    });

    assert.equal(cap.seen.length, 1);
    assert.deepEqual(cap.seen[0].body.reasoning, { enabled: false });
    // The rest of the payload must survive the rewrite untouched.
    assert.equal(cap.seen[0].body.model, 'x-ai/grok-4.3');
  } finally {
    env.aiReasoningEnabled = previous;
    cap.restore();
  }
});

test('ai request: reasoning can be turned back on from the environment', async () => {
  // The point of the flag is being able to revert without a deploy.
  const cap = captureRequest();
  const previous = env.aiReasoningEnabled;
  env.aiReasoningEnabled = true;

  try {
    await aiFetch('https://example.test/v1/chat/completions', {
      method: 'POST',
      body: JSON.stringify({ model: 'x-ai/grok-4.3', messages: [] }),
    });

    assert.equal(cap.seen[0].body.reasoning, undefined);
  } finally {
    env.aiReasoningEnabled = previous;
    cap.restore();
  }
});

test('ai request: every call carries an abort signal', async () => {
  // There was no timeout on any of the six call sites. A provider that accepts
  // the connection and then stalls would hold the request open indefinitely.
  const cap = captureRequest();

  try {
    await aiFetch('https://example.test/v1/chat/completions', {
      method: 'POST',
      body: JSON.stringify({ messages: [] }),
    });

    assert.ok(cap.seen[0].options.signal, 'no abort signal was attached');
    assert.ok(Number.isFinite(env.aiRequestTimeoutMs) && env.aiRequestTimeoutMs > 0);
  } finally {
    cap.restore();
  }
});

test('ai request: a body that cannot be parsed is passed through, not dropped', async () => {
  const cap = captureRequest();
  const previous = env.aiReasoningEnabled;
  env.aiReasoningEnabled = false;

  try {
    const realFetch = globalThis.fetch;
    let sentBody = null;
    globalThis.fetch = async (_url, options) => {
      sentBody = options.body;
      return new Response('{}', { status: 200 });
    };

    await aiFetch('https://example.test/v1/chat/completions', {
      method: 'POST',
      body: 'not json at all',
    });

    assert.equal(sentBody, 'not json at all');
    globalThis.fetch = realFetch;
  } finally {
    env.aiReasoningEnabled = previous;
    cap.restore();
  }
});
