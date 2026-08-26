import { createOrUpdateDailyLog, getDailyLogByDate } from '../repositories/dailyLogRepository.js';

function isValidDateString(str) {
  if (typeof str !== 'string') return false;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(str)) return false;
  const [y, m, d] = str.split('-').map(Number);
  if (m < 1 || m > 12) return false;
  const isLeap = (y % 4 === 0 && y % 100 !== 0) || (y % 400 === 0);
  const maxDays = [31, isLeap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1];
  return d >= 1 && d <= maxDays;
}

export async function submitCheckin(req, res) {
  try {
    const userId = req.user?.user_id || req.user?.userId;
    if (!userId) {
      return res.status(401).json({ status: 'error', message: 'Unauthorized' });
    }

    const { logDate, log_date, mood, energyLevel, energy_level, sleepHours, sleep_hours, symptoms, notes, source } = req.body || {};
    const effectiveDate = logDate || log_date;

    if (!effectiveDate || !isValidDateString(effectiveDate)) {
      return res.status(400).json({
        status: 'error',
        message: 'A valid logDate in YYYY-MM-DD format is required.',
      });
    }

    // Future date check: allow today + 1 day leeway for global timezone differences, reject further future dates
    const parsedDate = new Date(effectiveDate);
    const maxAllowedFuture = new Date();
    maxAllowedFuture.setUTCDate(maxAllowedFuture.getUTCDate() + 1);
    if (parsedDate > maxAllowedFuture) {
      return res.status(400).json({
        status: 'error',
        message: 'Log date cannot be in the future.',
      });
    }

    if (sleepHours !== undefined && sleepHours !== null && typeof sleepHours !== 'number') {
      return res.status(400).json({
        status: 'error',
        message: 'sleepHours must be a valid number between 0 and 24.',
      });
    }

    const savedLog = await createOrUpdateDailyLog(userId, {
      logDate: effectiveDate,
      mood,
      energyLevel: energyLevel || energy_level,
      sleepHours: sleepHours !== undefined ? sleepHours : sleep_hours,
      symptoms,
      notes,
      source,
    });

    return res.status(200).json({
      status: 'success',
      data: savedLog,
    });
  } catch (err) {
    console.error('Error submitting daily checkin:', err);
    return res.status(500).json({
      status: 'error',
      message: 'Failed to record daily checkin.',
    });
  }
}

export async function getCheckinByDate(req, res) {
  try {
    const userId = req.user?.user_id || req.user?.userId;
    if (!userId) {
      return res.status(401).json({ status: 'error', message: 'Unauthorized' });
    }

    const { date } = req.params;
    if (!date || !isValidDateString(date)) {
      return res.status(400).json({ status: 'error', message: 'Valid date parameter (YYYY-MM-DD) is required.' });
    }

    const log = await getDailyLogByDate(userId, date);
    return res.status(200).json({
      status: 'success',
      data: log,
    });
  } catch (err) {
    console.error('Error getting daily checkin:', err);
    return res.status(500).json({
      status: 'error',
      message: 'Failed to get checkin record.',
    });
  }
}
