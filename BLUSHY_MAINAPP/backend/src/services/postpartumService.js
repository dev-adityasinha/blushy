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
  LACTATION_SAFETY_RULES,
} from './postpartumData.js';
import { todayIso } from '../utils/appCalendar.js';
import { makeUserDocStore } from '../repositories/stageStateRepository.js';
import { env } from '../utils/env.js';
import { logger } from '../utils/logger.js';

// One document per user in Mongo, replacing the process-level Maps that were
// lost on restart and never shared across instances.
const store = makeUserDocStore('postpartum_state', {
  profile: () => ({
    deliveryDate: null,
    deliveryType: 'vaginal',   // 'vaginal' | 'cesarean'
    feedingMethod: 'breastfeeding', // 'breastfeeding' | 'pumping' | 'formula' | 'combination'
    lowEnergyMode: false,
  }),
  checkins: () => [],
  babyEvents: () => [],
  supportCircle: () => [],
  appointmentNotes: () => ({ before: [], after: [] }),
});

export class PostpartumService {
  /**
   * Retrieves or initializes the user's postpartum configuration.
   */
  static async getProfile(userId) {
    const state = await store.load(userId);
    return state.profile;
  }

  /**
   * Calibrates postpartum delivery details.
   */
  static async updateCalibration(userId, { deliveryDate, deliveryType, feedingMethod, lowEnergyMode }) {
    const state = await store.load(userId);
    const profile = state.profile;
    if (deliveryDate !== undefined) profile.deliveryDate = deliveryDate;
    if (deliveryType !== undefined) profile.deliveryType = deliveryType;
    if (feedingMethod !== undefined) profile.feedingMethod = feedingMethod;
    if (lowEnergyMode !== undefined) profile.lowEnergyMode = Boolean(lowEnergyMode);
    await store.save(userId, state);
    return profile;
  }

  /**
   * Logs a daily maternal check-in.
   */
  static async recordCheckin(userId, data = {}) {
    const state = await store.load(userId);
    const list = state.checkins;
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

    await store.save(userId, state);
    return { checkin: entry, safetyStatus };
  }

  /**
   * Logs a baby event (feed, diaper, sleep, breast comfort).
   */
  static async recordBabyEvent(userId, event = {}) {
    const state = await store.load(userId);
    const list = state.babyEvents;
    const entry = {
      id: `bev_${Date.now()}`,
      type: event.type || 'feed', // 'feed' | 'diaper' | 'sleep' | 'breast_comfort'
      date: event.date || todayIso(),
      timestamp: new Date().toISOString(),
      details: event.details || {},
    };
    list.unshift(entry);
    await store.save(userId, state);
    return entry;
  }

  static async getBabyEvents(userId, date = todayIso()) {
    const state = await store.load(userId);
    return state.babyEvents.filter((e) => e.date === date);
  }

