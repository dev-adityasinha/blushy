/**
 * perimenopauseService.js
 * Comprehensive orchestration, state storage, and business logic for "My Transition" (Perimenopause).
 */

import { PerimenopauseStateService } from './perimenopauseStateService.js';
import { DocsyPerimenopauseService } from './docsyPerimenopauseService.js';
import { resolveUserLanguage } from '../utils/language.js';
import {
  TRANSITION_PHASES,
  ACTION_PATHWAYS,
  CLINICIAN_DISCUSSION_TOPICS,
  CONTEXTUAL_ARTICLES,
} from './perimenopauseData.js';
import { todayIso } from '../utils/appCalendar.js';
import { makeUserDocStore } from '../repositories/stageStateRepository.js';

// One document per user in Mongo, replacing the process-level Maps that were
// lost on restart and never shared across instances.
const store = makeUserDocStore('perimenopause_state', {
  profile: () => ({
    onsetDuration: 'a_few_months',
    primaryConcerns: ['My periods', 'My sleep', 'My temperature'],
    focus: 'sleep',
    lifeMode: 'normal',
    isCalibrated: true,
  }),
  checkins: () => [],
  cycleHistory: () => [],
  treatments: () => [],
  questions: () => [],
  notes: () => [],
});

export class PerimenopauseService {
  /**
   * Retrieves or initializes the user's Perimenopause profile.
   */
  static async getProfile(userId) {
    const state = await store.load(userId);
    return state.profile;
  }

  /**
   * Initial "Tell Blushy Once" calibration.
   */
  static async calibrate(userId, { onsetDuration, primaryConcerns = [], focus = 'sleep' }) {
    const state = await store.load(userId);
    const profile = state.profile;
    if (onsetDuration !== undefined) profile.onsetDuration = onsetDuration;
    if (Array.isArray(primaryConcerns) && primaryConcerns.length > 0) profile.primaryConcerns = primaryConcerns;
    if (focus !== undefined) profile.focus = focus;
    profile.isCalibrated = true;
    await store.save(userId, state);
    return profile;
  }

  /**
   * Updates the user's active focus area.
   */
  static async setFocus(userId, focus) {
    const state = await store.load(userId);
    state.profile.focus = focus;
    await store.save(userId, state);
    return state.profile;
  }

  /**
   * Updates the active life mode.
   */
  static async setLifeMode(userId, lifeMode) {
    const state = await store.load(userId);
    state.profile.lifeMode = lifeMode;
    await store.save(userId, state);
    return state.profile;
  }

  /**
   * Logs a daily maternal check-in with severity + impact + context.
   */
  static async recordCheckin(userId, data = {}) {
    const state = await store.load(userId);
    const checkins = state.checkins;
    const date = todayIso();

    const record = {
      id: `peri_chk_${Date.now()}`,
      date,
      timestamp: new Date().toISOString(),
      temperatureFlashes: data.temperatureFlashes ?? 'none', // 'none' | 'mild' | 'moderate' | 'night_sweats' | 'severe' | 'unsure'
      sleepQuality: data.sleepQuality ?? 'good', // 'deep' | 'good' | 'fragmented' | 'woke_sweating' | 'insomnia' | 'unsure'
      moodFog: data.moodFog ?? 'balanced', // 'balanced' | 'brain_fog' | 'mood_swings' | 'anxious' | 'low_energy' | 'unsure'
      cycleStatus: data.cycleStatus ?? 'none', // 'none' | 'spotting' | 'light' | 'moderate' | 'heavy' | 'prolonged' | 'irregular'
      intimateHealth: data.intimateHealth ?? 'comfortable', // 'comfortable' | 'dryness' | 'sensitive' | 'low_libido' | 'unsure'
      energyLevel: data.energyLevel ?? 'normal', // 'high' | 'normal' | 'low' | 'exhausted'
      botherImpact: data.botherImpact ?? 'a_little', // 'not_at_all' | 'a_little' | 'quite_a_bit' | 'overwhelming'
      contextTags: Array.isArray(data.contextTags) ? data.contextTags : [], // e.g. ['late_coffee', 'stressful_day', 'exercise']
      botherLevel: data.botherLevel ?? 2, // 1–5 slider
      userNote: data.userNote ?? '',
    };

    // Replace if logged today, otherwise prepend
    const existingIndex = checkins.findIndex((c) => c.date === date);
    if (existingIndex >= 0) {
      checkins[existingIndex] = record;
    } else {
      checkins.unshift(record);
    }

    await store.save(userId, state);
    return record;
  }

