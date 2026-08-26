import { db } from '../utils/db.js';
import { getDailyLogsForRange } from '../repositories/dailyLogRepository.js';
import { getPeriodEntries } from '../repositories/periodRepository.js';
import { getUserById } from '../repositories/userRepository.js';
import { periodPredictionConfig } from '../config/periodPredictionConfig.js';

function isLeapYear(year) {
  return (year % 4 === 0 && year % 100 !== 0) || (year % 400 === 0);
}

function getDaysInMonth(year, month) {
  const daysMap = [31, isLeapYear(year) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return daysMap[month - 1];
}

function getTodayInTimezone(timezone, referenceDate = null) {
  if (referenceDate && /^\d{4}-\d{2}-\d{2}$/.test(referenceDate)) {
    return referenceDate;
  }
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const parts = formatter.formatToParts(now);
  const year = parts.find((p) => p.type === 'year')?.value;
  const month = parts.find((p) => p.type === 'month')?.value;
  const day = parts.find((p) => p.type === 'day')?.value;
  return `${year}-${month}-${day}`;
}

export function getPreviousCompletedMonthBoundaries(referenceDate, userTimezone) {
  const todayTz = getTodayInTimezone(userTimezone, referenceDate);
  const [curYearStr, curMonthStr] = todayTz.split('-');
  const curYear = parseInt(curYearStr, 10);
  const curMonth = parseInt(curMonthStr, 10);

  let prevYear = curYear;
  let prevMonth = curMonth - 1;
  if (prevMonth === 0) {
    prevMonth = 12;
    prevYear -= 1;
  }

  const prevMonthStr = String(prevMonth).padStart(2, '0');
  const reportingMonth = `${prevYear}-${prevMonthStr}`;
  const totalDays = getDaysInMonth(prevYear, prevMonth);
  const startDate = `${reportingMonth}-01`;
  const endDate = `${reportingMonth}-${String(totalDays).padStart(2, '0')}`;

  return {
    reportingMonth,
    startDate,
    endDate,
    totalDays,
    currentMonth: `${curYear}-${curMonthStr}`,
  };
}

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

export async function calculateMonthlyInsights(userId, options = {}) {
  const cleanUserId = typeof userId === 'string' ? userId.replace('user:', '') : userId;
  const user = await getUserById(cleanUserId);

  // Determine timezone
  let userTimezone = user?.timezone || user?.onboardingAnswers?.timezone || user?.onboarding_answers?.timezone;
  let timezoneSource = 'user_profile';

  if (!userTimezone || typeof userTimezone !== 'string') {
    userTimezone = periodPredictionConfig.defaultFallbackTimezone;
    timezoneSource = 'emergency_fallback';
  } else {
    try {
      Intl.DateTimeFormat(undefined, { timeZone: userTimezone });
    } catch (_) {
      userTimezone = periodPredictionConfig.defaultFallbackTimezone;
      timezoneSource = 'emergency_fallback';
    }
  }

  // Calculate default completed month boundaries
  const defaultBoundaries = getPreviousCompletedMonthBoundaries(options.referenceDate, userTimezone);

  let reportingMonth = defaultBoundaries.reportingMonth;
  let startDate = defaultBoundaries.startDate;
  let endDate = defaultBoundaries.endDate;
  let totalDays = defaultBoundaries.totalDays;

  // Handle explicit month parameter if provided
  if (options.month) {
    const monthPattern = /^\d{4}-(0[1-9]|1[0-2])$/;
    if (!monthPattern.test(options.month)) {
      const error = new Error('Invalid month format. Must be YYYY-MM.');
      error.statusCode = 400;
      throw error;
    }

    if (options.month >= defaultBoundaries.currentMonth) {
      const error = new Error('Cannot request current or future month. Monthly insights are only available for completed calendar months.');
      error.statusCode = 400;
      throw error;
    }

    reportingMonth = options.month;
    const [yStr, mStr] = reportingMonth.split('-');
    const y = parseInt(yStr, 10);
    const m = parseInt(mStr, 10);
    totalDays = getDaysInMonth(y, m);
    startDate = `${reportingMonth}-01`;
    endDate = `${reportingMonth}-${String(totalDays).padStart(2, '0')}`;
  }

  // 1. Query daily logs in M-1 range
  const dailyLogs = await getDailyLogsForRange(cleanUserId, startDate, endDate);

  // 2. Query period entries in M-1 range
  const isMan = await db.collection('users_man').findOne({ user_id: cleanUserId });
  const periodColl = isMan ? 'user_period_logs_man' : 'user_period_logs_woman';
  const periodLogs = await db.collection(periodColl)
    .find({
      user_id: cleanUserId,
      period_start_date: { $gte: startDate, $lte: endDate },
    })
    .sort({ period_start_date: 1 })
    .toArray();

  // 3. Query authenticated Sia chat history in M-1 range
  const chatColl = isMan ? 'ai_chat_history_man' : 'ai_chat_history_woman';
  const chatDocs = await db.collection(chatColl)
    .find({
      $or: [
        { user_id: cleanUserId },
        { user_key: cleanUserId },
      ],
      created_at: {
        $gte: new Date(`${startDate}T00:00:00.000Z`),
        $lte: new Date(`${endDate}T23:59:59.999Z`),
      },
    })
    .toArray();

  // Count distinct chat dates with at least 2 exchanges
  const chatDatesMap = {};
  for (const doc of chatDocs) {
    const dStr = doc.created_at instanceof Date
      ? doc.created_at.toISOString().split('T')[0]
      : (typeof doc.created_at === 'string' ? doc.created_at.split('T')[0] : null);
    if (dStr && dStr >= startDate && dStr <= endDate) {
      chatDatesMap[dStr] = (chatDatesMap[dStr] || 0) + 1;
    }
  }
  const siaConversationsCount = Object.values(chatDatesMap).filter((c) => c >= 2).length;

  // Calculate Metrics
  const distinctCheckinDates = new Set(dailyLogs.map((l) => l.logDate));
  const checkinCount = distinctCheckinDates.size;
  const checkinConsistencyPercentage = totalDays > 0
    ? Math.round((checkinCount / totalDays) * 1000) / 10
    : 0;

  const symptomLogs = dailyLogs.filter((l) => Array.isArray(l.symptoms) && l.symptoms.length > 0);
  const symptomLogCount = symptomLogs.length;

  const uniqueSymptoms = Array.from(
    new Set(dailyLogs.flatMap((l) => l.symptoms || []))
  );

  const moodLogs = dailyLogs.filter((l) => l.mood != null);
  const moodLogCount = moodLogs.length;

  const periodDaysInMonth = periodLogs.length;
  const completedCyclesInMonth = periodLogs.length >= 2 ? periodLogs.length - 1 : (periodLogs.length === 1 ? 1 : 0);

  // Determine Data State
  let dataState = 'sufficient_data';
  if (checkinCount === 0 && periodDaysInMonth === 0) {
    dataState = 'no_data';
  } else if (checkinCount < 5) {
    dataState = 'learning_state';
  }

  // Parse Month Name for UI
  const monthNum = parseInt(reportingMonth.split('-')[1], 10);
  const monthName = MONTH_NAMES[monthNum - 1] || reportingMonth;

  // Milestones with Auditable Green-Tick Booleans
  const milestones = [
    {
      id: 'milestone_checkin_consistency',
      title: 'Consistent Daily Check-ins',
      description: `Completed ${checkinCount} of ${totalDays} days in ${monthName}.`,
      sourceField: 'user_daily_logs_woman (distinct log_date count)',
      completionRule: 'checkinCount >= 15',
      isCompleted: checkinCount >= 15,
      showGreenTick: checkinCount >= 15,
      statusLabel: checkinCount >= 15 ? 'Completed' : `${checkinCount} / 15 days logged`,
    },
    {
      id: 'milestone_symptom_tracking',
      title: 'Proactive Symptom Logging',
      description: symptomLogCount > 0
        ? `Logged symptoms (${uniqueSymptoms.slice(0, 3).join(', ')}) in ${monthName}.`
        : `No symptoms recorded for ${monthName}.`,
      sourceField: 'user_daily_logs_woman.symptoms',
      completionRule: 'symptomLogCount >= 1',
      isCompleted: symptomLogCount >= 1,
      showGreenTick: symptomLogCount >= 1,
      statusLabel: symptomLogCount >= 1 ? `Completed (${symptomLogCount} logs)` : `Not logged in ${monthName}`,
    },
    {
      id: 'milestone_cycle_logging',
      title: 'Cycle Start Tracking',
      description: periodDaysInMonth > 0
        ? `Confirmed period start date logged in ${monthName}.`
        : `No period start date logged in ${monthName}.`,
      sourceField: 'user_period_logs_woman.period_start_date',
      completionRule: 'periodDaysInMonth >= 1',
      isCompleted: periodDaysInMonth >= 1,
      showGreenTick: periodDaysInMonth >= 1,
      statusLabel: periodDaysInMonth >= 1 ? 'Completed' : `No cycle logged in ${monthName}`,
    },
    {
      id: 'milestone_sia_engagement',
      title: 'Sia Wellness Conversations',
      description: siaConversationsCount > 0
        ? `Engaged in ${siaConversationsCount} Sia wellness sessions in ${monthName}.`
        : `No wellness conversations logged in ${monthName}.`,
      sourceField: 'ai_chat_history_woman (distinct dates with >= 2 exchanges)',
      completionRule: 'siaConversationsCount >= 3',
      isCompleted: siaConversationsCount >= 3,
      showGreenTick: siaConversationsCount >= 3,
      statusLabel: siaConversationsCount >= 3 ? 'Completed' : `${siaConversationsCount} / 3 sessions`,
    },
  ];

  // Observational Reflection Summary
  let headline = `${monthName} Monthly Reflection`;
  let summaryText = '';

  if (dataState === 'no_data') {
    summaryText = `No check-ins or cycle events were recorded for ${monthName}. Daily check-ins this month will appear in your next monthly summary.`;
  } else if (dataState === 'learning_state') {
    summaryText = `In ${monthName}, you began building your daily wellness rhythm with ${checkinCount} logged check-in${checkinCount === 1 ? '' : 's'}. Log 5+ check-ins to unlock detailed pattern summaries.`;
  } else {
    summaryText = `In ${monthName}, you recorded ${checkinCount} daily check-ins (${checkinConsistencyPercentage}% consistency)${uniqueSymptoms.length > 0 ? ` and tracked ${uniqueSymptoms.length} distinct symptom categories` : ''}. Your recorded inputs provide clear visibility into your wellness rhythm.`;
  }

  return {
    reportingMonth,
    startDate,
    endDate,
    userTimezone,
    timezoneSource,
    dataState,
    totalDaysInMonth: totalDays,
    metrics: {
      checkinCount,
      checkinConsistencyPercentage,
      symptomLogCount,
      moodLogCount,
      uniqueSymptomsTracked: uniqueSymptoms,
      periodDaysInMonth,
      completedCyclesInMonth,
      siaConversationsCount,
    },
    milestones,
    reflection: {
      headline,
      summaryText,
      isPersonalized: dataState !== 'no_data',
      sampleSize: checkinCount,
    },
    disclaimer: 'Monthly insights are descriptive summaries of your recorded inputs and are not intended for medical diagnosis or clinical evaluation.',
  };
}