  /**
   * Generates the comprehensive Postpartum Command Center Overview.
   */
  static async getOverview(userId) {
    const state = await store.load(userId);
    const profile = state.profile;
    const timing = PostpartumStateService.calculateTiming(profile.deliveryDate);
    const checkins = state.checkins;
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

    const todayEvents = state.babyEvents.filter((e) => e.date === today);
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
  static async getTodayBrief(userId) {
    const state = await store.load(userId);
    const profile = state.profile;
    const timing = PostpartumStateService.calculateTiming(profile.deliveryDate);
    const checkins = state.checkins;
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

  /**
   * Fast synchronous rule lookup for common postpartum / nursing medications and foods.
   */
  static checkLactationRuleSafety({ query }) {
    if (!query || typeof query !== 'string') return null;
    const q = query.toLowerCase().trim();
    for (const rule of LACTATION_SAFETY_RULES) {
      if (rule.keywords.some((k) => q.includes(k))) {
        return {
          query: rule.query,
          status: rule.status,
          badge: rule.badge,
          colorHex: rule.colorHex,
          summary: rule.summary,
          reasoning: rule.reasoning,
          safeAlternative: rule.safeAlternative,
          docQuestion: rule.docQuestion,
        };
      }
    }
    return null;
  }

  /**
   * Evaluates medication, food, herb, or beverage safety while breastfeeding.
   * Leverages immediate evidence rules and falls back to Grok/OpenRouter AI with clinical accuracy.
   */
  static async checkLactationSafety({ query, daysSinceBirth = 14, feedingMethod = 'breastfeeding' }) {
    if (!query || !query.trim()) {
      return {
        query: '',
        status: 'caution',
        badge: 'Please Specify',
        colorHex: '#D97706',
        summary: 'Please enter a medication, supplement, food, or beverage to check nursing safety.',
        reasoning: 'Lactation pharmacology requires identifying the specific compound or active ingredient.',
        safeAlternative: 'Consult your IBCLC lactation consultant, OB/GYN, or pediatrician.',
        docQuestion: 'Is this safe for my baby and milk supply at our current postpartum stage?',
      };
    }

    const ruleMatch = this.checkLactationRuleSafety({ query });
    if (ruleMatch) {
      return ruleMatch;
    }

    if (env.aiChatApiKey) {
      try {
        const prompt = `You are an International Board Certified Lactation Consultant (IBCLC) and maternal-fetal pharmacologist.
A postpartum mother on Postpartum Day ${daysSinceBirth} (${feedingMethod}) asks: "Can I take, eat, or drink: ${query} while breastfeeding/nursing?"
Evaluate infant safety, transfer into breast milk (M/P ratio or relative infant dose), and effect on maternal milk supply/prolactin.
Respond strictly in valid JSON matching this schema:
{
  "query": "${query}",
  "status": "safe" | "caution" | "avoid",
  "badge": "3-5 word concise safety badge (e.g. 'Safe While Nursing', 'May Reduce Supply', 'Avoid While Nursing')",
  "colorHex": "#0D9488" (for safe) or "#D97706" (for caution) or "#DD0D22" (for avoid),
  "summary": "1-2 calm, reassuring, direct sentences",
  "reasoning": "Clear clinical reasoning on breast milk transfer, infant safety, or prolactin/milk volume impact",
  "safeAlternative": "Nursing-friendly alternative, timing advice (e.g. nurse right before), or pump advice",
  "docQuestion": "One practical question to ask her pediatrician or lactation consultant"
}`;

        const res = await fetch(env.aiChatApiUrl, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.aiChatApiKey}`,
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://blushy.app',
            'X-Title': 'Blushy Postpartum Lactation Safety',
          },
          body: JSON.stringify({
            model: env.aiChatModel || 'x-ai/grok-4.3',
            messages: [{ role: 'user', content: prompt }],
            temperature: 0.3,
            max_tokens: 400,
          }),
        });

        if (res.ok) {
          const json = await res.json();
          const content = json.choices?.[0]?.message?.content?.trim();
          if (content) {
            const clean = content.replace(/```json/gi, '').replace(/```/g, '').trim();
            const parsed = JSON.parse(clean);
            if (parsed.status && parsed.summary) {
              return {
                query,
                status: parsed.status,
                badge: parsed.badge || (parsed.status === 'safe' ? 'Safe While Nursing' : parsed.status === 'avoid' ? 'Avoid While Nursing' : 'Use Caution'),
                colorHex: parsed.colorHex || (parsed.status === 'safe' ? '#0D9488' : parsed.status === 'avoid' ? '#DD0D22' : '#D97706'),
                summary: parsed.summary,
                reasoning: parsed.reasoning || '',
                safeAlternative: parsed.safeAlternative || 'Discuss with your pediatrician or lactation consultant.',
                docQuestion: parsed.docQuestion || `Is ${query} compatible with breastfeeding for my baby?`,
              };
            }
          }
        }
      } catch (err) {
        logger.warn('AI lactation safety check fallback triggered', { message: err?.message });
      }
    }

    return {
      query,
      status: 'caution',
      badge: 'Consult Provider',
      colorHex: '#D97706',
      summary: `Limited immediate data for "${query}". Check LactMed or ask your pediatrician before taking.`,
      reasoning: 'Infant age, health, and maternal dosage determine safety for less common substances.',
      safeAlternative: 'Paracetamol or Ibuprofen are standard safe analgesics during lactation.',
      docQuestion: `Is ${query} compatible with my baby's age and health?`,
    };
  }
}

