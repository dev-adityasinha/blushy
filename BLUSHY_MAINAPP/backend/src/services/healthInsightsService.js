/**
 * Health Insights Service
 * Analyzes user health data and identifies patterns, concerns, and suggestions
 * All insights are data-backed and based only on actual user data
 */

const MOOD_TO_SCORE = {
  great: 5,
  okay: 4,
  low: 2,
  anxious: 2,
  irritated: 2,
};

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

function average(values) {
  if (!Array.isArray(values) || values.length === 0) {
    return null;
  }

  const sum = values.reduce((acc, value) => acc + value, 0);
  return sum / values.length;
}

class HealthInsightsService {
  /**
   * Analyze user health data and generate insights and alerts
   */
  analyzeUserHealth({
    userId,
    role,
    dailyMoods = [],
    sleepLogs = [],
    onboardingAnswers = {},
    cycleStartDate = null,
  }) {
    if (!userId) {
      return {
        hasData: false,
        insights: [],
        alerts: [],
        suggestions: [],
      };
    }

    const moods = Array.isArray(dailyMoods) ? dailyMoods : [];
    const sleeps = Array.isArray(sleepLogs) ? sleepLogs : [];

    const insights = [];
    const alerts = [];
    const suggestions = [];

    // Analyze mood patterns
    if (moods.length > 0) {
      const moodAnalysis = this._analyzeMoodPatterns(moods);
      insights.push(...moodAnalysis.insights);
      alerts.push(...moodAnalysis.alerts);
      suggestions.push(...moodAnalysis.suggestions);
    }

    // Analyze sleep patterns
    if (sleeps.length > 0) {
      const sleepAnalysis = this._analyzeSleepPatterns(sleeps);
      insights.push(...sleepAnalysis.insights);
      alerts.push(...sleepAnalysis.alerts);
      suggestions.push(...sleepAnalysis.suggestions);
    }

    // Analyze stress levels
    if (moods.length > 0) {
      const stressAnalysis = this._analyzeStressLevels(moods);
      insights.push(...stressAnalysis.insights);
      alerts.push(...stressAnalysis.alerts);
      suggestions.push(...stressAnalysis.suggestions);
    }

    // Analyze energy levels
    if (moods.length > 0) {
      const energyAnalysis = this._analyzeEnergyLevels(moods);
      insights.push(...energyAnalysis.insights);
      alerts.push(...energyAnalysis.alerts);
      suggestions.push(...energyAnalysis.suggestions);
    }

    // Analyze cycle if data available
    if (cycleStartDate || Object.keys(onboardingAnswers).length > 0) {
      const cycleAnalysis = this._analyzeCycleHealth(
        cycleStartDate,
        onboardingAnswers,
        moods,
      );
      insights.push(...cycleAnalysis.insights);
      alerts.push(...cycleAnalysis.alerts);
      suggestions.push(...cycleAnalysis.suggestions);
    }

    return {
      hasData: moods.length > 0 || sleeps.length > 0,
      dataPoints: {
        moodEntries: moods.length,
        sleepEntries: sleeps.length,
      },
      insights: this._deduplicateMessages(insights),
      alerts: this._deduplicateMessages(alerts),
      suggestions: this._deduplicateMessages(suggestions),
    };
  }

  _analyzeMoodPatterns(moods) {
    const insights = [];
    const alerts = [];
    const suggestions = [];

    const sorted = [...moods].sort(
      (a, b) =>
        new Date(a.entryDate).getTime() - new Date(b.entryDate).getTime(),
    );
    const recent = sorted.slice(-7);

    if (recent.length === 0) return { insights, alerts, suggestions };

    const scores = recent
      .map((m) => MOOD_TO_SCORE[m.mood] ?? 3)
      .filter((s) => typeof s === 'number');
    const avgScore = average(scores) || 3;

    // Detect low moods
    const lowMoodEntries = recent.filter((m) => m.mood === 'low' || m.mood === 'anxious');
    const lowMoodPercentage = (lowMoodEntries.length / recent.length) * 100;

    if (lowMoodPercentage >= 50) {
      alerts.push({
        type: 'low_mood_pattern',
        severity: 'high',
        title: 'Persistent Low Mood',
        message: `${lowMoodPercentage.toFixed(0)}% of your mood logs in the past 7 days show low mood or anxiety.`,
      });
      suggestions.push({
        type: 'mood_support',
        suggestion:
          'Consider connecting with someone you trust. Sometimes talking helps. Also ensure you are getting enough rest and moving your body gently.',
      });
    } else if (lowMoodPercentage >= 30) {
      insights.push({
        type: 'mood_variability',
        message: `Your mood has been variable recently (${lowMoodPercentage.toFixed(0)}% low days). This is normal, but be gentle with yourself.`,
      });
    } else if (lowMoodPercentage === 0 && recent.length >= 3) {
      insights.push({
        type: 'positive_mood',
        message: 'Great job! Your mood has been consistently positive over the past few days.',
      });
    }

    // Detect mood trends
    if (recent.length >= 5) {
      const first = average(scores.slice(0, 2));
      const last = average(scores.slice(-2));
      if (last < first - 1) {
        alerts.push({
          type: 'declining_mood',
          severity: 'medium',
          title: 'Declining Mood Trend',
          message: 'Your mood appears to be declining. Is something bothering you?',
        });
      }
    }

    return { insights, alerts, suggestions };
  }

