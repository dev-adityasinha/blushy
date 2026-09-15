/**
 * postpartumService.js
 * Comprehensive data, storage, and orchestration service for Postpartum.
 */

import { PostpartumStateService } from './postpartumStateService.js';
import { PostpartumSafetyService } from './postpartumSafetyService.js';
import { DocsyPostpartumService } from './docsyPostpartumService.js';
import { resolveUserLanguage } from '../utils/language.js';
import {
  POSTPARTUM_PHASES,
  LOCHIA_STAGES,
  CAN_I_DO_THIS_YET,
  CONTEXTUAL_READS,
  RECOVERY_MILESTONES,
} from './postpartumData.js';
import { todayIso } from '../utils/appCalendar.js';

// In-memory data store with disk persistence support
const store = {
  profiles: new Map(), // userId -> { deliveryDate, deliveryType, feedingMethod, lowEnergyMode }
  checkins: new Map(), // userId -> [checkins...]
  babyEvents: new Map(), // userId -> [events...]
  supportCircle: new Map(), // userId -> [contacts...]
  appointmentNotes: new Map(), // userId -> { before: [], after: [] }
};

export class PostpartumService {
  /**
   * Retrieves or initializes the user's postpartum configuration.
   */
  static getProfile(userId = 'default_user') {
    if (!store.profiles.has(userId)) {
      store.profiles.set(userId, {
        deliveryDate: null,
        deliveryType: 'vaginal', // 'vaginal' | 'cesarean'
        feedingMethod: 'breastfeeding', // 'breastfeeding' | 'pumping' | 'formula' | 'combination'
        lowEnergyMode: false,
      });
    }
    return store.profiles.get(userId);
  }

  /**
   * Calibrates postpartum delivery details.
   */
  static updateCalibration(userId = 'default_user', { deliveryDate, deliveryType, feedingMethod, lowEnergyMode }) {
    const profile = this.getProfile(userId);
    if (deliveryDate !== undefined) profile.deliveryDate = deliveryDate;
    if (deliveryType !== undefined) profile.deliveryType = deliveryType;
    if (feedingMethod !== undefined) profile.feedingMethod = feedingMethod;
    if (lowEnergyMode !== undefined) profile.lowEnergyMode = Boolean(lowEnergyMode);
    store.profiles.set(userId, profile);
    return profile;
  }

  /**
   * Logs a daily maternal check-in.
   */
  static recordCheckin(userId = 'default_user', data = {}) {
    if (!store.checkins.has(userId)) {
      store.checkins.set(userId, []);
    }
    const list = store.checkins.get(userId);
    const date = data.date || todayIso();

    // Check for safety signals
    const safetyStatus = PostpartumSafetyService.evaluateSafety({
      bleedingLevel: data.bleedingLevel,
      clotSize: data.clotSize,
      padSaturationHours: data.padSaturationHours,
      hasSevereHeadache: data.hasSevereHeadache,
      hasVisualChanges: data.hasVisualChanges,
      feverTempF: data.feverTempF,
      incisionCondition: data.incisionCondition,
      calfPainUnilateral: data.calfPainUnilateral,
      chestPainOrShortBreath: data.chestPainOrShortBreath,
      mood: data.mood,
      harmThoughts: data.harmThoughts,
      epdsScore: data.epdsScore,
    });

    const entry = {
      id: `chk_${Date.now()}`,
      date,
      physicalComfort: data.physicalComfort || 'okay',
      mood: data.mood || 'okay',
      energy: data.energy || 'normal',
      needRightNow: data.needRightNow || 'rest',
      todayFeels: data.todayFeels || 'easy',
      painScore: Number(data.painScore) || 2,
      bleedingLevel: data.bleedingLevel || 'moderate',
      sleepHours: Number(data.sleepHours) || 5,
      waterGlasses: Number(data.waterGlasses) || 4,
      notes: data.notes || '',
      safetyStatus,
      createdAt: new Date().toISOString(),
    };

    const existingIndex = list.findIndex((c) => c.date === date);
    if (existingIndex >= 0) {
      list[existingIndex] = entry;
    } else {
      list.unshift(entry);
    }

    return { checkin: entry, safetyStatus };
  }

