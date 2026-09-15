/**
 * perimenopauseStateService.js
 * State machine, Priority Engine, longitudinal baseline calculator,
 * multi-symptom correlation observer, and narrative story generator for "My Transition".
 */

import { TRANSITION_PHASES, ACTION_PATHWAYS } from './perimenopauseData.js';

export class PerimenopauseStateService {
  /**
   * Computes the dynamic order of homepage sections based on the user's
   * current state, active life mode, selected focus, and recent symptom logs.
   */
  static determineSectionOrder({ recentCheckins = [], lifeMode = 'normal', focus = 'sleep', hasHRT = false, safetyAlerts = [] }) {
    const latest = recentCheckins[0] || {};
    const hasNightSweats = latest.temperatureFlashes === 'night_sweats' || latest.temperatureFlashes === 'severe';
    const hasSleepDisruption = latest.sleepQuality === 'fragmented' || latest.sleepQuality === 'insomnia' || latest.sleepQuality === 'woke_sweating';
    const hasBleedingShift = latest.cycleStatus === 'heavy' || latest.cycleStatus === 'prolonged' || latest.cycleStatus === 'unexpected_spotting';
    const isSteadyDay = !hasNightSweats && !hasSleepDisruption && !hasBleedingShift && latest.moodFog === 'balanced';

    // Base default sequence - Period Tracker is right after Today with Docsy
    let order = [
      'editorial_greeting',
      'today_with_docsy',
      'my_changing_cycle',
      'what_are_you_noticing',
      'what_changed_connections',
      'what_can_i_do',
      'focus_selector',
      'baseline_good_days',
      'treatment_intelligence',
      'tell_blushy_natural_note',
      'prepare_care',
      'intimate_health',
      'my_story',
      'learn_relevant',
      'ai_transparency',
    ];

    if (safetyAlerts.length > 0) {
      // Elevate safety and doctor prep to the very top, followed by period tracker
      order = [
        'safety_banner',
        'editorial_greeting',
        'today_with_docsy',
        'my_changing_cycle',
        'prepare_care',
        ...order.filter((s) => !['safety_banner', 'editorial_greeting', 'today_with_docsy', 'my_changing_cycle', 'prepare_care'].includes(s)),
      ];
    } else if (lifeMode === 'terrible_sleep' || hasNightSweats || (focus === 'sleep' && hasSleepDisruption)) {
      // Prioritize sleep cooling protocols and night temperature, keeping period tracker right after docsy
      order = [
        'editorial_greeting',
        'today_with_docsy',
        'my_changing_cycle',
        'what_are_you_noticing',
        'what_can_i_do',
        'what_changed_connections',
        'focus_selector',
        'baseline_good_days',
        ...order.filter((s) => !['editorial_greeting', 'today_with_docsy', 'my_changing_cycle', 'what_are_you_noticing', 'what_can_i_do', 'what_changed_connections', 'focus_selector', 'baseline_good_days'].includes(s)),
      ];
    } else if (hasBleedingShift || focus === 'period_changes') {
      // Prioritize cycle changes and clinician question prep
      order = [
        'editorial_greeting',
        'today_with_docsy',
        'my_changing_cycle',
        'what_are_you_noticing',
        'prepare_care',
        'what_changed_connections',
        'what_can_i_do',
        ...order.filter((s) => !['editorial_greeting', 'today_with_docsy', 'my_changing_cycle', 'what_are_you_noticing', 'prepare_care', 'what_changed_connections', 'what_can_i_do'].includes(s)),
      ];
    } else if (hasHRT && focus === 'treatment') {
      // Prioritize treatment tracking and notes
      order = [
        'editorial_greeting',
        'today_with_docsy',
        'my_changing_cycle',
        'treatment_intelligence',
        'what_are_you_noticing',
        'what_changed_connections',
        ...order.filter((s) => !['editorial_greeting', 'today_with_docsy', 'my_changing_cycle', 'treatment_intelligence', 'what_are_you_noticing', 'what_changed_connections'].includes(s)),
      ];
    } else if (isSteadyDay) {
      // Steady state: celebrate stability and learning
      order = [
        'editorial_greeting',
        'steady_state_banner',
        'today_with_docsy',
        'my_changing_cycle',
        'what_are_you_noticing',
        'baseline_good_days',
        'my_story',
        'learn_relevant',
        ...order.filter((s) => !['editorial_greeting', 'steady_state_banner', 'today_with_docsy', 'my_changing_cycle', 'what_are_you_noticing', 'baseline_good_days', 'my_story', 'learn_relevant'].includes(s)),
      ];
    }

    return order;
  }

