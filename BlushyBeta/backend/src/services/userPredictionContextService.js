import { aiHistoryRepository } from '../repositories/aiHistoryRepository.js';
import { dailyMoodRepository } from '../repositories/dailyMoodRepository.js';
import { partnerRepository } from '../repositories/partnerRepository.js';
import { sleepRepository } from '../repositories/sleepRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { journalRepository } from '../repositories/journalRepository.js';

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

function parseCycleLength(onboardingAnswers) {
  if (!onboardingAnswers || typeof onboardingAnswers !== 'object' || Array.isArray(onboardingAnswers)) {
    return 28;
  }

  const candidates = [
    onboardingAnswers.cycle_length,
    onboardingAnswers.cycleLength,
    onboardingAnswers.period_cycle_length,
    onboardingAnswers.cycle_usual_length_days,
    onboardingAnswers.cycle_frequency_days,
  ];

  for (const candidate of candidates) {
    const numeric = Number(candidate);
    if (Number.isFinite(numeric) && numeric >= 18 && numeric <= 60) {
      return Math.round(numeric);
    }
  }

  return 28;
}

function buildMoodForecast(moods) {
  const sorted = Array.isArray(moods)
    ? [...moods].sort((a, b) => String(a.entryDate).localeCompare(String(b.entryDate)))
    : [];

  const recent = sorted.slice(-7);
  const moodScores = recent
    .map((entry) => MOOD_TO_SCORE[entry.mood] ?? null)
    .filter((value) => typeof value === 'number');
  const energyScores = recent
    .map((entry) => {
      if (entry.energyLevel === 'high') return 5;
      if (entry.energyLevel === 'medium') return 3;
      if (entry.energyLevel === 'low') return 1;
      return null;
    })
    .filter((value) => typeof value === 'number');
  const stressScores = recent
    .map((entry) => {
      if (entry.stressLevel === 'high') return 5;
      if (entry.stressLevel === 'medium') return 3;
      if (entry.stressLevel === 'low') return 1;
      return null;
    })
    .filter((value) => typeof value === 'number');

  const moodAvg = average(moodScores) ?? 3.5;
  const energyAvg = average(energyScores) ?? 3;
  const stressAvg = average(stressScores) ?? 3;

  const combined = clamp(1, (moodAvg * 0.55) + (energyAvg * 0.25) + ((6 - stressAvg) * 0.2), 5);
  const confidence = clamp(0.35, (recent.length / 7) * 0.9, 0.9);

  return [1, 2, 3].map((offset) => ({
    date: isoDate(addDays(new Date(), offset)),
    predictedMood: moodFromScore(combined),
    predictedEnergy: combined >= 4 ? 'high' : combined >= 2.8 ? 'medium' : 'low',
    predictedStress: combined >= 4 ? 'low' : combined >= 2.8 ? 'medium' : 'high',
    confidence,
  }));
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

function buildCycleForecast(user, onboardingAnswers) {
  const rawStartStr = onboardingAnswers?.last_period ||
    onboardingAnswers?.last_period_date ||
    onboardingAnswers?.cycle_start_date ||
    user?.cycleStartDate ||
    onboardingAnswers?.period_last_start_date ||
    onboardingAnswers?.cycle_last_period_start;

  const rawStart = rawStartStr ? new Date(rawStartStr) : null;

  if (!rawStart || Number.isNaN(rawStart.getTime())) {
    return null;
  }

  const cycleLength = parseCycleLength(onboardingAnswers);
  const rawDuration = Number(onboardingAnswers?.period_duration_days || onboardingAnswers?.cycle_last_period_duration_days);
  const periodLength = Number.isFinite(rawDuration) && rawDuration >= 2 && rawDuration <= 10 ? Math.round(rawDuration) : 5;

  const today = new Date();
  const todayNormalized = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const startNormalized = new Date(rawStart.getFullYear(), rawStart.getMonth(), rawStart.getDate());

  let currentCycleStart = new Date(startNormalized);
  if (startNormalized <= todayNormalized) {
    const diffMs = todayNormalized.getTime() - startNormalized.getTime();
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const cyclesElapsed = Math.floor(diffDays / cycleLength);
    currentCycleStart = addDays(startNormalized, cyclesElapsed * cycleLength);
  }

  const currentCycleDay = Math.floor((todayNormalized.getTime() - currentCycleStart.getTime()) / (1000 * 60 * 60 * 24)) + 1;
  const isCurrentPeriod = currentCycleDay >= 1 && currentCycleDay <= periodLength;
  const periodDay = isCurrentPeriod ? currentCycleDay : null;

  const nextPeriodStart = addDays(currentCycleStart, cycleLength);
  const daysUntilNextPeriod = Math.round((nextPeriodStart.getTime() - todayNormalized.getTime()) / (1000 * 60 * 60 * 24));

  const ovulationDate = addDays(nextPeriodStart, -14);
  const fertileWindowStart = addDays(ovulationDate, -5);
  const fertileWindowEnd = addDays(ovulationDate, 1);

  let currentPhase = 'Safe Phase';
  if (isCurrentPeriod) {
    currentPhase = `Menstrual Phase (Period Day ${currentCycleDay} of ${periodLength})`;
  } else if (todayNormalized >= fertileWindowStart && todayNormalized <= fertileWindowEnd) {
    const isOvulationDay = isoDate(todayNormalized) === isoDate(ovulationDate);
    currentPhase = isOvulationDay ? 'Ovulation Day' : 'Fertile Window';
  } else if (currentCycleDay > periodLength && todayNormalized < fertileWindowStart) {
    currentPhase = 'Follicular Phase';
  } else if (todayNormalized > fertileWindowEnd && currentCycleDay <= cycleLength) {
    currentPhase = 'Luteal Phase';
  } else if (currentCycleDay > cycleLength) {
    currentPhase = `Late Period (${currentCycleDay - cycleLength} days late)`;
  }

  return {
    todayDate: isoDate(todayNormalized),
    lastPeriodStartDate: isoDate(startNormalized),
    currentCycleStartDate: isoDate(currentCycleStart),
    currentCycleDay,
    cycleLengthDays: cycleLength,
    periodLengthDays: periodLength,
    isCurrentPeriod,
    periodDay,
    currentPhase,
    nextPeriodStartDate: isoDate(nextPeriodStart),
    daysUntilNextPeriod,
    estimatedOvulationDate: isoDate(ovulationDate),
    fertileWindowStart: isoDate(fertileWindowStart),
    fertileWindowEnd: isoDate(fertileWindowEnd),
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

  if (cycleForecast) {
    if (cycleForecast.isCurrentPeriod) {
      return `Currently on period Day ${cycleForecast.periodDay} of ${cycleForecast.periodLengthDays}. Prioritize rest, hydration, and comfort.`;
    }
    return `Moderate trend expected; current phase is ${cycleForecast.currentPhase}. Watch cycle milestones around ${cycleForecast.estimatedOvulationDate} and ${cycleForecast.nextPeriodStartDate}.`;
  }

  return 'Mixed trend expected; continue tracking daily logs for better prediction confidence.';
}

class UserPredictionContextService {
  async buildUserPredictionContext({ userId, userKey, role }) {
    const [
      user,
      onboarding,
      moods,
      sleepLogs,
      aiHistory,
      connections,
      journals,
    ] = await Promise.all([
      userRepository.getUserById(userId),
      userRepository.getOnboardingAnswers(userId),
      dailyMoodRepository.getRecentDailyMoods(userId, 30),
      sleepRepository.getRecentSleepLogs(userId, 7),
      aiHistoryRepository.listHistory(userKey),
      partnerRepository.listConnectionsForUser(userId),
      journalRepository.getJournalsByUserId(userId, 5).catch(() => []),
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
    const cycleForecast = role === 'woman'
      ? buildCycleForecast(user, onboarding?.onboardingAnswers ?? {})
      : null;

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
    if (cycle) {
      const periodStatus = cycle.isCurrentPeriod 
        ? `CURRENTLY ON PERIOD: Day ${cycle.periodDay} of ${cycle.periodLengthDays} (Day ${cycle.currentCycleDay} of cycle).`
        : `CURRENT CYCLE DAY: Day ${cycle.currentCycleDay} of ${cycle.cycleLengthDays}. Phase: ${cycle.currentPhase}.`;
      
      const countdownDetail = cycle.daysUntilNextPeriod > 0
        ? `in ${cycle.daysUntilNextPeriod} days`
        : (cycle.daysUntilNextPeriod === 0 ? 'Today!' : `${Math.abs(cycle.daysUntilNextPeriod)} days late`);

      cycleSummaryText = `EXACT CYCLE & PERIOD STATUS:
- Today's Date: ${cycle.todayDate}
- Status: ${periodStatus}
- Current Phase: ${cycle.currentPhase}
- Last Period Start Date: ${cycle.lastPeriodStartDate}
- Current Cycle Start Date: ${cycle.currentCycleStartDate}
- Cycle Frequency: ${cycle.cycleLengthDays} days
- Period Duration: ${cycle.periodLengthDays} days
- Next Period Expected: ${cycle.nextPeriodStartDate} (${countdownDetail})
- Estimated Ovulation Date: ${cycle.estimatedOvulationDate}
- Fertile Window: ${cycle.fertileWindowStart} to ${cycle.fertileWindowEnd}`;
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