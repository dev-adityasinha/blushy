/**
 * menopauseStateService.js
 * Longitudinal baseline engine ("My Normal"), "What Changed?" & "What's Been Steady?"
 * dual comparators, Treatment Before/After tracker, Questions Inbox, Life Mode state,
 * and dynamic Docsy Priority Engine for Menopause.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { MENOPAUSE_DOMAINS, LIFE_MODES, COMMON_TREATMENTS, POSTMENOPAUSAL_BLEEDING_ALERT } from './menopauseData.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DATA_DIR = path.resolve(__dirname, '../../data');
const STATE_FILE = path.join(DATA_DIR, 'menopause_state.json');

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

function loadPersistedState() {
  try {
    ensureDataDir();
    if (fs.existsSync(STATE_FILE)) {
      const raw = fs.readFileSync(STATE_FILE, 'utf8');
      return JSON.parse(raw);
    }
  } catch (err) {
    console.error('[MenopauseStateService] Error loading state:', err.message);
  }
  return {
    checkins: [],
    questions: [
      { id: 'q_bone_density', text: 'When should I have my first DEXA bone density scan?', category: 'Bone & Muscle', createdAt: new Date().toISOString() },
      { id: 'q_gsm_relief', text: 'Is localized low-dose vaginal estrogen safe for long-term comfort?', category: 'Intimate & Urinary', createdAt: new Date().toISOString() },
      { id: 'q_cholesterol', text: 'Should we re-check my fasting lipid panel now that my periods have ended?', category: 'Heart & Metabolic', createdAt: new Date().toISOString() },
    ],
    treatments: [
      {
        id: 't_transdermal_patch',
        name: 'Estradiol Transdermal Patch',
        category: 'Hormone Therapy (MHT)',
        dose: '50 mcg/day twice weekly',
        startDate: new Date(Date.now() - 28 * 24 * 60 * 60 * 1000).toISOString(),
        notes: 'Started for nighttime hot flashes and sleep maintenance.',
      },
      {
        id: 't_vit_d3_k2',
        name: 'Vitamin D3 (2000 IU) + K2',
        category: 'Bone & Muscle Supplement',
        dose: '1 capsule daily with morning meal',
        startDate: new Date(Date.now() - 45 * 24 * 60 * 60 * 1000).toISOString(),
        notes: 'Prescribed to support calcium bone mineralization.',
      },
    ],
    lifeMode: 'normal',
    privateMode: false,
  };
}

let memoryState = loadPersistedState();

function savePersistedState() {
  try {
    ensureDataDir();
    fs.writeFileSync(STATE_FILE, JSON.stringify(memoryState, null, 2), 'utf8');
  } catch (err) {
    console.error('[MenopauseStateService] Error saving state:', err.message);
  }
}

export class MenopauseStateService {
  static getState() {
    return memoryState;
  }

  static getLifeMode() {
    return memoryState.lifeMode || 'normal';
  }

  static setLifeMode(modeKey) {
    if (LIFE_MODES[modeKey.toUpperCase()] || modeKey === 'normal') {
      memoryState.lifeMode = modeKey.toLowerCase();
      savePersistedState();
    }
    return memoryState.lifeMode;
  }

  static getPrivateMode() {
    return !!memoryState.privateMode;
  }

  static setPrivateMode(enabled) {
    memoryState.privateMode = !!enabled;
    savePersistedState();
    return memoryState.privateMode;
  }

  /**
   * Records a daily checkin.
   * Supports "nothing much today" and "not_sure" without forced fields.
   */
  static recordCheckin({
    bodyFeeling = 'comfortable', // 'comfortable', 'tense', 'fatigued', 'not_sure'
    sleepQuality = 'restful',    // 'restful', 'interrupted_waking', 'night_sweats', 'insomnia', 'not_sure'
    energyLevel = 'steady',      // 'steady', 'fluctuating', 'exhausted', 'not_sure'
    moodState = 'calm',          // 'calm', 'low', 'anxious', 'foggy', 'not_sure'
    hotFlashes = 'none',         // 'none', 'mild_daytime', 'night_flushes', 'frequent', 'not_sure'
    jointDiscomfort = 'none',    // 'none', 'morning_stiffness', 'aching', 'not_sure'
    vaginalComfort = 'normal',   // 'normal', 'dryness', 'discomfort', 'not_sure'
    bleedingLogged = false,      // true if any spotting or bleeding was noted
    isNothingMuchToday = false,
    userNotes = '',
    loggedAt = new Date().toISOString(),
  }) {
    const checkin = {
      id: `chk_${Date.now()}`,
      bodyFeeling,
      sleepQuality,
      energyLevel,
      moodState,
      hotFlashes,
      jointDiscomfort,
      vaginalComfort,
      bleedingLogged: !!bleedingLogged,
      isNothingMuchToday: !!isNothingMuchToday,
      userNotes,
      loggedAt,
    };

    memoryState.checkins.unshift(checkin);
    // Keep last 180 checkins
    if (memoryState.checkins.length > 180) {
      memoryState.checkins = memoryState.checkins.slice(0, 180);
    }
    savePersistedState();
    return checkin;
  }

  /**
   * Questions Inbox Operations
   */
  static getQuestions() {
    return memoryState.questions || [];
  }

  static addQuestion({ text, category = 'General Menopause' }) {
    if (!text || !text.trim()) return null;
    const q = {
      id: `q_${Date.now()}`,
      text: text.trim(),
      category: category || 'General Menopause',
      createdAt: new Date().toISOString(),
    };
    memoryState.questions.unshift(q);
    savePersistedState();
    return q;
  }

  static deleteQuestion(questionId) {
    memoryState.questions = memoryState.questions.filter((q) => q.id !== questionId);
    savePersistedState();
    return true;
  }

  /**
   * Treatment Tracking Operations
   */
  static getTreatments() {
    return memoryState.treatments || [];
  }

  static addTreatment({ name, category, dose = '', startDate = new Date().toISOString(), notes = '' }) {
    if (!name || !name.trim()) return null;
    const t = {
      id: `t_${Date.now()}`,
      name: name.trim(),
      category: category || 'General Support',
      dose: dose || '',
      startDate,
      notes,
    };
    memoryState.treatments.push(t);
    savePersistedState();
    return t;
  }

  static removeTreatment(treatmentId) {
    memoryState.treatments = memoryState.treatments.filter((t) => t.id !== treatmentId);
    savePersistedState();
    return true;
  }

  /**
   * Computes "My Normal" - an individualized baseline.
   * Never shows 0-100 fake scores; describes what is usual for her.
   */
  static computeMyNormal() {
    const checkins = memoryState.checkins;
    const count = checkins.length;

    if (count < 3) {
      return {
        status: 'Building your baseline',
        description: 'Blushy is learning your body’s unique daily rhythms. Check in for a few days to see what is normal for you.',
        confidence: 'Initial Calibration',
        markers: [
          { domain: 'Sleep', baseline: 'Establishing baseline', status: `${count}/7 days logged` },
          { domain: 'Hot Flashes', baseline: 'Establishing baseline', status: 'Listening' },
          { domain: 'Energy', baseline: 'Establishing baseline', status: 'Listening' },
          { domain: 'Intimate Comfort', baseline: 'Establishing baseline', status: 'Listening' },
          { domain: 'Joints & Movement', baseline: 'Establishing baseline', status: 'Listening' },
        ],
      };
    }

    // Tally recent observations
    let restfulSleepCount = 0;
    let hotFlashCount = 0;
    let steadyEnergyCount = 0;
    let comfortableIntimateCount = 0;
    let quietJointsCount = 0;

    for (const c of checkins) {
      if (c.sleepQuality === 'restful') restfulSleepCount++;
      if (c.hotFlashes !== 'none' && c.hotFlashes !== 'not_sure') hotFlashCount++;
      if (c.energyLevel === 'steady') steadyEnergyCount++;
      if (c.vaginalComfort === 'normal') comfortableIntimateCount++;
      if (c.jointDiscomfort === 'none') quietJointsCount++;
    }

    const sleepPct = Math.round((restfulSleepCount / count) * 100);
    const flashFreq = (hotFlashCount / count).toFixed(1);

    return {
      status: 'Your personalized baseline',
      description: 'Based on your real logged days. These patterns reflect your unique body rather than population averages.',
      confidence: count >= 14 ? 'High Confidence' : 'Moderate Confidence',
      markers: [
        {
          domain: 'Sleep',
          baseline: sleepPct >= 70 ? 'Usually 6–8h restful' : 'Light with intermittent waking',
          status: `${sleepPct}% restful nights`,
        },
        {
          domain: 'Hot Flashes',
          baseline: hotFlashCount === 0 ? 'Rare or absent' : `Averages ~${flashFreq} per day`,
          status: `${hotFlashCount} logged over ${count}d`,
        },
        {
          domain: 'Energy',
          baseline: steadyEnergyCount >= count * 0.6 ? 'Usually steady & functional' : 'Variable afternoon dips',
          status: 'Pattern identified',
        },
        {
          domain: 'Intimate Comfort',
          baseline: comfortableIntimateCount >= count * 0.8 ? 'Usually comfortable' : 'Occasional dryness noted',
          status: 'Monitored gently',
        },
        {
          domain: 'Joints & Movement',
          baseline: quietJointsCount >= count * 0.7 ? 'Comfortable morning movement' : 'Intermittent morning stiffness',
          status: 'Monitored gently',
        },
      ],
    };
  }

  /**
   * Computes "What Changed?" and "What Has Been Steady?".
   * Balances change detection with steady reinforcement for low-cortisol tracking.
   */
  static computeWhatChangedAndSteady() {
    const checkins = memoryState.checkins;
    if (checkins.length < 3) {
      return {
        whatChanged: [
          {
            id: 'c_welcome',
            title: 'Welcome to your new chapter',
            detail: 'You have begun recording your days. As you log, Blushy compares this week to your normal baseline.',
            timeframe: 'Getting Started',
            icon: 'waving_hand_rounded',
            colorHex: '0xFF0D9488',
          },
        ],
        whatBeenSteady: [
          {
            id: 's_fresh',
            title: 'A clean slate for your health',
            detail: 'Your health story is building. Blushy watches for what remains steady just as much as what shifts.',
            timeframe: 'Baseline',
            icon: 'check_circle_outline_rounded',
            colorHex: '0xFF2563EB',
          },
        ],
      };
    }

    const recent7 = checkins.slice(0, Math.min(7, checkins.length));
    const previous = checkins.slice(7);

    const whatChanged = [];
    const whatBeenSteady = [];

    // Check night waking shift
    const recentWaking = recent7.filter((c) => c.sleepQuality === 'interrupted_waking' || c.sleepQuality === 'night_sweats').length;
    if (recentWaking >= 3) {
      whatChanged.push({
        id: 'c_sleep_waking',
        title: 'More frequent night waking this week',
        detail: `You reported interrupted sleep ${recentWaking} nights over the last 7 days, higher than your earlier baseline.`,
        timeframe: 'Past 7 Days',
        icon: 'nightlight_round',
        colorHex: '0xFF7209B7',
      });
    } else {
      whatBeenSteady.push({
        id: 's_sleep_steady',
        title: 'Sleep rhythm has remained steady',
        detail: 'Your sleep duration and night comfort have stayed consistent throughout the recent week.',
        timeframe: 'Past 7 Days',
        icon: 'bedtime_rounded',
        colorHex: '0xFF0D9488',
      });
    }

    // Check hot flash shift
    const recentFlashes = recent7.filter((c) => c.hotFlashes === 'night_flushes' || c.hotFlashes === 'frequent').length;
    if (recentFlashes >= 3) {
      whatChanged.push({
        id: 'c_flashes_up',
        title: 'Noticeable uptick in temperature flushes',
        detail: 'Flushes were reported on multiple days this week. Evening room cooling and hydration may provide immediate comfort.',
        timeframe: 'Past 7 Days',
        icon: 'thermostat_rounded',
        colorHex: '0xFFFF4A00',
      });
    } else {
      whatBeenSteady.push({
        id: 's_flashes_calm',
        title: 'Temperature balance has been calm',
        detail: 'No disruptive hot flashes or night sweats were reported over recent check-ins.',
        timeframe: 'Past 7 Days',
        icon: 'ac_unit_rounded',
        colorHex: '0xFF2563EB',
      });
    }

    // Check joint discomfort
    const recentJoints = recent7.filter((c) => c.jointDiscomfort === 'morning_stiffness' || c.jointDiscomfort === 'aching').length;
    if (recentJoints >= 3) {
      whatChanged.push({
        id: 'c_joints_stiff',
        title: 'Morning joint stiffness reported 3+ times',
        detail: 'Gentle morning mobility and adequate hydration often ease early stiffness.',
        timeframe: 'Past 7 Days',
        icon: 'accessibility_new_rounded',
        colorHex: '0xFFD97706',
      });
    } else {
      whatBeenSteady.push({
        id: 's_joints_quiet',
        title: 'Joint and body comfort has been steady',
        detail: 'You have moved comfortably through your daily routines with no stiffness logged.',
        timeframe: 'Past 7 Days',
        icon: 'directions_walk_rounded',
        colorHex: '0xFF0D9488',
      });
    }

    // Fallback if nothing changed
    if (whatChanged.length === 0) {
      whatChanged.push({
        id: 'c_equipoise',
        title: 'No significant shifts detected',
        detail: 'Your logged markers are tracking closely with your established normal baseline.',
        timeframe: 'Past 7 Days',
        icon: 'balance_rounded',
        colorHex: '0xFF0D9488',
      });
    }

    return { whatChanged, whatBeenSteady };
  }

  /**
   * "Before / During / After Treatment" Response Tracker.
   * Compares logged markers before start date vs after start date.
   * Uses responsible language: "Symptoms changed after starting" (NEVER "caused by").
   */
  static computeTreatmentResponse() {
    const treatments = memoryState.treatments;
    const checkins = memoryState.checkins;

    return treatments.map((treatment) => {
      const startTime = new Date(treatment.startDate).getTime();
      const beforeLogs = checkins.filter((c) => new Date(c.loggedAt).getTime() < startTime);
      const afterLogs = checkins.filter((c) => new Date(c.loggedAt).getTime() >= startTime);

      const beforeFlashes = beforeLogs.filter((c) => c.hotFlashes !== 'none').length;
      const afterFlashes = afterLogs.filter((c) => c.hotFlashes !== 'none').length;

      const beforeDisruptedSleep = beforeLogs.filter((c) => c.sleepQuality !== 'restful').length;
      const afterDisruptedSleep = afterLogs.filter((c) => c.sleepQuality !== 'restful').length;

      return {
        treatmentId: treatment.id,
        name: treatment.name,
        category: treatment.category,
        dose: treatment.dose,
        startDate: treatment.startDate,
        daysActive: Math.max(1, Math.round((Date.now() - startTime) / (24 * 60 * 60 * 1000))),
        beforeSummary: {
          periodTracked: `${beforeLogs.length} days before`,
          flashesReported: beforeFlashes,
          sleepDisruptions: beforeDisruptedSleep,
        },
        afterSummary: {
          periodTracked: `${afterLogs.length} days since starting`,
          flashesReported: afterFlashes,
          sleepDisruptions: afterDisruptedSleep,
        },
        attributionNote: 'These patterns changed after starting this treatment. Blushy observes longitudinal correlations; discuss individual response with your clinician.',
      };
    });
  }

  /**
   * Priority Engine: Dynamically determines the homepage module sequence.
   * Adapts based on safety red flags, life mode, recent sleep, and doctor questions.
   */
  static determineSectionOrder() {
    const checkins = memoryState.checkins;
    const latest = checkins[0] || {};
    const lifeMode = memoryState.lifeMode || 'normal';
    const questions = memoryState.questions || [];

    // Check for urgent safety alert: Postmenopausal Bleeding
    const hasBleedingLogged = checkins.some((c) => c.bleedingLogged === true);
    if (hasBleedingLogged) {
      return [
        'safety_alert_bleeding',
        'editorial_greeting',
        'today_with_docsy',
        'prepare_for_care',
        'my_questions',
        'how_am_i_today',
        'what_changed',
        'my_normal',
        'my_health_domains',
        'my_treatment',
        'my_health_story',
        'teach_me_30s',
      ];
    }

    // If Life Mode is Exhausted or Overwhelmed -> "Do Nothing" and Steady come early
    if (lifeMode === 'exhausted' || lifeMode === 'overwhelmed') {
      return [
        'editorial_greeting',
        'today_with_docsy', // containing "Do Nothing" recommendation
        'what_do_i_need_actions',
        'what_been_steady',
        'how_am_i_today',
        'my_normal',
        'my_health_domains',
        'my_treatment',
        'my_questions',
        'prepare_for_care',
        'my_health_story',
        'teach_me_30s',
      ];
    }

    // If severe sleep disruption
    if (latest.sleepQuality === 'night_sweats' || latest.sleepQuality === 'insomnia' || lifeMode === 'bad_sleep_week') {
      return [
        'editorial_greeting',
        'today_with_docsy',
        'what_changed',
        'what_do_i_need_actions',
        'how_am_i_today',
        'what_been_steady',
        'my_health_domains',
        'my_normal',
        'my_treatment',
        'my_questions',
        'prepare_for_care',
        'my_health_story',
        'teach_me_30s',
      ];
    }

    // If user has many questions saved (e.g. preparing for care)
    if (questions.length >= 4) {
      return [
        'editorial_greeting',
        'today_with_docsy',
        'how_am_i_today',
        'my_questions',
        'prepare_for_care',
        'what_changed',
        'what_been_steady',
        'what_do_i_need_actions',
        'my_health_domains',
        'my_normal',
        'my_treatment',
        'my_health_story',
        'teach_me_30s',
      ];
    }

    // Default canonical sequence
    return [
      'editorial_greeting',
      'today_with_docsy',
      'how_am_i_today',
      'what_changed',
      'what_been_steady',
      'what_do_i_need_actions',
      'my_health_domains',
      'my_normal',
      'my_treatment',
      'my_questions',
      'prepare_for_care',
      'my_health_story',
      'teach_me_30s',
    ];
  }

  /**
   * "Why Am I Seeing This?" global explanation builder for any module.
   */
  static getWhyAmISeeingThis(moduleKey) {
    const checkins = memoryState.checkins;
    const latest = checkins[0] || {};
    const lifeMode = memoryState.lifeMode || 'normal';

    switch (moduleKey) {
      case 'today_with_docsy':
        return {
          youLogged: latest.sleepQuality ? `Sleep logged as '${latest.sleepQuality}' and mood as '${latest.moodState}'` : 'Recent check-ins reflecting everyday postmenopause rhythm.',
          wereNoticing: `Active life mode is currently '${LIFE_MODES[lifeMode.toUpperCase()]?.label || lifeMode}'.`,
          whyItMayMatter: 'Menopause is a non-linear chapter where everyday context (rest, workload, temperature) interacts directly with symptoms.',
          whatBlushyDoesntKnow: 'Blushy does not ingest hormonal lab assays and cannot predict sudden vasomotor spikes.',
          whatYouCanDo: 'Check in with what you notice today, talk to Docsy, or save a question for your next doctor visit.',
        };
      case 'what_changed':
        return {
          youLogged: `${checkins.length} daily logs recorded in your personal history.`,
          wereNoticing: 'Longitudinal comparison between your past 7 days and earlier baseline check-ins.',
          whyItMayMatter: 'Isolating recent shifts from your personal normal helps you discuss meaningful trends with your doctor.',
          whatBlushyDoesntKnow: 'Whether recent shifts are caused by lifestyle changes, natural fluctuations, or medical factors.',
          whatYouCanDo: 'Review the highlighted shifts. If a change persists, save a question to your Questions Inbox.',
        };
      case 'my_treatment':
        return {
          youLogged: `${memoryState.treatments.length} active treatments or supplements recorded.`,
          wereNoticing: 'Symptoms logged before your treatment start date compared with logs recorded afterward.',
          whyItMayMatter: 'Tracking your before-and-after response helps you evaluate treatment comfort objectively with your physician.',
          whatBlushyDoesntKnow: 'Blushy cannot determine clinical causality or recommend prescription dosage changes.',
          whatYouCanDo: 'Share your Before/After treatment summary with your prescribing doctor at your next appointment.',
        };
      default:
        return {
          youLogged: 'Recent entries in your Menopause health log.',
          wereNoticing: 'Patterns tailored to your current stage and preferences.',
          whyItMayMatter: 'Empowering you with evidence-based insights to protect bone, heart, and intimate health.',
          whatBlushyDoesntKnow: 'Individual medical diagnoses without clinical consultation.',
          whatYouCanDo: 'Explore the details or ask Docsy for clarification.',
        };
    }
  }
}