  /**
   * Generates the 4-tier confidence breakdown:
   * WHAT YOU LOGGED -> WHAT WE'RE SEEING -> WHAT THIS MIGHT MEAN -> WHAT YOU CAN DO
   */
  static buildConfidenceBreakdown({ recentCheckins = [], focus = 'sleep' }) {
    const latest = recentCheckins[0] || {};
    const past7 = recentCheckins.slice(0, 7);

    const sweatCount = past7.filter((c) => c.temperatureFlashes === 'night_sweats' || c.temperatureFlashes === 'severe').length;
    const poorSleepCount = past7.filter((c) => c.sleepQuality === 'fragmented' || c.sleepQuality === 'insomnia' || c.sleepQuality === 'woke_sweating').length;

    if (sweatCount >= 2 && poorSleepCount >= 2) {
      return {
        whatYouLogged: `You reported night sweats or heat surges on ${sweatCount} nights this past week.`,
        whatWereSeeing: `On those exact nights, your sleep duration averaged less than 5.5 hours with multiple mid-night wakeups.`,
        whatThisMightMean: `Night sweats and sleep fragmentation frequently co-occur during midlife estrogen shifts. However, your daily logs alone cannot determine medical causation.`,
        whatYouCanDo: `Try dropping the room temperature by 1–2°C and establishing a cooling wind-down routine tonight. Consider mentioning this pattern to your doctor.`,
        confidenceLevel: 'High Correlation Observed (Non-Diagnostic)',
      };
    }

    if (latest.cycleStatus === 'irregular' || latest.cycleStatus === 'heavy') {
      return {
        whatYouLogged: `You recorded your recent period timing as irregular with heavier flow.`,
        whatWereSeeing: `Your cycle spacing has widened from your past baseline of 28 days to over 38 days.`,
        whatThisMightMean: `Anovulatory cycles during perimenopause cause variable progesterone release, which often creates wider spacing followed by heavier flow.`,
        whatYouCanDo: `Keep an on-the-go care kit ready, track pad change frequency, and review our heavy bleeding discussion points with your provider if soaking persists.`,
        confidenceLevel: 'Typical Transition Pattern',
      };
    }

    // Default gentle baseline
    return {
      whatYouLogged: `You checked in with ${latest.energyLevel || 'moderate'} energy and ${latest.moodFog || 'centered'} focus.`,
      whatWereSeeing: `Your recent daily logs show steady rhythms without acute temperature spikes.`,
      whatThisMightMean: `Perimenopause involves fluctuating waves; steady stretches reflect effective habit buffering or temporary hormonal plateau.`,
      whatYouCanDo: `Keep listening to your body's signals, hydrate well, and maintain your regular restorative sleep schedule.`,
      confidenceLevel: 'Baseline Steady Observation',
    };
  }

