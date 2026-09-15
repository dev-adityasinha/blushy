/**
 * postpartumStateService.js
 * Core state & reasoning engine for the Postpartum Command Center.
 * Computes chronological timing, phase, baseline maturity, daily priorities,
 * and longitudinal comparisons ('What Changed' vs 'What's Been Steady').
 */

import { POSTPARTUM_PHASES, LOCHIA_STAGES, RECOVERY_MILESTONES } from './postpartumData.js';

export class PostpartumStateService {
  /**
   * Computes chronological postpartum timing and orientation.
   */
  static calculateTiming(deliveryDateInput, referenceDate = new Date()) {
    if (!deliveryDateInput) {
      return {
        isConfigured: false,
        deliveryDate: null,
        daysSinceBirth: null,
        weeksSinceBirth: null,
        monthsSinceBirth: null,
        phase: null,
        phaseName: 'Not Calibrated',
        phaseDescription: 'Set your delivery date to calibrate your personal 4th trimester recovery path.',
        currentMilestone: null,
      };
    }

    const birth = new Date(deliveryDateInput);
    if (Number.isNaN(birth.getTime())) {
      return {
        isConfigured: false,
        deliveryDate: null,
        daysSinceBirth: null,
        weeksSinceBirth: null,
        monthsSinceBirth: null,
        phase: null,
        phaseName: 'Invalid Date',
        phaseDescription: 'Please provide a valid delivery date.',
        currentMilestone: null,
      };
    }

    const now = new Date(referenceDate);
    const msPerDay = 24 * 60 * 60 * 1000;
    const diffDays = Math.floor((now.getTime() - birth.getTime()) / msPerDay);
    const daysSinceBirth = Math.max(0, Math.min(365, diffDays));
    const weeksSinceBirth = Math.floor(daysSinceBirth / 7);
    const monthsSinceBirth = Math.floor(daysSinceBirth / 30.44);

    let phaseKey = 'immediate';
    if (daysSinceBirth <= 7) phaseKey = 'immediate';
    else if (daysSinceBirth <= 42) phaseKey = 'early';
    else if (daysSinceBirth <= 180) phaseKey = 'extended';
    else phaseKey = 'transition';

    const phaseConfig = POSTPARTUM_PHASES[phaseKey.toUpperCase()] || POSTPARTUM_PHASES.IMMEDIATE;

    // Determine current/next recovery milestone
    let milestone = RECOVERY_MILESTONES[0];
    for (const m of RECOVERY_MILESTONES) {
      if (daysSinceBirth >= m.day) {
        milestone = m;
      }
    }

    return {
      isConfigured: true,
      deliveryDate: birth.toISOString().slice(0, 10),
      daysSinceBirth,
      weeksSinceBirth,
      monthsSinceBirth,
      phase: phaseKey,
      phaseName: phaseConfig.name,
      phaseRange: phaseConfig.range,
      phaseDescription: phaseConfig.description,
      primaryFocus: phaseConfig.primaryFocus,
      currentMilestone: milestone,
    };
  }

  /**
   * Computes baseline maturity without premature claims of "normal".
   */
  static computeBaselineMaturity(checkinHistory = []) {
    const count = checkinHistory.length;
    if (count < 3) {
      return {
        tier: 'building',
        label: 'Building Your Baseline',
        description: 'Keep checking in for a few days and Blushy will start learning what feels typical for you.',
        dataPointsCount: count,
        readyForBaseline: false,
      };
    }
    if (count < 7) {
      return {
        tier: 'pattern',
        label: 'Your Emerging Pattern',
        description: 'Based on your recent check-ins, here is the recovery rhythm taking shape.',
        dataPointsCount: count,
        readyForBaseline: true,
      };
    }
    return {
      tier: 'usual',
      label: 'Your Usual Rhythm',
      description: 'Derived from consistent longitudinal logs over your recovery.',
      dataPointsCount: count,
      readyForBaseline: true,
    };
  }

