import { db } from '../utils/db.js';
import { getGestationalDataForWeek } from './pregnancyData.js';
import { todayIso } from '../utils/appCalendar.js';

// In-memory fallback cache for preview/offline environments
const memoryStore = {
  checkins: new Map(),
  memories: new Map(),
  questions: new Map(),
};

export class PregnancyService {
  calculateGestationalAge(dueDateInput) {
    let dueDate;
    const isConfigured = Boolean(dueDateInput && !Number.isNaN(new Date(dueDateInput).getTime()));
    if (isConfigured) {
      dueDate = new Date(dueDateInput);
    }

    if (!isConfigured) {
      return {
        isDueDateConfigured: false,
        dueDate: null,
        week: null,
        day: null,
        trimester: null,
        trimesterLabel: 'Not Set',
        daysRemaining: null,
        progressPercent: 0,
      };
    }

    const now = new Date();
    const msPerDay = 24 * 60 * 60 * 1000;
    const daysToGo = Math.round((dueDate.getTime() - now.getTime()) / msPerDay);
    
    // Gestation is 280 days total
    const daysElapsed = Math.max(1, Math.min(294, 280 - daysToGo));
    const week = Math.max(1, Math.min(42, Math.floor(daysElapsed / 7)));
    const day = Math.max(0, Math.min(6, daysElapsed % 7));
    const trimester = week <= 12 ? 1 : (week <= 27 ? 2 : 3);

    return {
      isDueDateConfigured: true,
      dueDate: dueDate.toISOString().slice(0, 10),
      week,
      day,
      trimester,
      trimesterLabel: trimester === 1 ? 'First Trimester' : (trimester === 2 ? 'Second Trimester' : 'Third Trimester'),
      daysRemaining: Math.max(0, daysToGo),
      progressPercent: Math.min(100, Math.round((daysElapsed / 280) * 100)),
    };
  }

  async getOverview({ dueDate: dueDateInput, userId }) {
    const age = this.calculateGestationalAge(dueDateInput);
    if (!age.isDueDateConfigured) {
      return {
        ...age,
        weeklyData: {
          babySizeName: '',
          babySizeEmoji: '🌱',
          babyLengthCm: 0,
          babyWeightG: 0,
          babyHighlights: [],
          maternalBodyHighlights: [],
          oneThingToKnow: 'Knowing your estimated due date helps Blushy tailor every milestone, symptom check, and appointment cue.',
          oneThingToDo: 'Set your estimated due date to calibrate your personal pregnancy timeline.',
          suggestedPrompts: [
            'How is an estimated due date calculated?',
            'What should I do in early pregnancy?',
            'What prenatal vitamins are best?',
          ],
        },
      };
    }
    const weeklyData = getGestationalDataForWeek(age.week);

    return {
      ...age,
      weeklyData,
    };
  }