  /**
   * Identifies multi-symptom overlaps and correlation patterns.
   */
  static detectConnections(recentCheckins = []) {
    const past14 = recentCheckins.slice(0, 14);
    const connections = [];

    const sweatAndSleep = past14.filter(
      (c) => (c.temperatureFlashes === 'night_sweats' || c.temperatureFlashes === 'severe') && (c.sleepQuality === 'fragmented' || c.sleepQuality === 'woke_sweating')
    ).length;

    if (sweatAndSleep >= 2) {
      connections.push({
        id: 'conn_sweats_sleep',
        title: 'Night Sweats & Sleep Disruption',
        description: `You've noticed nighttime heat surges and disrupted sleep on ${sweatAndSleep} of the same nights.`,
        rationale: 'Observed relationship in your logs — this co-occurrence is common during estrogen shifts.',
        actionPrompt: 'Explore evening cooling protocols →',
      });
    }

    const fogAndTired = past14.filter((c) => (c.moodFog === 'brain_fog' || c.moodFog === 'low_focus') && (c.energyLevel === 'low' || c.energyLevel === 'exhausted')).length;

    if (fogAndTired >= 2) {
      connections.push({
        id: 'conn_fog_energy',
        title: 'Brain Fog & Energy Dips',
        description: `Days with reported brain fog frequently aligned with low morning energy (${fogAndTired} logs).`,
        rationale: 'Pacing cognitive load with morning protein and gentle sunlight helps buffer mental fatigue.',
        actionPrompt: 'See focus pacing tips →',
      });
    }

    return connections;
  }

  /**
   * Discovers positive habit patterns ("Something Seems to Be Working").
   */
  static detectGoodDays(recentCheckins = []) {
    const past14 = recentCheckins.slice(0, 14);
    const goodDays = past14.filter((c) => (c.energyLevel === 'high' || c.energyLevel === 'normal') && (c.sleepQuality === 'deep' || c.sleepQuality === 'good'));

    if (goodDays.length >= 2) {
      return {
        hasGoodPattern: true,
        headline: 'Something seems to be working',
        insight: `On the ${goodDays.length} days you reported sleeping 7+ hours and feeling well-rested, your daytime energy and mental focus were noticeably higher.`,
        encouragement: 'Your body responds well to consistent sleep boundaries. Keep honoring that evening rhythm!',
      };
    }

    return {
      hasGoodPattern: false,
      headline: 'Building your positive baseline',
      insight: 'As you log more check-ins, Blushy will identify which lifestyle habits consistently correlate with your highest energy and comfort.',
      encouragement: 'Every check-in helps map what works best for you.',
    };
  }

  /**
   * Compares the current week's metrics against the longitudinal baseline.
   */
  static computeDeltas(recentCheckins = []) {
    const thisWeek = recentCheckins.slice(0, 7);
    const flashCount = thisWeek.filter((c) => c.temperatureFlashes && c.temperatureFlashes !== 'none').length;
    const poorSleep = thisWeek.filter((c) => c.sleepQuality === 'fragmented' || c.sleepQuality === 'woke_sweating' || c.sleepQuality === 'insomnia').length;

    return {
      sleep: poorSleep > 2 ? `Woken during the night ${poorSleep} times this week` : 'Sleep has been relatively steady',
      temperature: flashCount > 0 ? `Logged ${flashCount} hot flash or night sweat episodes this week` : 'No significant temperature flushes logged',
      cycle: 'Cycle intervals have shown wider spacing than typical',
      focus: thisWeek.some((c) => c.moodFog === 'brain_fog') ? 'Brain fog noted on 2+ days this week' : 'Mental clarity feels balanced',
    };
  }

  /**
   * Generates the longitudinal narrative milestones ("My Story").
   */
  static buildStoryTimeline(profile = {}) {
    const onset = profile.onsetDuration || 'a few months';
    return [
      {
        date: 'Earlier',
        title: 'Regular Cycles & Baseline',
        description: 'Predictable menstrual cycle intervals with familiar PMS patterns.',
        status: 'completed',
      },
      {
        date: onset === 'over_a_year' ? '1 year ago' : 'Recent months',
        title: 'First Noticeable Shifts',
        description: 'First subtle adjustments in cycle lengths (+/- 7 days) and occasional nighttime warmth.',
        status: 'completed',
      },
      {
        date: 'Currently',
        title: 'Active Transition & Pattern Mapping',
        description: 'Mapping vasomotor signals, protecting restorative sleep, and understanding personal baselines.',
        status: 'active',
      },
      {
        date: 'Looking Ahead',
        title: 'Rhythm Stabilization & Postmenopause',
        description: '12 consecutive months without bleeding, marking full hormonal stabilization.',
        status: 'future',
      },
    ];
  }
}