  /**
   * Logs a baby event (feed, diaper, sleep, breast comfort).
   */
  static recordBabyEvent(userId = 'default_user', event = {}) {
    if (!store.babyEvents.has(userId)) {
      store.babyEvents.set(userId, []);
    }
    const list = store.babyEvents.get(userId);
    const entry = {
      id: `bev_${Date.now()}`,
      type: event.type || 'feed', // 'feed' | 'diaper' | 'sleep' | 'breast_comfort'
      date: event.date || todayIso(),
      timestamp: new Date().toISOString(),
      details: event.details || {},
    };
    list.unshift(entry);
    return entry;
  }

  static getBabyEvents(userId = 'default_user', date = todayIso()) {
    const list = store.babyEvents.get(userId) || [];
    return list.filter((e) => e.date === date);
  }

  /**
   * Generates the comprehensive Postpartum Command Center Overview.
   */
  static getOverview(userId = 'default_user') {
    const profile = this.getProfile(userId);
    const timing = PostpartumStateService.calculateTiming(profile.deliveryDate);
    const checkins = store.checkins.get(userId) || [];
    const today = todayIso();
    const todayCheckin = checkins.find((c) => c.date === today) || null;
    const yesterdayCheckin = checkins.find((c) => c.date !== today) || null;

    const baselineMaturity = PostpartumStateService.computeBaselineMaturity(checkins);
    const priorities = PostpartumStateService.determinePriorities({
      timing,
      todayCheckin,
      yesterdayCheckin,
      recentCheckins: checkins,
    });

    const deltas = PostpartumStateService.evaluateDeltas({
      todayCheckin,
      yesterdayCheckin,
      recentCheckins: checkins,
    });

    const todayEvents = this.getBabyEvents(userId, today);
    const safetyStatus = todayCheckin?.safetyStatus || { severity: 'low', shouldInterrupt: false, flags: [] };

    return {
      profile,
      timing,
      baselineMaturity,
      priorities,
      deltas,
      todayCheckin,
      recentCheckins: checkins.slice(0, 7),
      todayBabyEvents: todayEvents,
      safetyStatus,
      lochiaStages: LOCHIA_STAGES,
      canIDoThisYet: CAN_I_DO_THIS_YET,
      contextualReads: CONTEXTUAL_READS,
      milestones: RECOVERY_MILESTONES,
      isLowEnergyMode: profile.lowEnergyMode,
    };
  }

  /**
   * Generates the dynamic Today with Docsy briefing.
   */
  static async getTodayBrief(userId = 'default_user') {
    const profile = this.getProfile(userId);
    const timing = PostpartumStateService.calculateTiming(profile.deliveryDate);
    const checkins = store.checkins.get(userId) || [];
    const today = todayIso();
    const todayCheckin = checkins.find((c) => c.date === today) || null;
    const yesterdayCheckin = checkins.find((c) => c.date !== today) || null;
    const priorities = PostpartumStateService.determinePriorities({
      timing,
      todayCheckin,
      yesterdayCheckin,
      recentCheckins: checkins,
    });
    const safetyStatus = todayCheckin?.safetyStatus || { severity: 'low', shouldInterrupt: false, flags: [] };

    return await DocsyPostpartumService.generateDailyBrief({
      languageCode: await resolveUserLanguage(userId),
      timing,
      todayCheckin,
      yesterdayCheckin,
      priorities,
      safetyStatus,
    });
  }

  /**
   * Generates a shareable "I Need Help" SOS message.
   */
  static generateHelpMessage({ needs = [], recipientName = 'Someone' }) {
    const needLabels = {
      food: 'bring me a warm, nourishing meal or snack',
      baby_care: 'hold or watch the baby for a couple of hours so I can rest',
      housework: 'help fold laundry or tidy up the kitchen',
      ride: 'give me a ride to an appointment',
      appointment: 'come with me to my doctor / pediatrician appointment',
      company: 'just come sit with me for a little while',
      chat: 'hop on a quick phone call to talk',
    };

    const selectedDescriptions = needs
      .map((n) => needLabels[n])
      .filter(Boolean);

    let itemsText = 'some support today';
    if (selectedDescriptions.length === 1) {
      itemsText = selectedDescriptions[0];
    } else if (selectedDescriptions.length > 1) {
      itemsText = `${selectedDescriptions.slice(0, -1).join(', ')} and ${selectedDescriptions.slice(-1)}`;
    }

    const message = `Hi ${recipientName}, I've had a really challenging stretch with recovery and could really use a hand today. If you're free, could you help me ${itemsText}? No pressure at all, but it would mean the world to me. ❤️`;

    return {
      message,
      selectedNeeds: needs,
      timestamp: new Date().toISOString(),
    };
  }
}