  _analyzeSleepPatterns(sleepLogs) {
    const insights = [];
    const alerts = [];
    const suggestions = [];

    const durations = sleepLogs
      .map((log) => Number(log.durationMinutes) || 0)
      .filter((d) => d > 0);

    if (durations.length === 0) return { insights, alerts, suggestions };

    const avgDuration = average(durations);
    const avgHours = (avgDuration / 60).toFixed(1);

    // Detect insufficient sleep
    if (avgDuration < 360) {
      // Less than 6 hours
      alerts.push({
        type: 'insufficient_sleep',
        severity: 'high',
        title: 'Low Sleep Duration',
        message: `Your average sleep is ${avgHours} hours per night. Adults typically need 7-9 hours.`,
      });
      suggestions.push({
        type: 'sleep_improvement',
        suggestion:
          'Try to improve your sleep: maintain consistent bedtime, avoid screens 1 hour before bed, keep your room cool and dark.',
      });
    } else if (avgDuration < 420) {
      // Less than 7 hours
      insights.push({
        type: 'suboptimal_sleep',
        message: `Your average sleep is ${avgHours} hours. Consider aiming for 7-9 hours for better recovery.`,
      });
    } else if (avgDuration >= 420 && avgDuration <= 540) {
      // 7-9 hours
      insights.push({
        type: 'healthy_sleep',
        message: `Great! Your average sleep is ${avgHours} hours, which is in the healthy range.`,
      });
    } else if (avgDuration > 540) {
      // More than 9 hours
      insights.push({
        type: 'excessive_sleep',
        message: `Your average sleep is ${avgHours} hours. While rest is important, excessive sleep sometimes indicates fatigue or mood changes. Monitor how you feel.`,
      });
    }

    // Detect sleep variability
    const variance = Math.sqrt(
      average(durations.map((d) => Math.pow(d - avgDuration, 2))),
    );
    if (variance > avgDuration * 0.3) {
      insights.push({
        type: 'sleep_variability',
        message:
          'Your sleep duration varies quite a bit. Try to establish a more consistent sleep schedule.',
      });
    }

    return { insights, alerts, suggestions };
  }

  _analyzeStressLevels(moods) {
    const insights = [];
    const alerts = [];
    const suggestions = [];

    const recent = [...moods]
      .sort(
        (a, b) =>
          new Date(a.entryDate).getTime() - new Date(b.entryDate).getTime(),
      )
      .slice(-7);

    if (recent.length === 0) return { insights, alerts, suggestions };

    const stressScores = recent
      .map((m) => {
        if (m.stressLevel === 'high') return 3;
        if (m.stressLevel === 'medium') return 2;
        return 1;
      })
      .filter((s) => typeof s === 'number');

    const avgStress = average(stressScores);
    const highStressCount = recent.filter((m) => m.stressLevel === 'high').length;

    if (avgStress >= 2.5 && highStressCount >= 3) {
      alerts.push({
        type: 'high_stress_pattern',
        severity: 'high',
        title: 'Elevated Stress Levels',
        message: `You have reported high stress on ${highStressCount} out of ${recent.length} days.`,
      });
      suggestions.push({
        type: 'stress_management',
        suggestion:
          'Try stress-relief techniques: deep breathing, meditation, light exercise, or time in nature. Also ensure adequate sleep.',
      });
    } else if (avgStress >= 2) {
      insights.push({
        type: 'moderate_stress',
        message: 'Your stress levels have been moderate. Remember to take breaks and care for yourself.',
      });
    } else {
      insights.push({
        type: 'low_stress',
        message: 'Your stress levels seem well-managed. Keep up the good self-care!',
      });
    }

    return { insights, alerts, suggestions };
  }