  /**
   * Retrieves cycle history intervals.
   */
  static async getCycleHistory(userId) {
    const state = await store.load(userId);
    return state.cycleHistory;
  }

  /**
   * Logs a new period interval.
   */
  static async recordPeriodCycle(userId, lengthDays = 28) {
    const state = await store.load(userId);
    const history = state.cycleHistory;
    if (typeof lengthDays === 'number' && lengthDays > 0) {
      history.push(lengthDays);
      if (history.length > 8) history.shift();
      await store.save(userId, state);
    }
    return history;
  }

  /**
   * Adds or updates a treatment regimen.
   */
  static async saveTreatment(userId, treatmentData = {}) {
    const state = await store.load(userId);
    const treatments = state.treatments;
    const item = {
      id: treatmentData.id || `trt_${Date.now()}`,
      name: treatmentData.name || 'Treatment',
      category: treatmentData.category || 'hrt', // 'hrt' | 'non_hormonal' | 'supplement' | 'lifestyle'
      dosage: treatmentData.dosage || '',
      startDate: treatmentData.startDate || todayIso(),
      notes: treatmentData.notes || '',
      whatNotice: treatmentData.whatNotice || 'Feeling more stable sleep',
    };

    const existingIdx = treatments.findIndex((t) => t.id === item.id);
    if (existingIdx >= 0) {
      treatments[existingIdx] = item;
    } else {
      treatments.push(item);
    }
    await store.save(userId, state);
    return item;
  }

  /**
   * Adds a question to the clinician appointment notebook.
   */
  static async addQuestion(userId, questionText = '') {
    const state = await store.load(userId);
    if (state.questions.length === 0) {
      state.questions = [
        { id: 'q_init_1', text: 'Should we check my iron levels given recent heavy periods?', dateAdded: todayIso() },
        { id: 'q_init_2', text: 'Are my waking night sweats a reason to consider local or transdermal HRT?', dateAdded: todayIso() },
      ];
    }
    const newQ = { id: `q_${Date.now()}`, text: questionText.trim(), dateAdded: todayIso() };
    state.questions.push(newQ);
    await store.save(userId, state);
    return newQ;
  }

  /**
   * Deletes a question from the appointment notebook.
   */
  static async deleteQuestion(userId, questionId) {
    const state = await store.load(userId);
    const before = state.questions.length;
    state.questions = state.questions.filter((q) => q.id !== questionId);
    await store.save(userId, state);
    return state.questions.length !== before;
  }

  /**
   * Parses natural text/voice notes and saves to timeline.
   */
  static async parseNaturalNote(userId, text = '') {
    const result = await DocsyPerimenopauseService.parseNaturalNote(text);
    if (result.success) {
      const state = await store.load(userId);
      state.notes.unshift({
        id: `note_${Date.now()}`,
        date: todayIso(),
        text,
        extracted: result.extracted,
      });
      await store.save(userId, state);
    }
    return result;
  }

