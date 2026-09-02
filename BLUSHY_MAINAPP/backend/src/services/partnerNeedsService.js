import { aiHistoryRepository } from '../repositories/aiHistoryRepository.js';
import { journalRepository } from '../repositories/journalRepository.js';
import { dailyMoodRepository } from '../repositories/dailyMoodRepository.js';
import { env } from '../utils/env.js';

function isWithinHours(dateInput, hours = 48) {
  if (!dateInput) return false;
  const d = new Date(dateInput);
  if (Number.isNaN(d.getTime())) return false;
  const diffMs = Date.now() - d.getTime();
  return diffMs >= 0 && diffMs <= hours * 60 * 60 * 1000;
}

function parseJsonSafely(raw) {
  if (!raw || typeof raw !== 'string') return null;
  try {
    const cleaned = raw.replace(/```json\s*/gi, '').replace(/```\s*/gi, '').trim();
    return JSON.parse(cleaned);
  } catch {
    const firstBrace = raw.indexOf('{');
    const lastBrace = raw.lastIndexOf('}');
    if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
      try {
        return JSON.parse(raw.slice(firstBrace, lastBrace + 1));
      } catch {
        return null;
      }
    }
    return null;
  }
}

function fallbackKeywordAnalysis({ chatText, journalText, moodText, isPartnerWoman, partnerName }) {
  const allText = `${chatText} ${journalText} ${moodText}`.toLowerCase();
  const needs = [];

  const pronoun = isPartnerWoman ? 'She' : 'He';
  const possessive = isPartnerWoman ? 'her' : 'his';

  if (/cramp|period|bleed|pms|bloat|uterus|ovary|pelvic/.test(allText)) {
    needs.push({
      label: `${pronoun} needs physical comfort & pain relief`,
      tip: `Docsy recommends: Bring a warm heat pack, brew ${possessive} favorite hot herbal tea, and don't let ${possessive} strain today.`,
      category: 'Comfort',
      urgency: 'high',
      source: 'Based on recent cycle & health notes',
    });
  }

  if (/tired|exhaust|sleepy|drained|fatigue|burnout|no energy|heavy head|sleep/.test(allText)) {
    needs.push({
      label: `${pronoun} needs deep rest & downtime`,
      tip: `Docsy recommends: Take care of dinner and household tasks tonight so ${pronoun.toLowerCase()} can wind down and rest early.`,
      category: 'Rest',
      urgency: 'normal',
      source: 'Based on recent logs',
    });
  }

  if (/stress|overwhelm|pressure|deadline|boss|workload|anxious|anxiety|panic|crying|sad|down|alone|lonely/.test(allText)) {
    needs.push({
      label: `${pronoun} needs gentle emotional support & reassurance`,
      tip: `Docsy recommends: Listen without trying to fix everything immediately. Acknowledge ${possessive} feelings and remind ${possessive} that you're in this together.`,
      category: 'Emotional Support',
      urgency: 'high',
      source: 'Based on recent reflections',
    });
  }

  if (/chore|errand|clean|cook|dishes|laundry|grocer|busy|hectic/.test(allText)) {
    needs.push({
      label: `${pronoun} needs practical help with daily chores`,
      tip: `Docsy recommends: Proactively handle a chore (like dishes or laundry) before being asked. It takes a huge mental load off.`,
      category: 'Practical Help',
      urgency: 'normal',
      source: 'Based on recent logs',
    });
  }

  if (/space|quiet|alone|overstimulat|headache|migraine/.test(allText)) {
    needs.push({
      label: `${pronoun} needs quiet space to recharge`,
      tip: `Docsy recommends: Give ${possessive} uninterrupted downtime without pressure. Say: 'I am here in the other room whenever you need me.'`,
      category: 'Space',
      urgency: 'normal',
      source: 'Based on recent chat',
    });
  }

  if (/craving|sweet|chocolate|snack|hungry|treat|dessert/.test(allText)) {
    needs.push({
      label: `${pronoun} is craving comfort food or snacks`,
      tip: `Docsy recommends: Surprise ${possessive} with a favorite comforting treat, chocolate, or a warm meal.`,
      category: 'Nutrition',
      urgency: 'normal',
      source: 'Based on recent reflections',
    });
  }

  if (needs.length > 0) {
    return {
      hasNeeds: true,
      partnerName,
      title: isPartnerWoman ? "What she needs today" : "What he needs today",
      message: `Based on ${possessive} recent check-ins:`,
      tip: `Docsy recommends: Check the cards below to see how to support ${partnerName} today.`,
      needs: needs.slice(0, 4),
      analyzedAt: new Date().toISOString(),
    };
  }

  return {
    hasNeeds: false,
    partnerName,
    title: isPartnerWoman ? "She doesn't need anything right now" : "He doesn't need anything right now",
    message: "Everything seems peaceful! No discomfort or specific requests logged recently.",
    tip: "Docsy recommends: A warm check-in or simple 'Thinking of you' goes a long way.",
    needs: [],
    analyzedAt: new Date().toISOString(),
  };
}