  _analyzeEnergyLevels(moods) {
    const insights = [];
    const alerts = [];
    const suggestions = [];

    const recent = [...moods]
      .sort(
        (a, b) =>
          new Date(a.entryDate).getTime() - new Date(b.entryDate).getTime(),
      )
      .slice(-7);

    if (recent.length === 0) return { insights, alerts, suggestions };

    const energyScores = recent
      .map((m) => {
        if (m.energyLevel === 'high') return 3;
        if (m.energyLevel === 'medium') return 2;
        return 1;
      })
      .filter((s) => typeof s === 'number');

    const avgEnergy = average(energyScores);
    const lowEnergyCount = recent.filter(
      (m) => m.energyLevel === 'low',
    ).length;

    if (avgEnergy <= 1.5 && lowEnergyCount >= 3) {
      alerts.push({
        type: 'fatigue_pattern',
        severity: 'medium',
        title: 'Persistent Fatigue',
        message: `You have reported low energy on ${lowEnergyCount} out of ${recent.length} days.`,
      });
      suggestions.push({
        type: 'energy_boost',
        suggestion:
          'Fatigue can be from insufficient sleep, hydration, or nutrition. Try: drinking more water, eating iron-rich foods, moving gently, and resting more.',
      });
    } else if (avgEnergy < 2) {
      insights.push({
        type: 'lower_energy',
        message:
          'Your energy levels have been lower recently. Ensure good nutrition, hydration, and rest.',
      });
    } else if (avgEnergy >= 2.5) {
      insights.push({
        type: 'good_energy',
        message: 'Your energy levels look great! Keep maintaining your healthy habits.',
      });
    }

    return { insights, alerts, suggestions };
  }

  _analyzeCycleHealth(cycleStartDate, onboardingAnswers, moods) {
    const insights = [];
    const alerts = [];
    const suggestions = [];

    const rawStart = cycleStartDate != null
      ? new Date(cycleStartDate)
      : (onboardingAnswers?.period_last_start_date
        ? new Date(onboardingAnswers.period_last_start_date)
        : (onboardingAnswers?.cycle_last_period_start
          ? new Date(onboardingAnswers.cycle_last_period_start)
          : null));

    if (!rawStart || Number.isNaN(rawStart.getTime())) {
      return { insights, alerts, suggestions };
    }

    const cycleLength = Number(onboardingAnswers?.cycle_length || onboardingAnswers?.period_cycle_length) || 28;
    const periodDuration = Number(onboardingAnswers?.period_duration_days || onboardingAnswers?.cycle_last_period_duration_days) || 5;

    const today = new Date();
    const todayNormalized = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const startNormalized = new Date(rawStart.getFullYear(), rawStart.getMonth(), rawStart.getDate());

    let currentCycleStart = new Date(startNormalized);
    if (startNormalized <= todayNormalized) {
      const diffMs = todayNormalized.getTime() - startNormalized.getTime();
      const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
      const cyclesElapsed = Math.floor(diffDays / cycleLength);
      currentCycleStart = new Date(startNormalized.getTime() + cyclesElapsed * cycleLength * 86400000);
    }

    const dayOfCycle = Math.floor((todayNormalized.getTime() - currentCycleStart.getTime()) / (1000 * 60 * 60 * 24)) + 1;
    const nextPeriod = new Date(currentCycleStart.getTime() + cycleLength * 86400000);
    const daysUntilPeriod = Math.ceil((nextPeriod.getTime() - todayNormalized.getTime()) / (1000 * 60 * 60 * 24));

    if (dayOfCycle >= 1 && dayOfCycle <= periodDuration) {
      insights.push({
        type: 'current_period',
        message: `You are on day ${dayOfCycle} of your period (expected duration: ${periodDuration} days, cycle day ${dayOfCycle}).`,
      });
      suggestions.push({
        type: 'period_care',
        suggestion:
          'During your period, prioritize: hydration, iron-rich foods, gentle movement, and adequate rest. Manage cramps with heat and relaxation.',
      });
    } else if (daysUntilPeriod > 0 && daysUntilPeriod <= 7) {
      insights.push({
        type: 'period_approaching',
        message: `Your next period is expected in ${daysUntilPeriod} days (around ${nextPeriod.toLocaleDateString()}).`,
      });

      if (moods.length >= 3) {
        const recentMoods = [...moods]
          .sort((a, b) => new Date(a.entryDate).getTime() - new Date(b.entryDate).getTime())
          .slice(-3);
        const lowMoodCount = recentMoods.filter((m) => m.mood === 'low' || m.mood === 'anxious').length;

        if (lowMoodCount >= 2) {
          suggestions.push({
            type: 'premenstrual_support',
            suggestion:
              'You seem to have lower mood recently, which is common before your period. Be extra kind to yourself, prioritize rest, and reach out if you need support.',
          });
        }
      }
    } else if (dayOfCycle > cycleLength) {
      const daysLate = dayOfCycle - cycleLength;
      alerts.push({
        type: 'period_late',
        severity: 'medium',
        title: 'Period Delayed',
        message: `Your period is approximately ${daysLate} day(s) late (Day ${dayOfCycle} of cycle).`,
      });
    }

    return { insights, alerts, suggestions };
  }

  _deduplicateMessages(messages) {
    const seen = new Set();
    return messages.filter((msg) => {
      const key = msg.type || msg.message;
      if (seen.has(key)) {
        return false;
      }
      seen.add(key);
      return true;
    });
  }
}

export const healthInsightsService = new HealthInsightsService();
