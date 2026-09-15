import test from 'node:test';
import assert from 'node:assert/strict';

import { aiChatService } from '../src/services/aiChatService.js';

/**
 * The system prompt is sent on every Docsy message, and it is most of what
 * each message costs -- roughly 1,500 tokens before the user has said anything.
 * That makes it a standing target for trimming.
 *
 * Trimming is fine. Trimming a safety rule is not, and the difference is
 * invisible in a diff that only shows a shorter prompt. These lock down the
 * rules that must survive any future edit: the medication ban, the cycle-data
 * integrity block that stops Docsy inventing numbers, the hard bans, and the
 * crisis escalation.
 */

/** The system message actually put on the wire, with `fetch` stubbed out. */
async function systemPromptFor(aiContext = {}) {
  const realFetch = globalThis.fetch;
  let sent = null;

  globalThis.fetch = async (_url, options) => {
    sent = JSON.parse(options.body);
    return new Response(
      JSON.stringify({ choices: [{ message: { content: 'ok' } }], model: 'x-ai/grok-4.3' }),
      { status: 200, headers: { 'content-type': 'application/json' } },
    );
  };

  try {
    await aiChatService.createReply({
      messages: [{ role: 'user', content: 'hi' }],
      role: 'woman',
      user: { userId: 'test-user' },
      aiContext,
    });
  } finally {
    globalThis.fetch = realFetch;
  }

  return sent.messages.find((m) => m.role === 'system').content;
}

const REQUIRED = [
  ['medication names are banned', 'NEVER recommend, suggest, or mention specific medicine names'],
  ['cycle data is never invented', 'NEVER guess, invent, or extrapolate cycle day'],
  ['no percentage claims', 'Never state percentage reductions'],
  ['says so when data is thin', 'more daily check-ins or logged periods are needed'],
  ['not for contraception', 'not intended for contraception'],
  ['hard ban: minors', 'Minors, underage'],
  ['hard ban: coercion', 'Coercion, sexual assault'],
  ['hard ban: pseudoscience', 'Astrology, numerology'],
  ['hard ban: body shaming', 'Body shaming'],
  ['crisis escalation', 'seek immediate professional help'],
];

for (const [label, needle] of REQUIRED) {
  test(`docsy prompt keeps the rule: ${label}`, async () => {
    const prompt = await systemPromptFor();
    assert.ok(
      prompt.includes(needle),
      `a safety rule has gone missing from the system prompt: ${label}`,
    );
  });
}

test('voice-only guidance is not paid for on text messages', async () => {
  // This block was headed "VOICE & CHAT" and sent on every text message,
  // billing for instructions about being spoken aloud that could not apply.
  const text = await systemPromptFor({});
  const voice = await systemPromptFor({ isVoiceCall: true });

  assert.ok(!text.includes('spoken aloud'), 'voice guidance leaked into a text reply');
  assert.ok(voice.includes('spoken aloud'), 'voice guidance missing from a voice reply');
});

test('the prompt does not quietly grow back', async () => {
  // A budget, not a target. It was 6,738 characters before the duplicate
  // instructions were merged; this fails if it drifts far past that again,
  // which is the point at which someone should look rather than pay.
  const prompt = await systemPromptFor();
  assert.ok(
    prompt.length < 7000,
    `the system prompt is ${prompt.length} characters, sent on every message`,
  );
});

test('the same instruction is not stated twice', async () => {
  // Three lines used to tell Docsy to validate feelings first, and four to
  // keep the conversation going. Each restatement is paid for on every message.
  const prompt = await systemPromptFor();
  const lines = prompt.split('\n').map((l) => l.trim()).filter(Boolean);

  const validateFeelings = lines.filter((l) => /validate .*feelings/i.test(l));
  assert.equal(validateFeelings.length, 1,
    `"validate feelings" appears ${validateFeelings.length} times`);

  const wrapUp = lines.filter((l) => /wrap up|canned closing/i.test(l));
  assert.equal(wrapUp.length, 1, `"do not wrap up" appears ${wrapUp.length} times`);
});