  async getTodayBrief({ dueDate: dueDateInput, userId, activeMode = null }) {
    const age = this.calculateGestationalAge(dueDateInput);
    const weeklyData = getGestationalDataForWeek(age.isDueDateConfigured ? age.week : 1);

    // Mode-specific adjustment
    let modeAdvice = "Tap any mood or reality above to tailor Docsy's recommendations for your day.";
    if (activeMode === 'default') {
      modeAdvice = "Take things at an unhurried, comfortable pace today.";
    } else if (activeMode === 'nausea') {
      modeAdvice = "Focus on small, frequent sips of cool water and bland snacks. Be extra gentle with yourself today.";
    } else if (activeMode === 'sleep') {
      modeAdvice = "Rest your eyes whenever you can; prioritize horizontal rest and an early wind-down tonight.";
    } else if (activeMode === 'back_pain') {
      modeAdvice = "Avoid standing in one spot for long. Place a pillow behind your lower back and take warm rest breaks.";
    } else if (activeMode === 'travel') {
      modeAdvice = "Wear compression socks, stay hydrated, and take 5-minute walking breaks every 90 minutes.";
    } else if (activeMode === 'anxious') {
      modeAdvice = "Your feelings are valid. Take three slow belly breaths; Docsy is right here with you.";
    }

    const brief = {
      greeting: "Good morning ❤️",
      isDueDateConfigured: age.isDueDateConfigured,
      gestationalDisplay: age.isDueDateConfigured ? `${age.week} weeks + ${age.day} days` : 'Due date not set',
      trimesterLabel: age.isDueDateConfigured ? age.trimesterLabel : 'Getting Started',
      yourBody: age.isDueDateConfigured
        ? (weeklyData.maternalBodyHighlights[0] || "Your body is adjusting gracefully to baby's developmental pace.")
        : "Set your due date to see what changes are happening in your body this week.",
      yourBaby: age.isDueDateConfigured
        ? (weeklyData.babyHighlights[0] || "Baby's sensory and organ systems are making steady daily progress.")
        : "Set your due date to follow baby's size, milestones, and weekly growth.",
      yourCare: age.isDueDateConfigured
        ? (age.week < 12 
          ? "First trimester baseline intake • Review prenatal vitamins with folic acid."
          : (age.week < 24 
            ? "Second trimester scan window • Anatomy scan scheduling."
            : "Third trimester monitoring • Stay mindful of baby's daily movement rhythms."))
        : "Initial prenatal intake • Set your estimated due date.",
      oneThingToKnow: weeklyData.oneThingToKnow,
      oneThingToDo: weeklyData.oneThingToDo,
      activeMode,
      modeAdvice,
      suggestedPrompts: weeklyData.suggestedPrompts,
    };

    return brief;
  }

  async recordCheckIn({ userId = 'preview_user', checkin }) {
    const entryDate = checkin.date || todayIso();
    const cleanUserId = String(userId).replace('user:', '');

    const record = {
      userId: cleanUserId,
      entryDate,
      nausea: checkin.nausea ?? 2, // 1 (none) to 4 (strong)
      energy: checkin.energy ?? 3, // 1 (exhausted) to 4 (high)
      sleep: checkin.sleep ?? 3, // 1 (poor) to 4 (deep)
      mood: checkin.mood ?? 3, // 1 (overwhelmed) to 4 (calm/excited)
      comfort: checkin.comfort ?? 3, // 1 (severe pain) to 4 (comfortable)
      mode: checkin.mode || 'default',
      waterGlasses: checkin.waterGlasses ?? 6,
      notes: checkin.notes || '',
      updatedAt: new Date().toISOString(),
    };

    // Save to DB if available
    try {
      if (db) {
        await db.collection('pregnancy_checkins').updateOne(
          { user_id: cleanUserId, entry_date: entryDate },
          { $set: { ...record, user_id: cleanUserId, entry_date: entryDate } },
          { upsert: true }
        );
      }
    } catch {
      // Fallback in-memory
    }

    // Save to memoryStore
    if (!memoryStore.checkins.has(cleanUserId)) {
      memoryStore.checkins.set(cleanUserId, new Map());
    }
    memoryStore.checkins.get(cleanUserId).set(entryDate, record);

    return { success: true, record };
  }

