import {
  createOrUpdatePeriodEntry,
  getPeriodEntries as fetchPeriodEntries,
  deletePeriodEntry as removePeriodEntry,
} from '../repositories/periodRepository.js';
import { calculatePeriodPredictions } from '../services/periodPredictionService.js';

function isValidCalendarDate(str) {
  if (typeof str !== 'string') return false;
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(str.trim());
  if (!match) return false;
  const y = Number(match[1]);
  const m = Number(match[2]);
  const d = Number(match[3]);
  if (m < 1 || m > 12 || d < 1 || d > 31) return false;
  const date = new Date(y, m - 1, d);
  return date.getFullYear() === y && date.getMonth() === m - 1 && date.getDate() === d;
}

export async function logPeriodEntry(req, res) {
  try {
    const userId = req.user?.user_id || req.user?.userId;
    if (!userId) {
      return res.status(401).json({ status: 'error', message: 'Unauthorized' });
    }

    const { periodStartDate, startDate, period_start_date, periodEndDate, endDate, period_end_date, flowIntensity, source, notes } = req.body || {};
    const effectiveStart = periodStartDate || startDate || period_start_date;
    const effectiveEnd = periodEndDate || endDate || period_end_date;

    if (!effectiveStart || !isValidCalendarDate(effectiveStart)) {
      return res.status(400).json({
        status: 'error',
        message: 'A valid periodStartDate in YYYY-MM-DD format is required.',
      });
    }

    // Future date check: allow today + 1 day leeway for global timezone differences, reject further future dates
    const parsedStart = new Date(effectiveStart);
    const maxAllowedFuture = new Date();
    maxAllowedFuture.setUTCDate(maxAllowedFuture.getUTCDate() + 1);
    if (parsedStart > maxAllowedFuture) {
      return res.status(400).json({
        status: 'error',
        message: 'Period start date cannot be in the future.',
      });
    }

    if (effectiveEnd) {
      if (!isValidCalendarDate(effectiveEnd)) {
        return res.status(400).json({
          status: 'error',
          message: 'periodEndDate must be a valid calendar date in YYYY-MM-DD format.',
        });
      }
      const parsedEnd = new Date(effectiveEnd);
      if (parsedEnd < parsedStart) {
        return res.status(400).json({
          status: 'error',
          message: 'periodEndDate cannot be before periodStartDate.',
        });
      }
    }

    if (flowIntensity && !['spotting', 'light', 'medium', 'heavy'].includes(flowIntensity)) {
      return res.status(400).json({
        status: 'error',
        message: 'flowIntensity must be one of: spotting, light, medium, heavy.',
      });
    }

    const entry = await createOrUpdatePeriodEntry(userId, {
      periodStartDate: effectiveStart,
      periodEndDate: effectiveEnd,
      flowIntensity,
      source,
      notes,
    });

    return res.status(200).json({
      status: 'success',
      data: entry,
    });
  } catch (err) {
    console.error('Error logging period entry:', err);
    return res.status(500).json({
      status: 'error',
      message: 'Failed to record period entry.',
    });
  }
}

export async function getPeriodEntriesList(req, res) {
  try {
    const userId = req.user?.user_id || req.user?.userId;
    if (!userId) {
      return res.status(401).json({ status: 'error', message: 'Unauthorized' });
    }

    const entries = await fetchPeriodEntries(userId);
    return res.status(200).json({
      status: 'success',
      data: {
        entries,
        count: entries.length,
      },
    });
  } catch (err) {
    console.error('Error fetching period entries:', err);
    return res.status(500).json({
      status: 'error',
      message: 'Failed to fetch period entries.',
    });
  }
}

export async function deletePeriodEntryHandler(req, res) {
  try {
    const userId = req.user?.user_id || req.user?.userId;
    if (!userId) {
      return res.status(401).json({ status: 'error', message: 'Unauthorized' });
    }

    const { id } = req.params;
    if (!id) {
      return res.status(400).json({ status: 'error', message: 'Entry id is required.' });
    }

    const ok = await removePeriodEntry(userId, id);
    if (!ok) {
      return res.status(404).json({ status: 'error', message: 'Period entry not found.' });
    }

    return res.status(200).json({
      status: 'success',
      message: 'Period entry deleted successfully.',
    });
  } catch (err) {
    console.error('Error deleting period entry:', err);
    return res.status(500).json({
      status: 'error',
      message: 'Failed to delete period entry.',
    });
  }
}

export async function getPredictions(req, res) {
  try {
    const userId = req.user?.user_id || req.user?.userId;
    if (!userId) {
      return res.status(401).json({ status: 'error', message: 'Unauthorized' });
    }

    const timezone = req.query?.timezone || req.headers['x-timezone'] || req.headers['timezone'];
    const referenceDate = req.query?.referenceDate || req.query?.reference_date;

    const predictions = await calculatePeriodPredictions(userId, { timezone, referenceDate });
    return res.status(200).json({
      status: 'success',
      data: predictions,
    });
  } catch (err) {
    console.error('Error getting period predictions:', err);
    return res.status(500).json({
      status: 'error',
      message: 'Failed to calculate predictions.',
    });
  }
}