  /**
   * Generates the comprehensive Overview payload for the frontend dashboard.
   */
  static async getOverview(userId) {
    const state = await store.load(userId);
    const profile = state.profile;
    const checkins = state.checkins;
    const cycleHistory = state.cycleHistory;
    // An empty store still shows seeded examples, exactly as the Map version did.
    const treatments = state.treatments.length ? state.treatments : [
      {
        id: 'trt_default',
        name: 'Evening Magnesium & Cooling Routine',
        category: 'lifestyle',
        dosage: '300mg before bed',
        startDate: '2026-08-01',
        whatNotice: 'Helps relax muscles and shorten time to fall asleep',
        notes: 'Discussed with clinician last check-up',
      },
    ];
    const questions = state.questions.length ? state.questions : [
      { id: 'q_1', text: 'Are my night sweats an indication to discuss transdermal estrogen?', dateAdded: 'Recent' },
      { id: 'q_2', text: 'Should we test my ferritin / iron levels after wider cycle spacing?', dateAdded: 'Recent' },
    ];

    // Evaluate Safety Alerts
    const latest = checkins[0] || {};
    const safetyAlerts = [];
    if (latest.cycleStatus === 'prolonged' || (latest.cycleStatus === 'heavy' && latest.botherImpact === 'overwhelming')) {
      safetyAlerts.push({
        id: 'heavy_bleeding_alert',
        title: 'Unusually Heavy or Prolonged Bleeding',
        message: 'You noted heavy bleeding that feels overwhelming. If you are soaking more than 2 pads an hour for consecutive hours or feeling faint, contact a healthcare provider promptly.',
        severity: 'urgent',
      });
    }

    // Determine Dynamic Section Sequence via Priority Engine
    const sectionOrder = PerimenopauseStateService.determineSectionOrder({
      recentCheckins: checkins,
      lifeMode: profile.lifeMode,
      focus: profile.focus,
      hasHRT: treatments.some((t) => t.category === 'hrt'),
      safetyAlerts,
    });

    // Compute Confidence Layer, Deltas, Connections, Good Days, and Story
    const confidence = PerimenopauseStateService.buildConfidenceBreakdown({ recentCheckins: checkins, focus: profile.focus });
    const deltas = PerimenopauseStateService.computeDeltas(checkins);
    const connections = PerimenopauseStateService.detectConnections(checkins);
    const goodDays = PerimenopauseStateService.detectGoodDays(checkins);
    const story = PerimenopauseStateService.buildStoryTimeline(profile);

    return {
      profile,
      sectionOrder,
      transitionPhase: TRANSITION_PHASES.ACTIVE,
      cycleHistory,
      todayCheckin: latest,
      confidence,
      deltas,
      connections,
      goodDays,
      actionPathways: ACTION_PATHWAYS,
      clinicianTopics: CLINICIAN_DISCUSSION_TOPICS,
      contextualArticles: CONTEXTUAL_ARTICLES,
      treatments,
      questions,
      story,
      safetyAlerts,
    };
  }

  /**
   * Generates the dynamic AI daily brief.
   */
  static async getTodayBrief(userId) {
    const state = await store.load(userId);
    const profile = state.profile;
    const checkins = state.checkins;
    const confidence = PerimenopauseStateService.buildConfidenceBreakdown({ recentCheckins: checkins, focus: profile.focus });
    const deltas = PerimenopauseStateService.computeDeltas(checkins);
    const connections = PerimenopauseStateService.detectConnections(checkins);

    return DocsyPerimenopauseService.generateDailyBrief({
      languageCode: await resolveUserLanguage(userId),
      profile,
      recentCheckins: checkins,
      confidence,
      deltas,
      connections,
      focus: profile.focus,
      lifeMode: profile.lifeMode,
    });
  }

  /**
   * Generates a 1-page Clinician Brief for doctor appointments.
   */
  static async getClinicianBrief(userId) {
    const state = await store.load(userId);
    const profile = state.profile;
    const checkins = state.checkins;
    const cycleHistory = state.cycleHistory;
    const treatments = state.treatments;
    const questions = state.questions;

    const flashCount = checkins.slice(0, 14).filter((c) => c.temperatureFlashes && c.temperatureFlashes !== 'none').length;
    const poorSleepCount = checkins.slice(0, 14).filter((c) => c.sleepQuality === 'fragmented' || c.sleepQuality === 'woke_sweating').length;

    return {
      patientName: 'Ananya',
      reportDate: todayIso(),
      transitionPhase: 'Active Perimenopause',
      cycleVariability: {
        recentIntervals: cycleHistory,
        summary: cycleHistory.length > 0
          ? `Cycles varying from ${Math.min(...cycleHistory)} to ${Math.max(...cycleHistory)} days.`
          : 'No historical cycle intervals recorded yet.',
      },
      symptomTrends14Days: {
        hotFlashesEpisodes: flashCount,
        nightSweatsDisruptedNights: poorSleepCount,
        predominantBother: 'Sleep fragmentation & nighttime temperature flushes',
      },
      activeTreatments: treatments,
      questionsToDiscuss: questions.map((q) => q.text),
    };
  }
}
