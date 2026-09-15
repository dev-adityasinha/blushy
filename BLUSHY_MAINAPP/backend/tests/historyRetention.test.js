import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';

import { startTestServer, stopTestServer, createTestUser, api, getDb } from './helpers/testServer.js';

/**
 * What the app logs, the app keeps.
 *
 * Three separate paths were destroying the user's own records:
 *
 *   - the nightly chat summary wrote a one-line digest and then deleted every
 *     exchange, which is why Docsy could only ever show today;
 *   - getDailyMood, upsertDailyMood, getRecentDailyMoods and getMoodStreakDays
 *     each pruned mood entries older than thirty days, so simply opening the
 *     app destroyed the month before last;
 *   - sleepRepository carried the same prune at seven days, exported but never
 *     called -- a landmine rather than a live loss.
 *
 * These are the records Docsy reads to say anything about a pattern, so the
 * deletions were quietly capping how far back any insight could reach.
 */

let repos;

before(async () => {
  await startTestServer();
  // Dynamic, like the helper itself: utils/db.js connects at module load.
  const [history, mood, sleep, summaryService] = await Promise.all([
    import('../src/repositories/aiHistoryRepository.js'),
    import('../src/repositories/dailyMoodRepository.js'),
    import('../src/repositories/sleepRepository.js'),
    import('../src/services/dailyChatSummaryService.js'),
  ]);
  repos = {
    history: history.aiHistoryRepository,
    mood: mood.dailyMoodRepository,
    sleep: sleep.sleepRepository,
    runDailySummary: summaryService.runDailyChatSummaryOnce,
  };
});

after(async () => { await stopTestServer(); });

/** An ISO day-only string `days` before today. */
function daysAgoIso(days) {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - days);
  return d.toISOString().slice(0, 10);
}

async function userWithChat(exchanges = 2) {
  const user = await createTestUser({ role: 'woman' });
  const userKey = `user:${user.userId}`;
  for (let i = 0; i < exchanges; i += 1) {
    await repos.history.appendConversation({
      userKey,
      role: 'woman',
      userMessage: `question ${i}`,
      assistantMessage: `answer ${i}`,
      model: 'docsy',
    });
  }
  return { user, userKey };
}

test('the nightly summary keeps the conversation it summarises', async () => {
  const { userKey } = await userWithChat(3);

  const result = await repos.runDailySummary();
  assert.ok(result.summarizedUsers >= 1, 'the job should have run over this user');

  const rows = await repos.history.listHistory(userKey);
  assert.equal(rows.length, 3, 'the exchanges are still there after the rollover');
  assert.equal(rows[0].userMessage, 'question 0', 'oldest first, as the screen renders it');
});

test('the summary is still written, so the reflection tab keeps working', async () => {
  const { userKey } = await userWithChat(2);

  await repos.runDailySummary();

  const summary = await getDb()
    .collection('ai_chat_daily_summaries_woman')
    .findOne({ user_key: userKey });
  assert.ok(summary, 'a digest row should exist for the day');
  assert.ok(String(summary.summary_text ?? '').includes('Turns: 2'), summary.summary_text);
});

test('an exchange from a previous day is still returned', async () => {
  // The failure people actually saw: yesterday's conversation gone at midnight.
  const { user, userKey } = await userWithChat(1);
  const old = new Date();
  old.setUTCDate(old.getUTCDate() - 9);
  await getDb().collection('ai_chat_history_woman').insertOne({
    id: 'older-than-today',
    user_key: userKey,
    user_id: user.userId,
    role: 'woman',
    user_message: 'nine days ago',
    assistant_message: 'and answered then',
    model: 'docsy',
    created_at: old,
  });

  await repos.runDailySummary();

  const rows = await repos.history.listHistory(userKey);
  assert.ok(
    rows.some((r) => r.userMessage === 'nine days ago'),
    'history should reach past the last midnight',
  );
});

test('GET /ai/history serves the older exchanges too', async () => {
  const user = await createTestUser({ role: 'woman' });
  const old = new Date();
  old.setUTCDate(old.getUTCDate() - 30);
  await getDb().collection('ai_chat_history_woman').insertOne({
    id: 'a-month-back',
    user_key: `user:${user.userId}`,
    user_id: user.userId,
    role: 'woman',
    user_message: 'a month back',
    assistant_message: 'still readable',
    model: 'docsy',
    created_at: old,
  });

  const res = await api('GET', '/ai/history', { token: user.token });
  assert.equal(res.status, 200);
  assert.ok(
    (res.body.history ?? []).some((r) => r.userMessage === 'a month back'),
    'the endpoint should not be capped to the current day',
  );
});

test('a mood entry older than thirty days survives being read past', async () => {
  // Reading today's mood used to delete everything older than thirty days.
  const user = await createTestUser({ role: 'woman' });
  const longAgo = daysAgoIso(60);

  await repos.mood.upsertDailyMood({
    userId: user.userId,
    entryDate: longAgo,
    mood: 4,
    energyLevel: 3,
    stressLevel: 2,
    symptoms: ['cramps'],
    notes: 'logged two months ago',
  });

  await repos.mood.getDailyMood(user.userId);
  await repos.mood.getMoodStreakDays(user.userId);
  await repos.mood.getRecentDailyMoods(user.userId, 30);

  const still = await repos.mood.getDailyMood(user.userId, longAgo);
  assert.ok(still, 'the entry should outlive a read of a different day');
  assert.equal(still.notes, 'logged two months ago');
});

test('a year of mood can be asked for, not just a month', async () => {
  // The read cap was 30 regardless of what the caller asked for, which is what
  // any long-range insight would have to go through.
  const user = await createTestUser({ role: 'woman' });
  for (const back of [5, 45, 200]) {
    await repos.mood.upsertDailyMood({
      userId: user.userId,
      entryDate: daysAgoIso(back),
      mood: 3,
      energyLevel: 3,
      stressLevel: 3,
    });
  }

  const rows = await repos.mood.getRecentDailyMoods(user.userId, 365);
  assert.equal(rows.length, 3, 'all three entries, not only the recent one');
});

test('nothing prunes sleep logs any more', async () => {
  assert.equal(
    repos.sleep.pruneSleepHistory,
    undefined,
    'the seven-day prune is gone, not merely unused',
  );

  const user = await createTestUser({ role: 'woman' });
  const longAgo = daysAgoIso(20);
  await repos.sleep.upsertSleepByDate({
    userId: user.userId,
    entryDate: longAgo,
    sleepTime: '23:00',
    wakeTime: '07:00',
  });

  await repos.sleep.getSleepByDate(user.userId);

  const still = await repos.sleep.getSleepByDate(user.userId, longAgo);
  assert.ok(still, 'a sleep log from three weeks ago is still there');
});

test('the symptom log itself has no delete path at all', async () => {
  // user_daily_logs_* is where the Log Symptoms sheet writes. It has never had
  // a prune, and this pins that: a retention sweep added here later would be
  // the same bug in a third place.
  const { readFileSync } = await import('node:fs');
  const src = readFileSync(
    new URL('../src/repositories/dailyLogRepository.js', import.meta.url),
    'utf8',
  );
  assert.ok(!/delete(One|Many)\s*\(/.test(src), 'the daily log repository should never delete');
});
