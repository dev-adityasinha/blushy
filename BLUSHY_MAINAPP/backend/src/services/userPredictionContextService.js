import { aiHistoryRepository } from '../repositories/aiHistoryRepository.js';
import { dailyMoodRepository } from '../repositories/dailyMoodRepository.js';
import { partnerRepository } from '../repositories/partnerRepository.js';
import { sleepRepository } from '../repositories/sleepRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { journalRepository } from '../repositories/journalRepository.js';
import { calculatePeriodPredictions } from './periodPredictionService.js';

const MOOD_TO_SCORE = {
  great: 5,
  okay: 4,
  low: 2,
  anxious: 2,
  irritated: 2,
};

function addDays(date, days) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

function clamp(min, value, max) {
  return Math.max(min, Math.min(max, value));
}

function average(values) {
  if (!Array.isArray(values) || values.length === 0) {
    return null;
  }

  const sum = values.reduce((acc, value) => acc + value, 0);
  return sum / values.length;
}

function toMinutes(timeString) {
  if (typeof timeString !== 'string') {
    return null;
  }

  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(timeString.trim());
  if (!match) {
    return null;
  }

  return (Number(match[1]) * 60) + Number(match[2]);
}

function minutesToTime(totalMinutes) {
  const safeMinutes = ((Math.round(totalMinutes) % 1440) + 1440) % 1440;
  const hours = Math.floor(safeMinutes / 60);
  const minutes = safeMinutes % 60;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

function moodFromScore(score) {
  if (score >= 4.5) {
    return 'great';
  }
  if (score >= 3.5) {
    return 'okay';
  }
  if (score >= 2.5) {
    return 'low';
  }
  return 'anxious';
}

function buildMoodForecast(moods) {
  const sorted = Array.isArray(moods)
    ? [...moods].sort((a, b) => String(a.entryDate).localeCompare(String(b.entryDate)))
    : [];

  const recent = sorted.slice(-7);
  const scores = recent
    .map((entry) => MOOD_TO_SCORE[entry.mood])
    .filter((value) => typeof value === 'number');

  const baseline = average(scores) ?? 3.8;
  const lastScore = scores.length > 0 ? scores[scores.length - 1] : baseline;
  const delta = clamp(-0.4, (lastScore - baseline) * 0.35, 0.4);

  const predictions = [1, 2, 3].map((offset) => {
    const projectedScore = clamp(1.5, baseline + delta * (1 - offset * 0.2), 5);
    const date = addDays(new Date(), offset);

    return {
      date: isoDate(date),
      predictedMood: moodFromScore(projectedScore),
      confidence: scores.length >= 5 ? 'high' : (scores.length >= 2 ? 'medium' : 'low'),
    };
  });

  return predictions;
}

function buildSleepForecast(sleepLogs) {
  const logs = Array.isArray(sleepLogs) ? sleepLogs : [];
  const durations = logs.map((entry) => Number(entry.durationMinutes) || 0).filter((value) => value > 0);
  const sleepTimes = logs.map((entry) => toMinutes(entry.sleepTime)).filter((value) => value != null);
  const wakeTimes = logs.map((entry) => toMinutes(entry.wakeTime)).filter((value) => value != null);

  const avgDuration = Math.round(average(durations) ?? 480);
  const avgSleep = average(sleepTimes) ?? 22.5 * 60;
  const avgWake = average(wakeTimes) ?? 6.5 * 60;

  return {
    averageDurationMinutes: avgDuration,
    predictedSleepTime: minutesToTime(avgSleep),
    predictedWakeTime: minutesToTime(avgWake),
    next3Days: [1, 2, 3].map((offset) => ({
      date: isoDate(addDays(new Date(), offset)),
      predictedSleepTime: minutesToTime(avgSleep),
      predictedWakeTime: minutesToTime(avgWake),
      predictedDurationMinutes: avgDuration,
    })),
  };
}

function compactAiHistory(history) {
  const rows = Array.isArray(history) ? history : [];
  return rows.slice(-40).map((entry) => ({
    createdAt: entry.createdAt,
    role: entry.role,
    userMessage: typeof entry.userMessage === 'string' ? entry.userMessage.slice(0, 280) : '',
    assistantMessage: typeof entry.assistantMessage === 'string' ? entry.assistantMessage.slice(0, 280) : '',
  }));
}

function buildOverallOutlook({ moodForecast, sleepForecast, cycleForecast }) {
  const moodTop = moodForecast?.[0]?.predictedMood ?? 'okay';
  const sleepHours = Math.round((sleepForecast?.averageDurationMinutes ?? 480) / 60);

  if (moodTop === 'great' && sleepHours >= 7) {
    return 'Stable and positive trend is likely over the next few days.';
  }

  if (moodTop === 'anxious' || sleepHours < 6) {
    return 'Possible low-energy or stress-prone days ahead; suggest lighter schedules and recovery time.';
  }

  if (cycleForecast && cycleForecast.hasData) {
    if (cycleForecast.currentCycle?.isCurrentPeriod) {
      return `Currently on period Day ${cycleForecast.currentCycle.periodDay} of ${cycleForecast.currentCycle.periodDurationDays}. Prioritize rest, hydration, and comfort.`;
    }
    if (cycleForecast.currentCycle?.isOverdue) {
      return `Current cycle is overdue by ${cycleForecast.currentCycle.daysOverdue} days. Log your period when it arrives.`;
    }
    return `Moderate trend expected; current phase is ${cycleForecast.currentCycle?.phase}. Estimated milestones around ${cycleForecast.prediction?.estimatedOvulationDate} and ${cycleForecast.prediction?.nextPeriodStartDate}.`;
  }

  return 'Mixed trend expected; continue tracking daily logs for better prediction confidence.';
}

class UserPredictionContextService {
  async buildUserPredictionContext({ userId, userKey, role, timezone }) {
    const [
      user,
      onboarding,
      moods,
      sleepLogs,
      aiHistory,
      connections,
      journals,
      cycleForecast,
    ] = await Promise.all([
      userRepository.getUserById(userId),
      userRepository.getOnboardingAnswers(userId),
      dailyMoodRepository.getRecentDailyMoods(userId, 30),
      sleepRepository.getRecentSleepLogs(userId, 7),
      aiHistoryRepository.listHistory(userKey),
      partnerRepository.listConnectionsForUser(userId),
      journalRepository.getJournalsByUserId(userId, 5).catch(() => []),
      role === 'woman' ? calculatePeriodPredictions(userId, { timezone }) : Promise.resolve(null),
    ]);

    const safeMoods = Array.isArray(moods)
      ? moods.filter((entry) => entry?.userId === userId)
      : [];
    const safeSleepLogs = Array.isArray(sleepLogs)
      ? sleepLogs.filter((entry) => entry?.userId === userId)
      : [];
    const safeConnections = Array.isArray(connections)
      ? connections.filter((entry) => entry?.userAId === userId || entry?.userBId === userId)
      : [];
    const safeJournals = Array.isArray(journals) ? journals : [];

    const moodForecast = buildMoodForecast(safeMoods);
    const sleepForecast = buildSleepForecast(safeSleepLogs);

    const predictions = {
      moodForecast,
      sleepForecast,
      cycleForecast,
      overallOutlook: buildOverallOutlook({ moodForecast, sleepForecast, cycleForecast }),
      generatedAt: new Date().toISOString(),
    };

    return {
      userProfile: {
        userId: user?.user_id ?? userId,
        role: user?.role ?? role,
        email: user?.email ?? null,
        phoneNumber: user?.phoneNumber ?? null,
        cycleStartDate: user?.cycleStartDate ?? null,
        onboardingCompletedAt: user?.onboardingCompletedAt ?? null,
      },
      predictionScope: {
        mode: 'user-only',
        userId,
      },
      onboardingAnswers: onboarding?.onboardingAnswers ?? {},
      moodHistory: safeMoods,
      sleepHistory: safeSleepLogs,
      journals: safeJournals,
      aiConversationHistory: compactAiHistory(aiHistory),
      partnerConnections: safeConnections,
      predictions,
    };
  }

  summarizeForPrompt(context) {
    if (!context || typeof context !== 'object') {
      return '';
    }

    const cycle = context.predictions?.cycleForecast;
    let cycleSummaryText = 'No cycle data recorded.';
    if (cycle && cycle.hasData) {
      const cur = cycle.currentCycle || {};
      const pred = cycle.prediction || {};
      const suff = cycle.dataSufficiency || {};

      let periodStatus;
      if (cur.isOverdue) {
        periodStatus = `OVERDUE CYCLE: Day ${cur.currentCycleDay} (${cur.daysOverdue} days past typical length). Phase: ${cur.phase}.`;
      } else if (cur.isCurrentPeriod) {
        periodStatus = `CURRENTLY ON PERIOD: Day ${cur.periodDay} of ${cur.periodDurationDays} (Day ${cur.currentCycleDay} of cycle).`;
      } else {
        periodStatus = `CURRENT CYCLE DAY: Day ${cur.currentCycleDay}. Phase: ${cur.phase}.`;
      }

      const countdownText = cur.isOverdue 
        ? 'Overdue / Awaiting Period' 
        : (pred.daysUntilNextPeriod != null ? `in ${pred.daysUntilNextPeriod} days` : 'Estimated');

      cycleSummaryText = `CANONICAL CYCLE DATA (DO NOT GUESS OR INVENT):
- Status: ${periodStatus}
- Current Phase: ${cur.phase}
- Latest Confirmed Period Start: ${cur.latestConfirmedPeriodStartDate}
- Next Period Estimate: ${pred.nextPeriodStartDate || 'Overdue / Awaiting Period'} (${countdownText})
- Estimated Ovulation Date: ${pred.estimatedOvulationDate || 'Uncertain / Past'}
- Fertile Window: ${pred.fertileWindowStart || 'N/A'} to ${pred.fertileWindowEnd || 'N/A'}
- Data Sufficiency: ${suff.displayLabel} (${suff.message})
- Disclaimer: ${pred.disclaimer || 'Predictions are estimates and are not intended for contraception or medical diagnosis.'}`;
    }

    const basePayload = {
      userProfile: context.userProfile,
      onboardingAnswers: context.onboardingAnswers,
      cycleStatusSummary: cycleSummaryText,
      moodHistory: Array.isArray(context.moodHistory)
        ? context.moodHistory.slice(-14).map((entry) => ({
            entryDate: entry.entryDate,
            mood: entry.mood,
            energyLevel: entry.energyLevel,
            stressLevel: entry.stressLevel,
          }))
        : [],
      sleepHistory: Array.isArray(context.sleepHistory)
        ? context.sleepHistory.slice(-7).map((entry) => ({
            entryDate: entry.entryDate,
            sleepTime: entry.sleepTime,
            wakeTime: entry.wakeTime,
            durationMinutes: entry.durationMinutes,
          }))
        : [],
      journals: Array.isArray(context.journals)
        ? context.journals.slice(0, 5).map((entry) => ({
            date: entry.date,
            summary: entry.summary,
            entries: entry.entries,
          }))
        : [],
      aiConversationHistory: Array.isArray(context.aiConversationHistory)
        ? context.aiConversationHistory.slice(-8)
        : [],
      partnerConnections: Array.isArray(context.partnerConnections)
        ? context.partnerConnections.slice(0, 5).map((entry) => ({
            connectionId: entry.connectionId,
            userAId: entry.userAId,
            userBId: entry.userBId,
            status: entry.status,
            permissions: entry.permissions,
          }))
        : [],
      predictions: context.predictions,
      contextGeneratedAt: context?.predictions?.generatedAt ?? new Date().toISOString(),
    };

    let raw = JSON.stringify(basePayload);
    if (raw.length <= 12000) {
      return raw;
    }

    const smallerPayload = {
      userProfile: basePayload.userProfile,
      onboardingAnswers: basePayload.onboardingAnswers,
      cycleStatusSummary: cycleSummaryText,
      moodHistory: basePayload.moodHistory.slice(-7),
      sleepHistory: basePayload.sleepHistory.slice(-5),
      journals: basePayload.journals.slice(0, 3),
      aiConversationHistory: basePayload.aiConversationHistory.slice(-4),
      partnerConnections: basePayload.partnerConnections.slice(0, 2),
      predictions: basePayload.predictions,
      contextGeneratedAt: basePayload.contextGeneratedAt,
    };

    raw = JSON.stringify(smallerPayload);
    if (raw.length <= 12000) {
      return raw;
    }

    const minimalPayload = {
      userProfile: smallerPayload.userProfile,
      onboardingAnswers: smallerPayload.onboardingAnswers,
      cycleStatusSummary: cycleSummaryText,
      moodHistory: smallerPayload.moodHistory.slice(-3),
      sleepHistory: smallerPayload.sleepHistory.slice(-3),
      predictions: smallerPayload.predictions,
      contextGeneratedAt: smallerPayload.contextGeneratedAt,
    };

    return JSON.stringify(minimalPayload);
  }
}

export const userPredictionContextService = new UserPredictionContextService();