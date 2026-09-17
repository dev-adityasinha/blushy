import assert from 'node:assert/strict';
import test, { before, after, mock } from 'node:test';
import { startTestServer, stopTestServer, api, createTestUser, getDb } from './helpers/testServer.js';

/**
 * Docsy's chat history has one job: what was said comes back next time.
 *
 * Reported as "the history isn't coming". The read path was blamed first, and
 * it was innocent -- `appendConversation` -> `ai_chat_history_woman` ->
 * `listHistory` -> `GET /ai/history` round-trips exactly, in the shape the app
 * parses. What the live database showed was 65 `docsy_chat` attempts since 28
 * July and not one saved exchange in that window.
 *
 * The saving is conditional on the reply: `createChatReply` only appends once
 * the model has answered, so a chat that fails after the provider call is
 * recorded as usage and stored nowhere. Usage is written at the moment of the
 * fetch, before the response is known, which is why the two counts disagree.
 *
 * These cover both halves, with the model stubbed so the suite never makes a
 * live call.
 */

before(async () => { await startTestServer(); });
after(async () => { await stopTestServer(); });

test('a SUCCESSFUL chat is saved to history', async () => {
  const { aiChatService } = await import('../src/services/aiChatService.js');
  mock.method(aiChatService, 'createReply', async () => ({
    message: 'Cramps in the luteal phase are common.', model: 'stub',
  }));

  const woman = await createTestUser({ role: 'woman' });
  const chat = await api('POST', '/ai/chat', {
    token: woman.token,
    body: {
      messages: [{ role: 'user', content: 'I have had cramps since yesterday.' }],
      message: 'I have had cramps since yesterday.',
      languageCode: 'en',
    },
  });
  console.log('   chat status:', chat.status);
  if (chat.status !== 200) console.log('   body:', JSON.stringify(chat.body).slice(0, 250));

  const db = getDb();
  console.log('   ai_chat_history_woman docs:', await db.collection('ai_chat_history_woman').countDocuments());
  const hist = await api('GET', '/ai/history', { token: woman.token });
  const rows = hist.body.history ?? [];
  console.log('   GET /ai/history rows:', rows.length);
  if (rows.length) console.log('   row:', JSON.stringify(rows[0]).slice(0, 180));

  assert.equal(chat.status, 200);
  assert.equal(rows.length, 1, 'a successful chat was still not saved');
});

test('a failed reply still records the question', async () => {
  const { aiChatService } = await import('../src/services/aiChatService.js');
  mock.method(aiChatService, 'createReply', async () => {
    const e = new Error('The AI provider returned an empty reply.');
    e.statusCode = 502;
    throw e;
  });

  const woman = await createTestUser({ role: 'woman' });
  const chat = await api('POST', '/ai/chat', {
    token: woman.token,
    body: { messages: [{ role: 'user', content: 'Is this normal?' }], message: 'Is this normal?' },
  });

  const hist = await api('GET', '/ai/history', { token: woman.token });
  const rows = hist.body.history ?? [];
  console.log('   rows after a failed chat:', rows.length, rows[0] ? JSON.stringify(rows[0]).slice(0, 160) : '');

  assert.notEqual(chat.status, 200, 'the stub should have failed the chat');
  assert.equal(rows.length, 1, 'her question was discarded with the failure');
  assert.equal(rows[0].userMessage, 'Is this normal?');
  assert.equal(rows[0].assistantMessage, null, 'there was no reply to record');
  assert.equal(rows[0].unanswered, true, 'the app needs to know this turn has no answer');
});

test('the error still reaches her -- saving the question does not swallow it', async () => {
  const { aiChatService } = await import('../src/services/aiChatService.js');
  mock.method(aiChatService, 'createReply', async () => {
    const e = new Error('The AI provider returned an empty reply.');
    e.statusCode = 502;
    throw e;
  });

  const woman = await createTestUser({ role: 'woman' });
  const chat = await api('POST', '/ai/chat', {
    token: woman.token,
    body: { messages: [{ role: 'user', content: 'Anything?' }], message: 'Anything?' },
  });
  assert.ok(chat.status >= 400, 'a failed chat must not report success');
});

test('a client can hand up exchanges the server never had', async () => {
  const woman = await createTestUser({ role: 'woman' });

  const res = await api('POST', '/ai/history/import', {
    token: woman.token,
    body: {
      exchanges: [
        { userMessage: 'Day one question', assistantMessage: 'Day one answer', at: '2026-09-15T10:00:00.000Z' },
        { userMessage: 'Day two question', assistantMessage: '', at: '2026-09-16T10:00:00.000Z' },
      ],
    },
  });
  console.log('   import:', res.status, JSON.stringify(res.body));

  const hist = await api('GET', '/ai/history', { token: woman.token });
  const rows = hist.body.history ?? [];
  console.log('   history rows:', rows.length);

  assert.equal(res.status, 200);
  assert.equal(res.body.imported, 2);
  assert.equal(rows.length, 2, 'both days should come back');
  assert.equal(rows[0].userMessage, 'Day one question', 'oldest first');
  assert.equal(rows[1].unanswered, true, 'the unanswered day keeps its flag');
});

test('re-importing the same conversation does not duplicate it', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const body = {
    exchanges: [
      { userMessage: 'Same question', assistantMessage: 'Same answer', at: '2026-09-15T10:00:00.000Z' },
    ],
  };

  const first = await api('POST', '/ai/history/import', { token: woman.token, body });
  const second = await api('POST', '/ai/history/import', { token: woman.token, body });
  const hist = await api('GET', '/ai/history', { token: woman.token });
  console.log('   imported first:', first.body.imported, '| second:', second.body.imported,
    '| rows:', (hist.body.history ?? []).length);

  assert.equal(first.body.imported, 1);
  assert.equal(second.body.imported, 0, 'the second import wrote nothing');
  assert.equal((hist.body.history ?? []).length, 1);
});

test('the import is bounded and scoped to the caller', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const other = await createTestUser({ role: 'woman' });

  const tooMany = await api('POST', '/ai/history/import', {
    token: woman.token,
    body: { exchanges: Array.from({ length: 301 }, () => ({ userMessage: 'x', assistantMessage: 'y' })) },
  });
  assert.equal(tooMany.status, 400, 'an unbounded import must be refused');

  await api('POST', '/ai/history/import', {
    token: woman.token,
    body: { exchanges: [{ userMessage: 'mine', assistantMessage: 'hers', at: '2026-09-15T10:00:00.000Z' }] },
  });
  const otherHist = await api('GET', '/ai/history', { token: other.token });
  assert.equal((otherHist.body.history ?? []).length, 0,
    'an import must never land in another account');
});
