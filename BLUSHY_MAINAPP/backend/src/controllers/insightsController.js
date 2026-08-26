import { calculateMonthlyInsights } from '../services/monthlyInsightsService.js';

export async function getMonthlyInsights(req, res) {
  try {
    const userId = req.user?.user_id || req.user?.userId;
    if (!userId) {
      return res.status(401).json({ status: 'error', message: 'Unauthorized' });
    }

    const { month, referenceDate, reference_date } = req.query || {};

    const insights = await calculateMonthlyInsights(userId, {
      month,
      referenceDate: referenceDate || reference_date,
    });

    return res.status(200).json({
      status: 'success',
      data: insights,
    });
  } catch (err) {
    if (err.statusCode) {
      return res.status(err.statusCode).json({
        status: 'error',
        message: err.message,
      });
    }
    console.error('Error calculating monthly insights:', err);
    return res.status(500).json({
      status: 'error',
      message: 'Failed to calculate monthly insights.',
    });
  }
}
