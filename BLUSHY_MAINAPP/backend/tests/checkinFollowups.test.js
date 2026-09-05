import test, { before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

import { startTestServer, stopTestServer, createTestUser, api } from './helpers/testServer.js';
import {
  validateCards,
  cacheKeyFor,
  clearCheckinFollowupCache,
  FOLLOWUP_METRICS,
} from '../src/services/checkinFollowupService.js';
import { env } from '../src/utils/env.js';

/**
 * Docsy's check-in cards.
 *
 * The model chooses and phrases the questions; the contract -- one metric
 * per card, answers the metric already stores, no findings about the
 * symptom -- is enforced here, not trusted.
 */

function modelReply(content) {
  return new Response(JSON.stringify({ choices: [{ message: { content }, finish_reason: 'stop' }] }), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });
}

test('validateCards keeps only cards that respect the contract', () => {
  const cards = validateCards([
    { metric: 'sleep', question: 'Did you sleep at least 7 hours?', yesValue: '7-8h', noValue: '<6h', becauseOf: ['Fatigue', 'Not logged'] },
    { metric: 'water', question: 'Did you drink about 2L today?', yesValue: '2L', noValue: '2L' }, // same answers
    { metric: 'blood_pressure', question: 'Was it high?', yesValue: 'High', noValue: 'Low' }, // unknown metric
    { metric: 'stress', question: 'Your cramps are caused by stress', yesValue: 'High', noValue: 'Low' }, // not a question
    { metric: 'exercise', question: 'Did you move or stretch today?', yesValue: 'Light', noValue: 'None' },
    { metric: 'exercise', question: 'Did you walk?', yesValue: 'Active', noValue: 'None' }, // repeat metric
    { metric: 'energy', question: 'Did your energy hold up?', yesValue: 'Fantastic', noValue: 'Low' }, // bad value
  ], ['Fatigue', 'Cramps']);

  assert.deepEqual(cards.map((c) => c.metric), ['sleep', 'exercise']);
  assert.equal(cards[0].id, 'ai_sleep');
  assert.deepEqual(cards[0].becauseOf, ['Fatigue'], 'only symptoms she actually logged');
});

test('never more than the cap, and every metric is a known one', () => {
  const many = Object.keys(FOLLOWUP_METRICS).map((metric) => ({
    metric,
    question: `Did you look after your ${metric} today?`,
    yesValue: FOLLOWUP_METRICS[metric][0],
    noValue: FOLLOWUP_METRICS[metric][1],
    becauseOf: [],
  }));
  const cards = validateCards(many, ['Fatigue']);
  assert.ok(cards.length <= 6);
  for (const c of cards) assert.ok(FOLLOWUP_METRICS[c.metric]);
});

test('the cache key does not care about order or case', () => {
  assert.equal(cacheKeyFor('u', '2026-09-05', ['Cramps', 'fatigue']), cacheKeyFor('u', '2026-09-05', ['Fatigue', 'cramps']));
  assert.notEqual(cacheKeyFor('u', '2026-09-05', ['Cramps']), cacheKeyFor('u', '2026-09-06', ['Cramps']));
});

let user;
let realFetch;
let realKey;

before(async () => {
  await startTestServer();
  user = await createTestUser({ role: 'woman' });
  realFetch = globalThis.fetch;
  realKey = env.aiChatApiKey;
  env.aiChatApiKey = env.aiChatApiKey || 'test-key';
});

after(async () => {
  globalThis.fetch = realFetch;
  env.aiChatApiKey = realKey;
  await stopTestServer();
});

beforeEach(() => clearCheckinFollowupCache());

function stubModel(handler) {
  globalThis.fetch = async (url, options) => {
    if (String(url).includes('/chat/completions') || String(url) === env.aiChatApiUrl) {
      return handler(url, options);
    }
    return realFetch(url, options);
  };
}

test('POST /ai/checkin-followups returns Docsy\'s cards for the logged symptoms', async () => {
  let prompt = '';
  stubModel(async (_url, options) => {
    prompt = JSON.parse(options.body).messages.at(-1).content;
    return modelReply('```json\n[' +
      '{"metric":"sleep","question":"Did you get at least 7 hours of sleep?","yesValue":"7-8h","noValue":"<6h","becauseOf":["Fatigue"]},' +
      '{"metric":"exercise","question":"Did you move a little today?","yesValue":"Light","noValue":"None","becauseOf":["Cramps"]},' +
      '{"metric":"nonsense","question":"Is it?","yesValue":"a","noValue":"b"}' +
      ']\n```');
  });

  const res = await api('POST', '/ai/checkin-followups', {
    token: user.token,
    body: { symptoms: ['Fatigue', 'Cramps'], date: '2026-09-05', stage: 'reproductiveYears' },
  });
  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.equal(res.body.source, 'docsy');
  assert.equal(res.body.date, '2026-09-05');
  assert.deepEqual(res.body.cards.map((c) => c.id), ['ai_sleep', 'ai_exercise']);
  assert.ok(prompt.includes('Fatigue') && prompt.includes('Cramps'), 'the symptoms reach the model');
});

test('the same symptoms on the same day do not ask the model twice', async () => {
  let calls = 0;
  stubModel(async () => {
    calls += 1;
    return modelReply('[{"metric":"water","question":"Did you drink about 2L?","yesValue":"2L","noValue":"1L","becauseOf":["Headache"]}]');
  });
  await api('POST', '/ai/checkin-followups', { token: user.token, body: { symptoms: ['Headache'], date: '2026-09-05' } });
  const again = await api('POST', '/ai/checkin-followups', { token: user.token, body: { symptoms: ['headache'], date: '2026-09-05' } });
  assert.equal(calls, 1);
  assert.equal(again.body.cards[0].id, 'ai_water');
});

test('a reply that is not JSON yields no cards, so the app uses its rules', async () => {
  stubModel(async () => modelReply('Sure! Here are some thoughts about sleep and water.'));
  const res = await api('POST', '/ai/checkin-followups', { token: user.token, body: { symptoms: ['Fatigue'], date: '2026-09-05' } });
  assert.equal(res.status, 200);
  assert.equal(res.body.source, 'none');
  assert.deepEqual(res.body.cards, []);
});

test('nothing logged asks the model nothing', async () => {
  let calls = 0;
  stubModel(async () => {
    calls += 1;
    return modelReply('[]');
  });
  const res = await api('POST', '/ai/checkin-followups', { token: user.token, body: { symptoms: [], date: '2026-09-05' } });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.cards, []);
  assert.equal(calls, 0);
});

test('it needs a signed-in user', async () => {
  const res = await api('POST', '/ai/checkin-followups', { body: { symptoms: ['Fatigue'] } });
  assert.equal(res.status, 401);
});