export async function getDynamicPartnerNeeds({ partnerUserId, partnerRole = 'woman', cycleInfo = null, partnerName = 'Her' }) {
  const isPartnerWoman = partnerRole !== 'man' && partnerRole !== 'partner';
  const pronoun = isPartnerWoman ? 'She' : 'He';
  const possessive = isPartnerWoman ? 'her' : 'his';

  try {
    const cleanUserId = typeof partnerUserId === 'string' ? partnerUserId.replace('user:', '') : partnerUserId;

    // 1. Fetch recent Docsy chat history (last 48 hours)
    let chatHistory = [];
    try {
      chatHistory = await aiHistoryRepository.listHistory(cleanUserId);
    } catch {
      chatHistory = [];
    }

    const recentChats = (chatHistory || [])
      .filter((m) => isWithinHours(m.createdAt, 48))
      .filter((m) => m.userMessage && m.userMessage.trim().length > 0);

    const chatText = recentChats
      .map((m) => `[Chat]: ${m.userMessage}`)
      .join('\n');

    // 2. Fetch recent journals (last 48 hours)
    let journals = [];
    try {
      journals = await journalRepository.getJournalsByUserId(cleanUserId, 5);
    } catch {
      journals = [];
    }

    const recentJournals = (journals || []).filter((j) => {
      if (j.createdAt && isWithinHours(j.createdAt, 48)) return true;
      if (j.date) {
        const d = new Date(`${j.date}T00:00:00Z`);
        return isWithinHours(d, 48);
      }
      return false;
    });

    const journalText = recentJournals
      .map((j) => {
        const entryTexts = Array.isArray(j.entries)
          ? j.entries.map((e) => (typeof e === 'string' ? e : e?.text || e?.content || '')).join(' ')
          : '';
        return `[Journal (${j.date || 'recent'})]: ${entryTexts} ${j.summary || ''}`.trim();
      })
      .filter((t) => t.length > 0)
      .join('\n');

    // 3. Fetch recent daily mood (last 48 hours)
    let recentMoods = [];
    try {
      recentMoods = await dailyMoodRepository.getRecentDailyMoods(cleanUserId, 2);
    } catch {
      recentMoods = [];
    }

    const moodText = recentMoods
      .map((m) => `[Mood (${m.entryDate})]: Mood: ${m.mood || 'normal'}, Energy: ${m.energyLevel || 'normal'}, Stress: ${m.stressLevel || 'normal'}, Notes: ${m.notes || 'none'}`)
      .join('\n');

    // Check if there is literally any data in the last 48 hours
    const hasAnyActivity = chatText.trim().length > 0 || journalText.trim().length > 0 || recentMoods.some((m) => m.notes || m.mood === 'low' || m.mood === 'irritated' || m.stressLevel === 'high' || m.stressLevel === 'medium');

    if (!hasAnyActivity) {
      return {
        hasNeeds: false,
        partnerName,
        title: isPartnerWoman ? "She doesn't need anything right now" : "He doesn't need anything right now",
        message: `Everything is peaceful! ${partnerName} hasn't logged any distress or asked for specific help recently.`,
        tip: "Docsy recommends: A warm check-in or sweet text is always wonderful just to remind her you care.",
        needs: [],
        analyzedAt: new Date().toISOString(),
      };
    }

    // Call LLM for empathetic and tailored synthesis
    const aiChatApiKey = env.aiChatApiKey;
    const aiChatApiUrl = env.aiChatApiUrl;
    const aiChatModel = env.aiChatModel;

    if (!aiChatApiKey) {
      return fallbackKeywordAnalysis({ chatText, journalText, moodText, isPartnerWoman, partnerName });
    }

    const cycleDesc = cycleInfo && cycleInfo.phase
      ? `Day ${cycleInfo.currentCycleDay || '?'} of cycle (${cycleInfo.phase} phase)`
      : `General phase`;

    const systemPrompt = `You are Docsy, an empathetic, intuitive AI relationship companion.
Your role is to analyze a woman's (or partner's) recent personal shares and identify what her partner can do to help her today.

Context of ${partnerName} (${pronoun}):
- Role: ${partnerRole}
- Cycle / Health Stage: ${cycleDesc}

Recent Docsy Chats (last 48h):
${chatText || 'None'}

Recent Journal Reflections (last 48h):
${journalText || 'None'}

Recent Mood & Health Logs (last 48h):
${moodText || 'None'}

CRITICAL INSTRUCTIONS:
1. Determine if she has specific needs, physical symptoms (cramps, fatigue, headache, nausea), emotional stress (work pressure, anxiety, sadness), daily burdens (chores, lack of time), cravings, or need for affection/space.
2. If she has NO negative feelings or specific requests (e.g. she is feeling great, relaxed, happy, or only chatting about casual neutral things), return "hasNeeds": false with a positive message.
3. If she DOES have needs, extract 1 to 4 clear, thoughtful need cards for her partner.
   - "label": Short clear sentence e.g. "She needs rest after a tiring workday", "She needs soothing comfort for period cramps", "She needs reassurance with work stress".
   - "tip": Concrete, actionable tip starting with "Docsy recommends: ...".
   - "category": Choose one of ["Rest", "Comfort", "Practical Help", "Emotional Support", "Space", "Nutrition", "Affection"].
   - "urgency": "high" or "normal".
   - "source": e.g. "From recent Docsy chat", "From journal reflection", "From mood log".

Respond ONLY with valid JSON in this exact schema (no markdown outside the JSON, no extra text):
{
  "hasNeeds": true,
  "title": "What she needs today",
  "message": "Based on what she shared recently:",
  "tip": "Docsy recommends: ...",
  "needs": [
    {
      "label": "She needs ...",
      "tip": "Docsy recommends: ...",
      "category": "Rest",
      "urgency": "normal",
      "source": "From recent Docsy chat"
    }
  ]
}`;

    const response = await fetch(aiChatApiUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${aiChatApiKey}`,
        'Content-Type': 'application/json',
        'X-Title': 'Docsy Dynamic Needs',
      },
      body: JSON.stringify({
        model: aiChatModel,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: 'Analyze the partner entries and return the structured JSON.' }
        ],
        temperature: 0.65,
        max_tokens: 500,
      }),
    });

    if (response.ok) {
      const payload = await response.json();
      const content = payload?.choices?.[0]?.message?.content;
      const parsed = parseJsonSafely(content);

      if (parsed && typeof parsed === 'object') {
        const hasNeeds = Boolean(parsed.hasNeeds && Array.isArray(parsed.needs) && parsed.needs.length > 0);
        return {
          hasNeeds,
          partnerName,
          title: parsed.title || (hasNeeds ? (isPartnerWoman ? "What she needs today" : "What he needs today") : (isPartnerWoman ? "She doesn't need anything right now" : "He doesn't need anything right now")),
          message: parsed.message || (hasNeeds ? `Based on ${possessive} recent check-ins:` : `Everything is peaceful! ${partnerName} hasn't logged any distress recently.`),
          tip: parsed.tip || "Docsy recommends: A warm check-in or simple 'Thinking of you' goes a long way.",
          needs: Array.isArray(parsed.needs) ? parsed.needs : [],
          analyzedAt: new Date().toISOString(),
        };
      }
    }

    return fallbackKeywordAnalysis({ chatText, journalText, moodText, isPartnerWoman, partnerName });
  } catch (err) {
    console.error('Error in getDynamicPartnerNeeds:', err);
    return fallbackKeywordAnalysis({ chatText: '', journalText: '', moodText: '', isPartnerWoman, partnerName });
  }
}
