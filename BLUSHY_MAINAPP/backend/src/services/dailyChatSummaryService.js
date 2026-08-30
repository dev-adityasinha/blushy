import { aiHistoryRepository } from '../repositories/aiHistoryRepository.js';
import { aiChatSummaryRepository } from '../repositories/aiChatSummaryRepository.js';
import { env } from '../utils/env.js';
import { logger } from '../utils/logger.js';

const IST_TIMEZONE = 'Asia/Kolkata';

function getIstDateParts(now = new Date()) {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: IST_TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  });

  const parts = formatter.formatToParts(now);
  const get = (type) => parts.find((part) => part.type === type)?.value ?? '';

  const year = get('year');
  const month = get('month');
  const day = get('day');
  const hour = Number(get('hour') || '0');
  const minute = Number(get('minute') || '0');

  return {
    dateKey: `${year}-${month}-${day}`,
    hour,
    minute,
  };
}

function shortLine(input, max = 180) {
  const value = typeof input === 'string' ? input.replace(/\s+/g, ' ').trim() : '';
  if (!value) {
    return '';
  }

  return value.length <= max ? value : `${value.slice(0, max)}...`;
}

function buildSummaryText(historyRows) {
  const rows = Array.isArray(historyRows) ? historyRows : [];
  if (rows.length === 0) {
    return 'No conversations recorded for this period.';
  }

  const userLines = rows
    .map((row) => shortLine(row.userMessage, 120))
    .filter((line) => line.length > 0);

  const assistantLines = rows
    .map((row) => shortLine(row.assistantMessage, 120))
    .filter((line) => line.length > 0);

  const lastUserMessage = userLines.at(-1) ?? '';
  const lastAssistantMessage = assistantLines.at(-1) ?? '';

  const keywordSet = new Set();
  const allUserText = userLines.join(' ').toLowerCase();
  const keywordMap = [
    ['mood', 'mood'],
    ['sleep', 'sleep'],
    ['cycle', 'cycle'],
    ['period', 'period'],
    ['stress', 'stress'],
    ['fertility', 'fertility'],
    ['pregnan', 'pregnancy'],
    ['nutrition', 'nutrition'],
    ['intimacy', 'intimacy'],
  ];

  for (const [token, label] of keywordMap) {
    if (allUserText.includes(token)) {
      keywordSet.add(label);
    }
  }

  const topics = [...keywordSet];
  const topicsText = topics.length > 0 ? topics.join(', ') : 'general wellbeing';

  return [
    `Turns: ${rows.length}.`,
    `Topics: ${topicsText}.`,
    lastUserMessage ? `Latest user intent: ${lastUserMessage}` : '',
    lastAssistantMessage ? `Latest assistant reply: ${lastAssistantMessage}` : '',
  ]
    .filter((part) => part.length > 0)
    .join(' ');
}

/**
 * Writes today's reflection for one user from the conversation so far.
 *
 * The nightly job was the only way a reflection could ever appear, so a
 * conversation held today produced nothing until after midnight IST -- while
 * the tab told people their letters would appear "once you have talked with
 * her". This is the on-demand path.
 *
 * It deliberately does NOT clear the history. Clearing belongs to the nightly
 * job, which summarises and then rolls the day over; doing it here would
 * delete the conversation the user is still having.
 */
export async function generateDailySummaryForUser(userKey, now = new Date()) {
  const { dateKey } = getIstDateParts(now);
  const history = await aiHistoryRepository.listHistory(userKey);

  if (!Array.isArray(history) || history.length === 0) {
    return null;
  }

  const summary = {
    userKey,
    role: history.at(-1)?.role ?? 'woman',
    summaryDateIst: dateKey,
    messageCount: history.length,
    firstMessageAt: history[0]?.createdAt ?? null,
    lastMessageAt: history.at(-1)?.createdAt ?? null,
    summaryText: buildSummaryText(history),
  };

  // Keyed on (userKey, date), so asking twice in a day updates today's
  // reflection rather than stacking duplicates.
  await aiChatSummaryRepository.upsertDailySummary(summary);
  return summary;
}

export async function runDailyChatSummaryOnce(now = new Date()) {
  const { dateKey } = getIstDateParts(now);
  const userKeys = await aiHistoryRepository.listUserKeysWithHistory();

  let summarizedUsers = 0;
  let clearedMessages = 0;

  for (const userKey of userKeys) {
    const history = await aiHistoryRepository.listHistory(userKey);
    if (!Array.isArray(history) || history.length === 0) {
      continue;
    }

    const role = history.at(-1)?.role ?? 'woman';
    const firstMessageAt = history[0]?.createdAt ?? null;
    const lastMessageAt = history.at(-1)?.createdAt ?? null;
    const summaryText = buildSummaryText(history);

    await aiChatSummaryRepository.upsertDailySummary({
      userKey,
      role,
      summaryDateIst: dateKey,
      messageCount: history.length,
      firstMessageAt,
      lastMessageAt,
      summaryText,
    });

    await aiHistoryRepository.clearHistory(userKey);

    summarizedUsers += 1;
    clearedMessages += history.length;
  }

  return {
    summaryDateIst: dateKey,
    summarizedUsers,
    clearedMessages,
  };
}

export function startDailyChatSummaryScheduler() {
  if (!env.dailyChatSummaryEnabled) {
    logger.info('Daily chat summary scheduler disabled by DAILY_CHAT_SUMMARY_ENABLED=false.');
    return () => {};
  }

  let lastRunDateKey = '';

  const tick = async () => {
    const now = new Date();
    const ist = getIstDateParts(now);

    if (lastRunDateKey === ist.dateKey) {
      return;
    }

    // Run once shortly after 12:00 AM IST.
    if (ist.hour !== 0 || ist.minute > 4) {
      return;
    }

    try {
      const result = await runDailyChatSummaryOnce(now);
      lastRunDateKey = ist.dateKey;
      logger.info(
        `Daily chat summary completed. date_ist=${result.summaryDateIst} users=${result.summarizedUsers} cleared_messages=${result.clearedMessages}`,
      );
    } catch (error) {
      logger.error(`Daily chat summary failed: ${error?.message ?? error}`);
    }
  };

  const timer = setInterval(() => {
    tick();
  }, 60 * 1000);

  tick();

  logger.info('Daily chat summary scheduler started (runs daily at 12:00 AM IST).');

  return () => {
    clearInterval(timer);
  };
}
