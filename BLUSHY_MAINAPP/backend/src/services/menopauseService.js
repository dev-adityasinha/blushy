/**
 * menopauseService.js
 * Comprehensive orchestration and business logic for Menopause:
 * "Understanding your body. Protecting your health. Living fully."
 */

import { MenopauseStateService } from './menopauseStateService.js';
import { DocsyMenopauseService } from './docsyMenopauseService.js';
import { resolveUserLanguage } from '../utils/language.js';
import {
  MENOPAUSE_DOMAINS,
  TEACH_ME_IN_30_SECONDS,
  LIFE_MODES,
  COMMON_TREATMENTS,
  POSTMENOPAUSAL_BLEEDING_ALERT,
} from './menopauseData.js';

export class MenopauseService {
  /**
   * Generates the comprehensive dashboard overview payload.
   */
  static async getOverview(userId = 'default_user', profile = {}) {
    const state = MenopauseStateService.getState();
    const lifeMode = MenopauseStateService.getLifeMode();
    const privateMode = MenopauseStateService.getPrivateMode();
    const checkins = state.checkins || [];
    const questions = MenopauseStateService.getQuestions();
    const treatments = MenopauseStateService.getTreatments();

    const myNormal = MenopauseStateService.computeMyNormal();
    const { whatChanged, whatBeenSteady } = MenopauseStateService.computeWhatChangedAndSteady();
    const treatmentResponse = MenopauseStateService.computeTreatmentResponse();
    const sectionOrder = MenopauseStateService.determineSectionOrder();

    const todayBrief = await DocsyMenopauseService.generateDailyBrief({
      languageCode: await resolveUserLanguage(userId),
      profile,
      checkins,
      myNormal,
      whatChanged,
      whatBeenSteady,
      lifeMode,
      treatments,
    });

    const hasBleeding = checkins.some((c) => c.bleedingLogged === true);
    const safetyAlert = hasBleeding ? POSTMENOPAUSAL_BLEEDING_ALERT : null;

    // Narrative Health Story milestones
    const healthStory = [
      {
        stage: 'Perimenopause',
        timing: 'Prior Years',
        title: 'Cycle Rhythms Shifted',
        desc: 'Periods became spaced and variable as ovulation timing fluctuated naturally.',
        icon: 'change_circle_rounded',
        colorHex: '0xFF7209B7',
      },
      {
        stage: 'Transition Milestone',
        timing: '12 Months Without Bleeding',
        title: 'Menopause Reached',
        desc: 'A full 365 days passed without a period, confirming transition into postmenopause.',
        icon: 'task_alt_rounded',
        colorHex: '0xFF0D9488',
      },
      {
        stage: 'New Chapter',
        timing: 'Present Day',
        title: 'Protecting Long-Term Health',
        desc: 'Focus has shifted to bone density, cardiovascular elasticity, intimate comfort, and restful sleep.',
        icon: 'spa_rounded',
        colorHex: '0xFF2563EB',
      },
    ];

    return {
      lifeStage: 'menopause',
      chapterTitle: 'Your New Chapter',
      subheading: 'Understanding your body. Protecting your health. Living fully.',
      lifeMode,
      lifeModeDetails: LIFE_MODES[lifeMode.toUpperCase()] || LIFE_MODES.NORMAL,
      privateMode,
      sectionOrder,
      safetyAlert,
      todayWithDocsy: todayBrief,
      myNormal,
      whatChanged,
      whatBeenSteady,
      healthDomains: Object.values(MENOPAUSE_DOMAINS),
      domains: Object.values(MENOPAUSE_DOMAINS),
      treatments,
      treatmentResponse,
      questions,
      teachMeIn30Seconds: TEACH_ME_IN_30_SECONDS,
      healthStory,
      recentCheckinsCount: checkins.length,
      lastCheckin: checkins[0] || null,
    };
  }

  static async getTodayBrief(userId = 'default_user', profile = {}) {
    const state = MenopauseStateService.getState();
    const lifeMode = MenopauseStateService.getLifeMode();
    const checkins = state.checkins || [];
    const myNormal = MenopauseStateService.computeMyNormal();
    const { whatChanged, whatBeenSteady } = MenopauseStateService.computeWhatChangedAndSteady();
    const treatments = MenopauseStateService.getTreatments();

    const brief = await DocsyMenopauseService.generateDailyBrief({
      languageCode: await resolveUserLanguage(userId),
      profile,
      checkins,
      myNormal,
      whatChanged,
      whatBeenSteady,
      lifeMode,
      treatments,
    });

    return {
      todayBrief: brief,
      sectionOrder: MenopauseStateService.determineSectionOrder(),
      lifeMode,
    };
  }

  static recordCheckin(userId = 'default_user', checkinData = {}) {
    return MenopauseStateService.recordCheckin(checkinData);
  }

  static setLifeMode(userId = 'default_user', modeKey = 'normal') {
    return MenopauseStateService.setLifeMode(modeKey);
  }

  static setPrivateMode(userId = 'default_user', enabled = false) {
    return MenopauseStateService.setPrivateMode(enabled);
  }

  static async askIsThisNormal(userId = 'default_user', { query }) {
    const state = MenopauseStateService.getState();
    const checkins = state.checkins || [];
    const myNormal = MenopauseStateService.computeMyNormal();
    const lifeMode = MenopauseStateService.getLifeMode();

    return DocsyMenopauseService.resolveIsThisNormal({
      languageCode: await resolveUserLanguage(userId),
      userQuery: query,
      checkins,
      myNormal,
      lifeMode,
    });
  }

  static async parseNaturalNote(userId = 'default_user', { noteText }) {
    return DocsyMenopauseService.parseNaturalNote({ noteText });
  }

  static getQuestions(userId = 'default_user') {
    return MenopauseStateService.getQuestions();
  }

  static addQuestion(userId = 'default_user', { text, category }) {
    return MenopauseStateService.addQuestion({ text, category });
  }

  static deleteQuestion(userId = 'default_user', questionId) {
    return MenopauseStateService.deleteQuestion(questionId);
  }

  static getTreatments(userId = 'default_user') {
    return MenopauseStateService.getTreatments();
  }

  static addTreatment(userId = 'default_user', treatmentData) {
    return MenopauseStateService.addTreatment(treatmentData);
  }

  static removeTreatment(userId = 'default_user', treatmentId) {
    return MenopauseStateService.removeTreatment(treatmentId);
  }

  static getClinicianBrief(userId = 'default_user', profile = {}) {
    const state = MenopauseStateService.getState();
    const checkins = state.checkins || [];
    const myNormal = MenopauseStateService.computeMyNormal();
    const { whatChanged, whatBeenSteady } = MenopauseStateService.computeWhatChangedAndSteady();
    const treatments = MenopauseStateService.getTreatments();
    const questions = MenopauseStateService.getQuestions();

    return DocsyMenopauseService.generateClinicianBrief({
      profile,
      checkins,
      myNormal,
      whatChanged,
      whatBeenSteady,
      treatments,
      questions,
    });
  }

  static getWhyAmISeeingThis(userId = 'default_user', moduleKey = 'today_with_docsy') {
    return MenopauseStateService.getWhyAmISeeingThis(moduleKey);
  }
}
