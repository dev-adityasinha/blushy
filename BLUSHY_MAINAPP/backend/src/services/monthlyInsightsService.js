import { db } from '../utils/db.js';
import { joinedAfterReportingMonth } from '../utils/monthWindow.js';
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

  // 1b. Check-ins recorded as health events, which is what the app writes.
  const checkinEvents = await db.collection('health_events')
    .find({
      user_id: cleanUserId,
      deleted_at: null,
      event_type: {
        $in: ['mood_logged', 'energy_logged', 'sleep_logged', 'stress_logged',
              'pain_logged', 'hydration_logged', 'symptom_logged', 'flow_logged',
              'activity_logged'],
      },
      timestamp: {
        $gte: new Date(`${startDate}T00:00:00.000Z`),
        $lte: new Date(`${endDate}T23:59:59.999Z`),
      },
    })
    .project({ timestamp: 1 })
    .toArray();

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

  // 3. Query authenticated Dr. Docsy chat history in M-1 range
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
  // A check-in counts wherever it was recorded.
  //
  // This counted `user_daily_logs_*` only, and the app does not write there:
  // it records check-ins as health events, and `ApiCheckinService` -- the one
  // client that would have hit the daily-log route -- is not called from
  // anywhere. So the monthly reflection reported "0 check-ins" no matter how
  // diligently someone logged. Verified by driving 637 events through the
  // pipeline and watching this come back 0.
  //
  // Both sources are counted, by distinct date, so a day logged in both is
  // still one day.
  const distinctCheckinDates = new Set(dailyLogs.map((l) => l.logDate));
  for (const event of checkinEvents) {
    const iso = event.timestamp instanceof Date
      ? event.timestamp.toISOString()
      : String(event.timestamp ?? '');
    const day = iso.slice(0, 10);
    if (day >= startDate && day <= endDate) distinctCheckinDates.add(day);
  }
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

  // A month that ended before this account existed is not a month she failed
  // to log -- she was not here. Reporting "no check-ins were recorded for
  // July" to someone who installed the app in August describes the app, not
  // her, and it is the first thing she sees on the home page.
  const joinedAfterMonth = joinedAfterReportingMonth(
    user?.createdAt ?? user?.created_at,
    endDate,
  );

  // Determine Data State
  let dataState = 'sufficient_data';
  if (joinedAfterMonth) {
    dataState = 'not_yet_joined';
  } else if (checkinCount === 0 && periodDaysInMonth === 0) {
    dataState = 'no_data';
  } else if (checkinCount === 0) {
    // A month with a period logged and nothing else is not a rhythm being
    // built. It previously fell through to `learning_state`, whose summary
    // reads "you began building your daily wellness rhythm with 0 logged
    // check-ins" -- congratulating her for having logged nothing.
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
      title: 'Dr. Docsy Wellness Conversations',
      description: siaConversationsCount > 0
        ? `Engaged in ${siaConversationsCount} Dr. Docsy wellness sessions in ${monthName}.`
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

  if (dataState === 'not_yet_joined') {
    summaryText = `Your account is newer than ${monthName}, so there is nothing to report for it. Your first monthly reflection arrives once this month completes.`;
  } else if (dataState === 'no_data') {
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
      isPersonalized: dataState !== 'no_data' && dataState !== 'not_yet_joined',
      sampleSize: checkinCount,
    },
    disclaimer: 'Monthly insights are descriptive summaries of your recorded inputs and are not intended for medical diagnosis or clinical evaluation.',
  };
}