  async getBaselineAndDeltas({ userId = 'preview_user' }) {
    const cleanUserId = String(userId).replace('user:', '');
    let records = [];

    try {
      if (db) {
        records = await db.collection('pregnancy_checkins')
          .find({ user_id: cleanUserId })
          .sort({ entry_date: -1 })
          .limit(7)
          .toArray();
      }
    } catch {
      // Fallback
    }

    if (records.length === 0 && memoryStore.checkins.has(cleanUserId)) {
      records = Array.from(memoryStore.checkins.get(cleanUserId).values())
        .sort((a, b) => b.entryDate.localeCompare(a.entryDate));
    }

    // First-Time User Optimization:
    // If fewer than 2 logs, provide an honest, calibrated first-time baseline without fake clinical claims
    if (records.length < 2) {
      return {
        isFirstTimeUser: true,
        daysTracked: records.length,
        headline: "Establishing Your Personal Baseline",
        subtext: "Blushy learns what is normal for YOUR body over your first 3 to 5 daily check-ins.",
        baseline: {
          energy: 3,
          sleep: 3,
          nausea: 2,
          mood: 3,
          comfort: 3,
        },
        deltas: [
          { key: 'energy', label: 'Energy', status: 'Calibrating', direction: 'stable', detail: 'Log today to start baseline' },
          { key: 'sleep', label: 'Sleep', status: 'Calibrating', direction: 'stable', detail: 'Tracking nighttime rest' },
          { key: 'nausea', label: 'Nausea', status: 'Calibrating', direction: 'stable', detail: 'Monitoring digestive rhythm' },
          { key: 'mood', label: 'Mood', status: 'Calibrating', direction: 'stable', detail: 'Emotional wellbeing anchor' },
        ],
        trendSynthesis: "Checking in once a day helps Docsy detect subtle shifts in your rest, comfort, and vitality.",
      };
    }

    // Returning user: calculate actual baseline averages
    const sum = records.reduce((acc, r) => ({
      energy: acc.energy + (r.energy || 3),
      sleep: acc.sleep + (r.sleep || 3),
      nausea: acc.nausea + (r.nausea || 2),
      mood: acc.mood + (r.mood || 3),
      comfort: acc.comfort + (r.comfort || 3),
    }), { energy: 0, sleep: 0, nausea: 0, mood: 0, comfort: 0 });

    const count = records.length;
    const baseline = {
      energy: Math.round((sum.energy / count) * 10) / 10,
      sleep: Math.round((sum.sleep / count) * 10) / 10,
      nausea: Math.round((sum.nausea / count) * 10) / 10,
      mood: Math.round((sum.mood / count) * 10) / 10,
      comfort: Math.round((sum.comfort / count) * 10) / 10,
    };

    const todayLog = records[0];
    const yesterdayLog = records[1];

    function getDelta(todayVal, yesterdayVal, label, higherIsGood = true) {
      const diff = (todayVal || 3) - (yesterdayVal || 3);
      if (diff > 0) {
        return {
          key: label.toLowerCase(),
          label,
          direction: 'higher',
          indicator: '↑ higher',
          isBeneficial: higherIsGood,
          detail: `${label} increased compared to yesterday`,
        };
      } else if (diff < 0) {
        return {
          key: label.toLowerCase(),
          label,
          direction: 'lower',
          indicator: '↓ lower',
          isBeneficial: !higherIsGood,
          detail: `${label} decreased compared to yesterday`,
        };
      }
      return {
        key: label.toLowerCase(),
        label,
        direction: 'stable',
        indicator: '→ stable',
        isBeneficial: true,
        detail: `${label} is steady with your recent baseline`,
      };
    }

    const deltas = [
      getDelta(todayLog.sleep, yesterdayLog.sleep, 'Sleep', true),
      getDelta(todayLog.energy, yesterdayLog.energy, 'Energy', true),
      getDelta(todayLog.nausea, yesterdayLog.nausea, 'Nausea', false),
      getDelta(todayLog.mood, yesterdayLog.mood, 'Mood', true),
    ];

    // Multi-day trend detection
    let trendSynthesis = "Your metrics are tracking close to your recent baseline pattern.";
    if (records.length >= 3) {
      const nauseaElevated = records.slice(0, 3).every((r) => (r.nausea || 0) >= 3);
      const sleepDisrupted = records.slice(0, 3).every((r) => (r.sleep || 0) <= 2);

      if (nauseaElevated) {
        trendSynthesis = "Docsy noticed your nausea has been elevated for three consecutive days. Consider smaller, bland protein-rich snacks before bed and upon waking.";
      } else if (sleepDisrupted) {
        trendSynthesis = "Docsy noticed your sleep quality has dipped over recent nights. A supportive pregnancy pillow or a warm bath before bed may ease hip and back tension.";
      }
    }

    return {
      isFirstTimeUser: false,
      daysTracked: records.length,
      headline: "My Normal & What Changed",
      subtext: "Personalized baseline calculated from your recent daily check-ins.",
      baseline,
      deltas,
      trendSynthesis,
    };
  }

