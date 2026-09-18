import { periodDurationBounds } from '../config/periodPredictionConfig.js';
import { resolvePeriodDuration } from '../domain/periodDuration.js';

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
    periodEntries = [],
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
        periodEntries,
      );
      insights.push(...cycleAnalysis.insights);
      alerts.push(...cycleAnalysis.alerts);
      suggestions.push(...cycleAnalysis.suggestions);
    }

    // Analyze diagnosed/reported conditions and tracked symptoms from onboarding
    if (Object.keys(onboardingAnswers).length > 0) {
      const conditionAnalysis = this._analyzeConditionsAndSymptoms(onboardingAnswers);
      insights.push(...conditionAnalysis.insights);
      alerts.push(...conditionAnalysis.alerts);
      suggestions.push(...conditionAnalysis.suggestions);

      const stageAnalysis = this._analyzeLifeStageSpecifics(onboardingAnswers, cycleStartDate, periodEntries);
      insights.push(...stageAnalysis.insights);
      alerts.push(...stageAnalysis.alerts);
      suggestions.push(...stageAnalysis.suggestions);
    }

    return {
      hasData: moods.length > 0 || sleeps.length > 0 || (periodEntries && periodEntries.length > 0) || cycleStartDate != null || Object.keys(onboardingAnswers).length > 0,
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

  _analyzeCycleHealth(cycleStartDate, onboardingAnswers, moods, periodEntries = []) {
    const insights = [];
    const alerts = [];
    const suggestions = [];

    const rawStart = cycleStartDate != null
      ? new Date(cycleStartDate)
      : (onboardingAnswers?.last_period
        ? new Date(onboardingAnswers.last_period)
        : (onboardingAnswers?.last_period_date
          ? new Date(onboardingAnswers.last_period_date)
          : (onboardingAnswers?.period_last_start_date
            ? new Date(onboardingAnswers.period_last_start_date)
            : (onboardingAnswers?.cycle_last_period_start
              ? new Date(onboardingAnswers.cycle_last_period_start)
              : null))));

    if (!rawStart || Number.isNaN(rawStart.getTime())) {
      return { insights, alerts, suggestions };
    }

    const cycleLength = Number(onboardingAnswers?.cycle_length || onboardingAnswers?.period_cycle_length) || 28;
    // Same resolution the cycle card uses, so the two surfaces agree.
    const { periodDurationDays: periodDuration } =
      resolvePeriodDuration(periodEntries, onboardingAnswers, periodDurationBounds);

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

  _extractItems(source) {
    if (Array.isArray(source)) {
      return source.map((s) => String(s).trim()).filter((s) => s.length > 0);
    }
    if (typeof source === 'string' && source.trim().length > 0) {
      return source.split(',').map((s) => s.trim()).filter((s) => s.length > 0);
    }
    return [];
  }

  _analyzeConditionsAndSymptoms(onboardingAnswers) {
    const insights = [];
    const alerts = [];
    const suggestions = [];

    const conditions = this._extractItems(onboardingAnswers.conditions).map((c) => c.toLowerCase());
    const symptoms = this._extractItems(onboardingAnswers.symptoms).map((s) => s.toLowerCase());

    // ── Conditions Analysis ────────────────────────────────────────────────
    if (conditions.some((c) => c.includes('pcos') || c.includes('pcod') || c.includes('polycystic'))) {
      insights.push({
        type: 'condition_pcos',
        message: 'PCOS hormonal profile: Blood sugar stability, balanced protein, and daily low-impact resistance movement support healthy androgen and insulin regulation.',
      });
      suggestions.push({
        type: 'pcos_support',
        suggestion: 'Pair carbohydrates with protein and healthy fats to minimize glucose spikes, and incorporate gentle walking after meals.',
      });
    }

    if (conditions.some((c) => c.includes('endo') || c.includes('endometriosis'))) {
      insights.push({
        type: 'condition_endometriosis',
        message: 'Endometriosis care: Estrogen-dependent inflammatory tissue benefits from pacing, anti-inflammatory nutrition, and pelvic floor relaxation.',
      });
      suggestions.push({
        type: 'endo_support',
        suggestion: 'Apply gentle thermal heat to the lower pelvis during discomfort, prioritize omega-3 rich foods, and avoid prolonged physical straining.',
      });
    }

    if (conditions.some((c) => c.includes('adeno') || c.includes('adenomyosis'))) {
      insights.push({
        type: 'condition_adenomyosis',
        message: 'Adenomyosis support: Endometrial tissue within the uterine muscle wall can cause deep cramping and heavier menstrual flow.',
      });
      suggestions.push({
        type: 'adeno_care',
        suggestion: 'Keep a heat pack handy for sacral and lower abdominal warmth, and maintain healthy iron stores with leafy greens and citrus.',
      });
    }

    if (conditions.some((c) => c.includes('thyroid') || c.includes('hypothyroid') || c.includes('hashimoto'))) {
      insights.push({
        type: 'condition_thyroid',
        message: 'Thyroid modulation: Thyroid hormones regulate your metabolic rate and directly influence menstrual regularity, body temperature, and energy rhythm.',
      });
      suggestions.push({
        type: 'thyroid_support',
        suggestion: 'Take any prescribed thyroid medication on an empty stomach consistently, and track your morning resting temperature for clinical review.',
      });
    }

    if (conditions.some((c) => c.includes('pmdd') || c.includes('premenstrual dysphoric'))) {
      insights.push({
        type: 'condition_pmdd',
        message: 'PMDD neuro-hormonal pattern: Cellular sensitivity to the post-ovulatory progesterone drop can provoke acute emotional dysregulation and physical tension.',
      });
      suggestions.push({
        type: 'pmdd_care',
        suggestion: 'Create protected calm in the late luteal phase (days 21-28), limit high caffeine, and incorporate magnesium-rich foods to nurture the nervous system.',
      });
    }

    if (conditions.some((c) => c.includes('fibroid'))) {
      insights.push({
        type: 'condition_fibroids',
        message: 'Uterine fibroids awareness: Benign muscular growths can increase bleeding volume and pelvic fullness.',
      });
      suggestions.push({
        type: 'fibroid_care',
        suggestion: 'Monitor bleeding duration, prioritize iron replenishment, and maintain regular pelvic checkups with your gynecologist.',
      });
    }

    // ── Tracked Symptoms Analysis ──────────────────────────────────────────
    if (symptoms.some((s) => s.includes('cramp') || s.includes('dysmenorrhea') || s.includes('pelvic ache'))) {
      alerts.push({
        type: 'symptom_cramps',
        severity: 'medium',
        title: 'Cramp Relief',
        message: 'Menstrual cramps are driven by uterine prostaglandins. Heat therapy increases pelvic blood flow and calms myometrial spasms.',
      });
      suggestions.push({
        type: 'cramp_relief',
        suggestion: 'Apply warmth (water bottle or heating pad) to the lower pelvis and sip warm ginger or chamomile tea.',
      });
    }

    if (symptoms.some((s) => s.includes('heavy') || s.includes('menorrhagia') || s.includes('flooding') || s.includes('clots'))) {
      alerts.push({
        type: 'symptom_heavy_bleeding',
        severity: 'medium',
        title: 'Heavy Flow & Iron Protection',
        message: 'Heavy menstrual blood loss can deplete ferritin and red blood cells over time.',
      });
      suggestions.push({
        type: 'heavy_flow_care',
        suggestion: 'Consume iron-rich foods (beans, lentils, spinach, seeds) paired with Vitamin C. Consult your doctor if bleeding exceeds 7 days or requires changing pads every hour.',
      });
    }

    if (symptoms.some((s) => s.includes('hot flash') || s.includes('night sweat') || s.includes('flushes'))) {
      alerts.push({
        type: 'symptom_vasomotor',
        severity: 'medium',
        title: 'Vasomotor Flushes',
        message: 'Estrogen fluctuations alter the hypothalamus set-point, triggering temporary warmth and flushing.',
      });
      suggestions.push({
        type: 'vasomotor_care',
        suggestion: 'Dress in layers of natural breathable fibers, keep cool water accessible, and practice paced diaphragmatic breathing.',
      });
    }

    if (symptoms.some((s) => s.includes('fatigue') || s.includes('tired') || s.includes('exhaustion') || s.includes('low energy'))) {
      insights.push({
        type: 'symptom_fatigue',
        message: 'Energy dips often correlate with hormone transitions, restorative sleep deficits, or nutrient demands.',
      });
      suggestions.push({
        type: 'energy_care',
        suggestion: 'Honor your body with a 20-minute rest pause, ensure consistent hydration, and get morning natural light.',
      });
    }

    if (symptoms.some((s) => s.includes('bloat') || s.includes('water retention'))) {
      insights.push({
        type: 'symptom_bloating',
        message: 'Hormonal fluid shifts can slow digestive motility and cause abdominal fullness.',
      });
      suggestions.push({
        type: 'bloating_care',
        suggestion: 'Eat warm, easily digestible foods in smaller portions, limit excess sodium, and enjoy herbal peppermint or fennel tea.',
      });
    }

    if (symptoms.some((s) => s.includes('mood') || s.includes('irritab') || s.includes('anxiety') || s.includes('tearful'))) {
      insights.push({
        type: 'symptom_mood',
        message: 'Neurotransmitters shift alongside estrogen and progesterone. Emotional waves are biological signals, not personal shortcomings.',
      });
      suggestions.push({
        type: 'mood_care',
        suggestion: 'Step outside for fresh air, practice 4-7-8 breathing, and give yourself grace without judgment.',
      });
    }

    return { insights, alerts, suggestions };
  }

  _analyzeLifeStageSpecifics(onboardingAnswers, cycleStartDate, periodEntries = []) {
    const insights = [];
    const alerts = [];
    const suggestions = [];

    const stage = String(onboardingAnswers.life_stage || onboardingAnswers.lifeStage || '').toLowerCase();

    // ── Pregnancy Analysis ─────────────────────────────────────────────────
    const rawDueDate = onboardingAnswers.due_date || onboardingAnswers.dueDate;
    if (stage.includes('pregnan') || rawDueDate) {
      if (rawDueDate) {
        const due = new Date(rawDueDate);
        if (!Number.isNaN(due.getTime())) {
          const today = new Date();
          const todayNorm = new Date(today.getFullYear(), today.getMonth(), today.getDate());
          const dueNorm = new Date(due.getFullYear(), due.getMonth(), due.getDate());
          const diffDays = Math.round((dueNorm.getTime() - todayNorm.getTime()) / 86400000);
          const gestDays = 280 - diffDays;
          const gestWeeks = Math.floor(gestDays / 7);
          const gestDayRemainder = Math.max(0, gestDays % 7);

          if (gestWeeks >= 1 && gestWeeks <= 44) {
            let trimester = 1;
            if (gestWeeks >= 13 && gestWeeks <= 27) trimester = 2;
            if (gestWeeks >= 28) trimester = 3;

            insights.push({
              type: 'pregnancy_gestational_progress',
              message: `You are approximately ${gestWeeks} weeks, ${gestDayRemainder} days along (Trimester ${trimester}). Your body is nurturing vital development every single day.`,
            });

            if (trimester === 1) {
              suggestions.push({
                type: 'pregnancy_trimester_1',
                suggestion: 'Trimester 1 focus: Prioritize active folate/folic acid, stay hydrated with small frequent sips, and manage nausea with bland snacks like crackers before rising.',
              });
            } else if (trimester === 2) {
              suggestions.push({
                type: 'pregnancy_trimester_2',
                suggestion: 'Trimester 2 focus: As energy rebounds, maintain gentle pelvic floor and core stability with walking or prenatal yoga, and consider sleeping on your left side with pillow support.',
              });
            } else {
              suggestions.push({
                type: 'pregnancy_trimester_3',
                suggestion: 'Trimester 3 focus: Rest frequently with feet elevated, practice slow labor breathing, and monitor daily fetal kick counts when resting quietly.',
              });
              alerts.push({
                type: 'pregnancy_third_trimester_safety',
                severity: 'medium',
                title: 'Maternal Safety Note',
                message: 'Contact your OB/GYN or midwife promptly if you notice severe headaches, visual changes, sudden facial/hand swelling, decreased fetal movements, or fluid leakage.',
              });
            }
          }
        }
      }
    }

    // ── Postpartum Analysis ────────────────────────────────────────────────
    const rawBirthDate = onboardingAnswers.baby_birth_date || onboardingAnswers.babyBirthDate;
    if (stage.includes('postpartum') || rawBirthDate) {
      if (rawBirthDate) {
        const birth = new Date(rawBirthDate);
        if (!Number.isNaN(birth.getTime())) {
          const today = new Date();
          const todayNorm = new Date(today.getFullYear(), today.getMonth(), today.getDate());
          const birthNorm = new Date(birth.getFullYear(), birth.getMonth(), birth.getDate());
          const daysElapsed = Math.max(0, Math.round((todayNorm.getTime() - birthNorm.getTime()) / 86400000));
          const weeksElapsed = Math.floor(daysElapsed / 7);

          insights.push({
            type: 'postpartum_milestone',
            message: `You are in week ${weeksElapsed + 1} of your fourth trimester recovery. Tissue healing, uterine involution, and hormone recalibration are actively progressing.`,
          });

          if (weeksElapsed < 6) {
            suggestions.push({
              type: 'postpartum_early_healing',
              suggestion: 'Early postpartum care: Rest whenever possible, practice gentle perineal/incision care, and honor normal lochia flow progression (gradually lightening from red to pink to pale cream).',
            });
          } else {
            suggestions.push({
              type: 'postpartum_gradual_rebuild',
              suggestion: 'Gradual rebuilding: Reconnect gently with transverse abdominal and pelvic floor breathing before resuming high-impact exercise, and attend your comprehensive 6-week postpartum visit.',
            });
          }

          const feeding = String(onboardingAnswers.postpartum_feeding || '').toLowerCase();
          if (feeding.includes('breast') || feeding.includes('nursing')) {
            suggestions.push({
              type: 'lactation_hydration',
              suggestion: 'Lactation hydration: Breastfeeding utilizes significant fluids and electrolytes. Keep a large water bottle at your nursing station and nourish your body with steady protein snacks.',
            });
          }
        }
      }
    }

    // ── Trying To Conceive (TTC) ───────────────────────────────────────────
    if (stage.includes('ttc') || stage.includes('conceive') || stage.includes('fertility')) {
      insights.push({
        type: 'ttc_physiology',
        message: 'Conception science: Healthy conception relies on the 6-day fertile window (5 days prior to ovulation plus ovulation day), guided by estrogenic cervical fluid and an LH surge.',
      });
      suggestions.push({
        type: 'ttc_pacing',
        suggestion: 'Focus on observing fertile cervical fluid signs rather than stress-inducing schedules, and wait until at least 12–14 days post-ovulation before testing to prevent false negatives.',
      });
    }

    // ── First Period / Puberty ─────────────────────────────────────────────
    if (stage.includes('firstperiodnotstarted') || stage.includes('not_started') || stage.includes('puberty')) {
      insights.push({
        type: 'puberty_milestone',
        message: 'Puberty progression: Breast buds (thelarche) and clear or white vaginal discharge (physiological leukorrhea) naturally precede your first period by 6 to 18 months.',
      });
      suggestions.push({
        type: 'puberty_prep',
        suggestion: 'Keep a small, discreet pouch in your school bag with two pads, backup underwear, and wipes so you always feel confident and prepared.',
      });
    }

    // ── Perimenopause / Menopause ──────────────────────────────────────────
    if (stage.includes('peri') || stage.includes('meno')) {
      insights.push({
        type: 'menopause_transition',
        message: 'Hormonal transition: Declining ovarian follicles shift the balance of estrogen and progesterone, changing cycle lengths and thermoregulation.',
      });
      suggestions.push({
        type: 'menopause_vitality',
        suggestion: 'Support bone density and metabolic health with resistance training, calcium and Vitamin D3 nutrition, and restful sleep routines.',
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