  /**
   * "Today, I'd Prioritize": dynamically selects 2–3 personalized priorities.
   */
  static determinePriorities({ timing, todayCheckin, yesterdayCheckin, recentCheckins = [] }) {
    const priorities = [];

    const sleepHours = todayCheckin?.sleepHours ?? yesterdayCheckin?.sleepHours ?? 5;
    const mood = (todayCheckin?.mood ?? yesterdayCheckin?.mood ?? 'okay').toLowerCase();
    const physicalComfort = (todayCheckin?.physicalComfort ?? yesterdayCheckin?.physicalComfort ?? 'okay').toLowerCase();
    const bleeding = (todayCheckin?.bleedingLevel ?? yesterdayCheckin?.bleedingLevel ?? 'moderate').toLowerCase();

    // Priority 1: Sleep / Rest Triage
    if (sleepHours < 5 || mood === 'exhausted' || physicalComfort === 'exhausted') {
      priorities.push({
        id: 'p_rest',
        category: 'Rest',
        icon: 'bed',
        headline: 'Rest & Nap Conservation',
        reason: `You logged ${sleepHours}h of sleep. Uninterrupted recovery matters more than tasks today.`,
        actionTag: 'Ask partner to take next wake-up',
      });
    }

    // Priority 2: Physical Tissue Healing / Lochia
    if (bleeding === 'heavy' || physicalComfort === 'sore' || physicalComfort === 'something feels off') {
      priorities.push({
        id: 'p_tissue',
        category: 'Tissue Recovery',
        icon: 'spa',
        headline: 'Horizontal Pelvic & Wound Care',
        reason: physicalComfort === 'sore'
          ? 'Increased soreness suggests your body wants less standing load today.'
          : 'Active lochia requires horizontal recovery and hydration.',
        actionTag: 'Warm sitz bath or ice pack',
      });
    }

    // Priority 3: Mental Health & Emotional Regulation
    const overwhelmedCount = recentCheckins.filter(
      (c) => (c.mood || '').toLowerCase().includes('overwhelm') || (c.mood || '').toLowerCase().includes('tearful')
    ).length;

    if (mood === 'overwhelmed' || mood === 'tearful' || mood === 'low' || overwhelmedCount >= 2) {
      priorities.push({
        id: 'p_support',
        category: 'Emotional Support',
        icon: 'heart',
        headline: 'Decompressing Emotional Load',
        reason: overwhelmedCount >= 2
          ? 'You have reported feeling overwhelmed across multiple recent check-ins.'
          : 'Hormonal resets in early postpartum require shared care, not solitary endurance.',
        actionTag: 'Activate Support Circle or Talk to Docsy',
      });
    }

    // Fallbacks if fewer than 2 priorities
    if (priorities.length < 2) {
      priorities.push({
        id: 'p_hydration',
        category: 'Nourishment',
        icon: 'water_drop',
        headline: 'Electrolytes & Tissue Nutrition',
        reason: 'Lactation and uterine remodeling demand 2.5–3L of fluids and protein daily.',
        actionTag: 'Keep water bottle at feeding station',
      });
    }

    if (priorities.length < 3 && (!timing || !timing.isConfigured || timing.daysSinceBirth == null || timing.daysSinceBirth <= 14)) {
      priorities.push({
        id: 'p_baby_blues',
        category: 'Gentle Pacing',
        icon: 'self_improvement',
        headline: 'Honor Your 4th Trimester Tempo',
        reason: 'In early postpartum, simply resting and nourishing yourself and baby is a 100% complete day.',
        actionTag: 'You do not need to accomplish chores',
      });
    }

    return priorities.slice(0, 3);
  }

  /**
   * Evaluates longitudinal changes: "What Changed?" AND "What's Been Steady".
   */
  static evaluateDeltas({ todayCheckin, yesterdayCheckin, recentCheckins = [] }) {
    const changes = [];
    const steady = [];

    if (!todayCheckin || !yesterdayCheckin) {
      return {
        hasData: false,
        changes: [],
        steady: [
          'Log your check-in today and tomorrow to view longitudinal recovery deltas.',
        ],
      };
    }

    // Pain comparisons
    const todayPain = todayCheckin.painScore ?? 2;
    const yesterdayPain = yesterdayCheckin.painScore ?? 2;
    if (todayPain > yesterdayPain + 1) {
      changes.push({
        type: 'shift',
        metric: 'Pain & Comfort',
        detail: `Your pain score shifted higher today (${todayPain}/10 vs ${yesterdayPain}/10 yesterday).`,
        context: 'Pain often increases after an unusually active day or standing prolonged periods.',
        isImportant: todayPain >= 6,
      });
    } else if (todayPain < yesterdayPain) {
      changes.push({
        type: 'improvement',
        metric: 'Pain & Comfort',
        detail: `Your physical comfort improved today (${todayPain}/10 vs ${yesterdayPain}/10 yesterday).`,
        context: 'Indicates acute tissue remodeling is settling down nicely.',
        isImportant: false,
      });
    } else {
      steady.push(`Your comfort level has stayed steady around ${todayPain}/10.`);
    }

    // Bleeding comparisons
    const todayBleed = (todayCheckin.bleedingLevel || 'moderate').toLowerCase();
    const yesterdayBleed = (yesterdayCheckin.bleedingLevel || 'moderate').toLowerCase();
    if (todayBleed !== yesterdayBleed) {
      changes.push({
        type: 'shift',
        metric: 'Lochia Flow',
        detail: `Bleeding shifted from ${yesterdayBleed} to ${todayBleed}.`,
        context: todayBleed === 'heavy' && yesterdayBleed === 'light'
          ? 'Sudden heavier flow usually signals it is time to lie down and rest.'
          : 'A progressive lightening of color and flow is the hallmark of uterine healing.',
        isImportant: todayBleed === 'heavy',
      });
    } else {
      steady.push(`Your lochia bleeding has remained ${todayBleed} without abrupt surges.`);
    }

    // Sleep comparisons
    const todaySleep = todayCheckin.sleepHours ?? 5;
    const yesterdaySleep = yesterdayCheckin.sleepHours ?? 5;
    if (Math.abs(todaySleep - yesterdaySleep) >= 2) {
      changes.push({
        type: todaySleep < yesterdaySleep ? 'shift' : 'improvement',
        metric: 'Sleep Recovery',
        detail: `You got ${todaySleep}h of rest (compared to ${yesterdaySleep}h the night before).`,
        context: todaySleep < yesterdaySleep
          ? 'Sleep deficits compound quickly; prioritize resting whenever your baby is down.'
          : 'A longer stretch of consolidated sleep provides significant neurological recovery.',
        isImportant: todaySleep <= 3,
      });
    } else {
      steady.push(`Your sleep duration has averaged ${todaySleep}h across night stretches.`);
    }

    return {
      hasData: true,
      changes,
      steady,
    };
  }
}