  classifySymptomIsThisNormal({ query = '', week = 20 }) {
    const q = query.trim().toLowerCase();

    // 1. URGENT Emergency Symptoms
    if (/bleeding|hemorrhage|clot|spotting heavy/i.test(q)) {
      return {
        category: 'urgent',
        badgeLabel: 'Urgent Evaluation Needed',
        colorHex: '#DD0D22',
        summary: 'Significant or bright red vaginal bleeding requires prompt medical assessment.',
        reasoning: 'Bleeding can indicate cervical changes, placental placement concerns, or other obstetric factors that need ultrasound evaluation.',
        guidance: 'Contact your OB/GYN, midwife, or head to your nearest maternity emergency triage right away.',
        questionsForDoctor: ['Can you check placenta location via ultrasound?', 'Is Rh-immune globulin indicated if I am Rh negative?']
      };
    }

    if (/water broke|fluid leak|leaking fluid|gush of fluid/i.test(q)) {
      return {
        category: 'urgent',
        badgeLabel: 'Prompt Evaluation Needed',
        colorHex: '#DD0D22',
        summary: 'Continuous leaking of clear or pinkish watery fluid may indicate rupture of membranes.',
        reasoning: 'Leaking amniotic fluid before 37 weeks requires immediate care to prevent infection and monitor baby.',
        guidance: 'Put on a clean pad to observe fluid color and call your maternity triage immediately.',
        questionsForDoctor: ['Can we test the fluid with a speculum or nitrazine swab?']
      };
    }

    if ((q.includes('headache') && (q.includes('severe') || q.includes('bad') || q.includes('worst') || q.includes('persistent') || q.includes('unrelieved'))) || 
        /visual|spots in eyes|blurred vision|flashing lights|vision changes|swelling face|swollen face|swelling hands|swollen hands/i.test(q)) {
      return {
        category: 'urgent',
        badgeLabel: 'High Priority Check',
        colorHex: '#DD0D22',
        summary: 'Severe persistent headaches or visual disturbances are clinical warning signs.',
        reasoning: 'These can indicate elevated blood pressure or pre-eclampsia, which requires immediate blood pressure monitoring and urine protein testing.',
        guidance: 'Do not wait. Have your blood pressure checked and contact your prenatal care provider today.',
        questionsForDoctor: ['Please check my blood pressure and rule out pre-eclampsia.']
      };
    }

    if (/movement|haven't felt|not moving|reduced kicks|less kicks|less movement/i.test(q) && week >= 24) {
      return {
        category: 'urgent',
        badgeLabel: 'Fetal Movement Check',
        colorHex: '#DD0D22',
        summary: 'A sudden, noticeable decrease in baby movements warrants clinical monitoring.',
        reasoning: 'While babies have sleep cycles, persistent stillness in late second or third trimester should always be checked with non-stress testing (NST).',
        guidance: 'Drink cold water, lie on your left side for 1 hour. If movement remains quiet, contact your clinic for a quick heartbeat/NST check.',
        questionsForDoctor: ['Can we do a quick non-stress test (NST) to verify baby’s reactivity?']
      };
    }

    // 2. CONTACT PROVIDER (Moderate)
    if (/burning|urination|pee hurts|uti|fever|chills/i.test(q)) {
      return {
        category: 'contact_provider',
        badgeLabel: 'Contact Your Provider',
        colorHex: '#D97706',
        summary: 'Urinary discomfort or fever during pregnancy should be treated promptly.',
        reasoning: 'UTIs are very common due to progesterone-induced urinary stasis, but require pregnancy-safe antibiotics to avoid kidney strain.',
        guidance: 'Call your clinic to drop off a urine sample for culture and sensitivity.',
        questionsForDoctor: ['Can you prescribe a pregnancy-safe antibiotic for urinary symptoms?']
      };
    }

    if (/cramping|cramp|lower belly pain/i.test(q)) {
      return {
        category: 'monitor',
        badgeLabel: 'Common / Worth Monitoring',
        colorHex: '#2563EB',
        summary: 'Mild cramping is very common as your uterus stretches and round ligaments adapt.',
        reasoning: 'If mild and resolves with rest and hydration, it is usually normal uterine growth. If rhythmic, intensifying, or accompanied by spotting, call your doctor.',
        guidance: 'Drink a tall glass of water, rest on your side, and monitor if the sensation softens.',
        questionsForDoctor: ['Is my uterine growth and cervix length tracking as expected?']
      };
    }

    // 3. COMMON & BENIGN (Default / Low Risk)
    return {
      category: 'common',
      badgeLabel: 'Common in Pregnancy',
      colorHex: '#0D9488',
      summary: 'This is a frequent physiological symptom caused by elevated hormones and maternal physical adaptation.',
      reasoning: 'Progesterone and estrogen induce profound vascular and musculoskeletal adaptations throughout all 40 weeks.',
      guidance: 'Rest, hydrate, and mention it at your next routine prenatal appointment if it interferes with your daily comfort.',
      questionsForDoctor: ['Are there gentle exercises or supportive stretches you recommend for this?']
    };
  }

  async saveMemory({ userId = 'preview_user', memory }) {
    const cleanUserId = String(userId).replace('user:', '');
    const item = {
      id: `mem_${Date.now()}`,
      userId: cleanUserId,
      title: memory.title || 'Pregnancy Milestone',
      date: memory.date || todayIso(),
      week: memory.week || 20,
      note: memory.note || '',
      category: memory.category || 'personal', // 'personal' or 'clinical'
      createdAt: new Date().toISOString(),
    };

    try {
      if (db) {
        await db.collection('pregnancy_memories').insertOne(item);
      }
    } catch {}

    if (!memoryStore.memories.has(cleanUserId)) {
      memoryStore.memories.set(cleanUserId, []);
    }
    memoryStore.memories.get(cleanUserId).unshift(item);

    return { success: true, memory: item };
  }

  async getMemories({ userId = 'preview_user' }) {
    const cleanUserId = String(userId).replace('user:', '');
    let list = [];

    try {
      if (db) {
        list = await db.collection('pregnancy_memories')
          .find({ userId: cleanUserId })
          .sort({ date: -1 })
          .toArray();
      }
    } catch {}

    if (list.length === 0 && memoryStore.memories.has(cleanUserId)) {
      list = memoryStore.memories.get(cleanUserId);
    }

    return { memories: list };
  }

  async saveQuestion({ userId = 'preview_user', question }) {
    const cleanUserId = String(userId).replace('user:', '');
    const textContent = (question.text || question.questionText || question.question || '').trim();
    const item = {
      id: `q_${Date.now()}`,
      userId: cleanUserId,
      questionText: textContent,
      text: textContent,
      category: question.category || 'general',
      isForDoctor: Boolean(question.isForDoctor),
      isAnswered: Boolean(question.isAnswered),
      answerSnippet: question.answerSnippet || '',
      createdAt: new Date().toISOString(),
    };

    try {
      if (db) {
        await db.collection('pregnancy_questions').insertOne(item);
      }
    } catch {}

    if (!memoryStore.questions.has(cleanUserId)) {
      memoryStore.questions.set(cleanUserId, []);
    }
    memoryStore.questions.get(cleanUserId).unshift(item);

    return { success: true, question: item };
  }

  async getQuestions({ userId = 'preview_user' }) {
    const cleanUserId = String(userId).replace('user:', '');
    let list = [];

    try {
      if (db) {
        list = await db.collection('pregnancy_questions')
          .find({ userId: cleanUserId })
          .sort({ createdAt: -1 })
          .toArray();
      }
    } catch {}

    if (list.length === 0 && memoryStore.questions.has(cleanUserId)) {
      list = memoryStore.questions.get(cleanUserId);
    }

    return { questions: list };
  }
}

export const pregnancyService = new PregnancyService();
