/**
 * docsyMenopauseService.js
 * Dedicated AI reasoning & clinical synthesis engine for Menopause:
 * "Understanding your body. Protecting your health. Living fully."
 * 
 * Features:
 * 1. Daily Brief: "What matters today?" or "Do nothing" recommendation.
 * 2. "Is This Normal?" structured 6-tier resolver.
 * 3. "+ Tell Blushy" natural language voice/text parser with entity confirmation.
 * 4. 1-Page Clinician Brief builder for doctor visits.
 */

import { env } from '../utils/env.js';
import { LIFE_MODES, POSTMENOPAUSAL_BLEEDING_ALERT } from './menopauseData.js';
import { jsonLanguageInstruction } from '../utils/language.js';

export class DocsyMenopauseService {
  /**
   * Generates the dynamic daily brief answering "What matters today?".
   * Supports "Do nothing" when steady or exhausted.
   */
  static async generateDailyBrief({
    languageCode = 'en',
    profile = {},
    checkins = [],
    myNormal = {},
    whatChanged = [],
    whatBeenSteady = [],
    lifeMode = 'normal',
    treatments = [],
  }) {
    const latest = checkins[0] || {};
    const fallback = this.generateHeuristicBrief({ latest, myNormal, whatChanged, whatBeenSteady, lifeMode });

    if (!env.grokApiKey) {
      return fallback;
    }

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 6000);

      const prompt = `You are Docsy, a wise, compassionate, clinically grounded AI companion for Blushy's Menopause life stage ("Understanding your new chapter").
User Context:
- Name: ${profile.preferred_name || profile.name || 'Ananya'}
- Life Mode: ${lifeMode} (${LIFE_MODES[lifeMode.toUpperCase()]?.label || lifeMode})
- Recent Check-in: Sleep: ${latest.sleepQuality || 'normal'}, Energy: ${latest.energyLevel || 'steady'}, Mood: ${latest.moodState || 'calm'}, Hot flashes: ${latest.hotFlashes || 'none'}, Joints: ${latest.jointDiscomfort || 'none'}
- What Changed: ${whatChanged.map((c) => c.title).join('; ') || 'Steady'}
- What's Been Steady: ${whatBeenSteady.map((s) => s.title).join('; ') || 'Balanced'}
- Active Treatments: ${treatments.map((t) => t.name).join(', ') || 'None recorded'}

PHILOSOPHY RULES:
1. NOT a "longevity biohacking" app. Frame as "Understanding your body. Protecting your health. Living fully."
2. Low-cortisol health experience: If she is steady or exhausted, literally recommend "Do nothing" and celebrate her balance!
3. Never make definitive diagnostic claims. Frame observations as personal associations, not clinical proof.
4. Return ONLY a valid JSON object matching this schema (no markdown, no backticks):
{
  "openingHeadline": "Warm 1-sentence headline for today (e.g., 'Your body is resting well this week' or 'Gentle morning pacing today')",
  "doNothingAffirmation": "If things are steady or she is exhausted, a warm permission statement like: 'You\\'re doing okay. Nothing urgent needs fixing today. Go live your life. ❤️'. Otherwise empty string.",
  "whatMattersToday": [
    "1-3 dynamic, compassionate bullet points answering what matters today based on her logs"
  ],
  "whyToday": "Transparent 1-sentence explanation of why this advice was surfaced today",
  "promptPills": [
    "3 specific, personalized questions she might want to ask Docsy today"
  ]
}${jsonLanguageInstruction(languageCode)}`;

      const res = await fetch(env.grokApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.grokApiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://blushy.app',
          'X-Title': 'Blushy Menopause AI',
        },
        body: JSON.stringify({
          model: env.grokApiModel || 'x-ai/grok-2-1212',
          messages: [{ role: 'user', content: prompt }],
          temperature: 0.7,
          max_tokens: 450,
        }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!res.ok) {
        return fallback;
      }

      const data = await res.json();
      const raw = data?.choices?.[0]?.message?.content?.trim() || '';
      const clean = raw.replace(/^```json\s*/, '').replace(/```\s*$/, '').trim();
      const parsed = JSON.parse(clean);

      return {
        openingHeadline: parsed.openingHeadline || fallback.openingHeadline,
        doNothingAffirmation: parsed.doNothingAffirmation || fallback.doNothingAffirmation,
        whatMattersToday: Array.isArray(parsed.whatMattersToday) && parsed.whatMattersToday.length > 0 ? parsed.whatMattersToday : fallback.whatMattersToday,
        whyToday: parsed.whyToday || fallback.whyToday,
        promptPills: Array.isArray(parsed.promptPills) && parsed.promptPills.length > 0 ? parsed.promptPills : fallback.promptPills,
      };
    } catch (err) {
      console.warn('[DocsyMenopauseService] AI generation error, using heuristic:', err.message);
      return fallback;
    }
  }

  /**
   * Resilient clinical heuristic fallback for the daily brief.
   */
  static generateHeuristicBrief({ latest, myNormal, whatChanged, whatBeenSteady, lifeMode }) {
    const isExhausted = lifeMode === 'exhausted' || lifeMode === 'overwhelmed';
    const isSteady = (whatChanged.length === 0 || whatChanged[0]?.id === 'c_equipoise') && latest.sleepQuality === 'restful';

    let doNothing = '';
    if (isExhausted) {
      doNothing = "You don't need another health task today. Rest is productive. Go easy on yourself. ❤️";
    } else if (isSteady) {
      doNothing = "You're doing okay. Nothing urgent stands out from what you've logged. Go live your life. ❤️";
    }

    const matters = [];
    if (latest.sleepQuality === 'night_sweats' || latest.sleepQuality === 'interrupted_waking') {
      matters.push("Support your evening cooling: bedroom at 18–19°C and light breathable layers.");
    }
    if (latest.jointDiscomfort === 'morning_stiffness') {
      matters.push("A gentle 10-minute morning walk or joint mobility warm-up helps ease early stiffness.");
    }
    if (matters.length === 0) {
      matters.push("Keep moving comfortably: 20 minutes of brisk walking promotes cardiovascular elasticity.");
      matters.push("Protect bone density: Include calcium-rich foods and natural sunshine for Vitamin D.");
    }

    // Whether anything has actually been logged.
    //
    // `matters` above already falls back to generic guidance when nothing has,
    // but `whyToday` claimed the brief was "tailored to recent check-in
    // patterns" regardless -- so an account with no check-ins at all was told
    // its advice came from data it had never entered. The life mode is a
    // setting rather than an observation, so that half stays true either way.
    const hasCheckinSignals = Boolean(
      latest && (
        latest.sleepQuality
        || latest.jointDiscomfort
        || latest.hotFlashes
        || latest.moodState
        || latest.energyLevel
      ),
    );
    const lifeModeLabel = LIFE_MODES[lifeMode.toUpperCase()]?.label || lifeMode;

    return {
      openingHeadline: isExhausted
        ? "Permission to rest and recharge today."
        : "Understanding your body. Protecting your vitality.",
      doNothingAffirmation: doNothing,
      whatMattersToday: matters,
      whyToday: hasCheckinSignals
        ? `Tailored to your current '${lifeModeLabel}' life mode and recent check-in patterns.`
        : `Based on your '${lifeModeLabel}' life mode. Log a check-in and this starts reflecting your own patterns.`,
      promptPills: [
        "Is 3 AM waking common in menopause?",
        "How can I protect my bone density?",
        "Tell me about localized vaginal comfort options",
      ],
    };
  }

  /**
   * Structured "Is This Normal?" clinical resolver.
   */
  static async resolveIsThisNormal({ userQuery, checkins = [], myNormal = {}, lifeMode = 'normal', languageCode = 'en' }) {
    const trimmed = (userQuery || '').trim();
    if (!trimmed) {
      return {
        whatYouToldMe: 'No question entered.',
        whatWeKnow: 'Menopause brings natural bodily adaptations.',
        whatMightBeGoingOn: 'Hormonal fluctuations settle into a new baseline.',
        whatYouCanTry: 'Track your symptoms and maintain balanced habits.',
        whenToCheckWithDoctor: 'If anything causes persistent concern.',
        suggestedTracking: 'Track in daily check-in',
      };
    }
    const lower = trimmed.toLowerCase();
    if (lower.includes('bleed') || lower.includes('spotting') || lower.includes('blood') || lower.includes('period')) {
      return {
        whatYouToldMe: trimmed,
        whatWeKnow: POSTMENOPAUSAL_BLEEDING_ALERT.headline,
        whatMightBeGoingOn: POSTMENOPAUSAL_BLEEDING_ALERT.explanation,
        whatYouCanTry: "Do not wait or dismiss it. Note the date, color (pink, brown, or red), and whether it was spotting or flow.",
        whenToCheckWithDoctor: "Right away. Any postmenopausal bleeding or spotting requires an in-person clinical assessment (typically a pelvic ultrasound or biopsy) by your gynecologist.",
        suggestedTracking: "Track bleeding episodes in your log and bring this summary to your doctor visit.",
        isRedFlag: true,
        alertTitle: POSTMENOPAUSAL_BLEEDING_ALERT.title,
      };
    }

    if (env.grokApiKey) {
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 6000);

        const prompt = `You are Docsy, an empathetic women's health AI. The user is in Menopause and asks: "${trimmed}".
Provide a structured, clinically responsible response following this exact 6-tier schema.
DO NOT diagnose. Emphasize that symptoms are common but individual.
Return ONLY valid JSON (no markdown):
{
  "whatYouToldMe": "Concise summary of what she described",
  "whatWeKnow": "Evidence-based clinical context on whether this is common in postmenopause",
  "whatMightBeGoingOn": "Physiological explanation without alarming language",
  "whatYouCanTry": "2-3 practical, low-friction comfort steps",
  "whenToCheckWithDoctor": "Specific red flags or persistence duration when she should consult a clinician",
  "suggestedTracking": "A short suggestion on what to log in Blushy (e.g., 'Track 3 AM waking for 7 days')"
}${jsonLanguageInstruction(languageCode)}`;

        const res = await fetch(env.grokApiUrl, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.grokApiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: env.grokApiModel || 'x-ai/grok-2-1212',
            messages: [{ role: 'user', content: prompt }],
            temperature: 0.6,
            max_tokens: 500,
          }),
          signal: controller.signal,
        });

        clearTimeout(timeoutId);

        if (res.ok) {
          const data = await res.json();
          const clean = data?.choices?.[0]?.message?.content?.trim().replace(/^```json\s*/, '').replace(/```\s*$/, '').trim();
          return JSON.parse(clean);
        }
      } catch (err) {
        console.warn('[DocsyMenopauseService] resolveIsThisNormal error:', err.message);
      }
    }

    // Heuristic response
    return {
      whatYouToldMe: trimmed,
      whatWeKnow: "Shifts in sleep, temperature regulation, and tissue hydration are frequently reported by women in menopause as hormones stabilize.",
      whatMightBeGoingOn: "Lower systemic estradiol levels affect the hypothalamic thermoregulatory center, collagen synthesis, and sleep depth.",
      whatYouCanTry: "Keep your sleep environment cool (18°C), ensure adequate hydration, and try gentle evening stretches.",
      whenToCheckWithDoctor: "If symptoms interfere with your daily life, persist for more than several weeks, or if you notice any vaginal bleeding.",
      suggestedTracking: `Would you like me to monitor this in your daily check-in?`,
    };
  }

  /**
   * "+ Tell Blushy" Natural Language Parser.
   * Parses conversational text into structured symptoms and asks confirmation.
   */
  static async parseNaturalNote({ noteText = '' }) {
    const raw = (noteText || '').trim();
    if (!raw) {
      return {
        extractedEntities: [],
        confirmationMessage: 'I did not catch any specific symptoms. You can tell me how your sleep, energy, or comfort felt today.',
        parsedCheckin: {},
      };
    }

    if (env.grokApiKey) {
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 6000);

        const prompt = `You are Blushy's natural language health note parser. The menopause user wrote: "${raw}".
Extract any health markers mentioned (sleep, energy, hot flashes, night sweats, joint pain, vaginal comfort, mood).
Map them to standardized values:
- sleepQuality: 'restful' | 'interrupted_waking' | 'night_sweats' | 'insomnia' | 'not_sure'
- energyLevel: 'steady' | 'fluctuating' | 'exhausted' | 'not_sure'
- hotFlashes: 'none' | 'mild_daytime' | 'night_flushes' | 'frequent' | 'not_sure'
- jointDiscomfort: 'none' | 'morning_stiffness' | 'aching' | 'not_sure'
- vaginalComfort: 'normal' | 'dryness' | 'discomfort' | 'not_sure'
- bleedingLogged: boolean (true only if spotting or blood mentioned)

Return ONLY valid JSON (no markdown):
{
  "extractedEntities": ["List of short human-readable entities extracted, e.g. 'Night waking', 'Morning joint stiffness'"],
  "confirmationMessage": "Warm question: 'I understood this as [X] and [Y]. Want me to save them?'",
  "parsedCheckin": {
    "sleepQuality": "...",
    "energyLevel": "...",
    "hotFlashes": "...",
    "jointDiscomfort": "...",
    "vaginalComfort": "...",
    "bleedingLogged": false
  }
}`;

        const res = await fetch(env.grokApiUrl, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.grokApiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: env.grokApiModel || 'x-ai/grok-2-1212',
            messages: [{ role: 'user', content: prompt }],
            temperature: 0.3,
            max_tokens: 400,
          }),
          signal: controller.signal,
        });

        clearTimeout(timeoutId);

        if (res.ok) {
          const data = await res.json();
          const clean = data?.choices?.[0]?.message?.content?.trim().replace(/^```json\s*/, '').replace(/```\s*$/, '').trim();
          return JSON.parse(clean);
        }
      } catch (err) {
        console.warn('[DocsyMenopauseService] parseNaturalNote error:', err.message);
      }
    }

    // Heuristic entity matcher
    const lower = raw.toLowerCase();
    const entities = [];
    const parsed = {};

    if (lower.includes('sweat') || lower.includes('flash') || lower.includes('drenched') || lower.includes('hot')) {
      entities.push('Night flushes / hot flashes');
      parsed.hotFlashes = 'night_flushes';
    }
    if (lower.includes('sleep') || lower.includes('woke') || lower.includes('waking') || lower.includes('insomnia')) {
      entities.push('Sleep disruption');
      parsed.sleepQuality = 'interrupted_waking';
    }
    if (lower.includes('joint') || lower.includes('knee') || lower.includes('ache') || lower.includes('stiff')) {
      entities.push('Joint stiffness');
      parsed.jointDiscomfort = 'morning_stiffness';
    }
    if (lower.includes('tired') || lower.includes('exhaust') || lower.includes('drained') || lower.includes('fatigue')) {
      entities.push('Lower energy');
      parsed.energyLevel = 'exhausted';
    }
    if (lower.includes('dry') || lower.includes('intimate') || lower.includes('vaginal')) {
      entities.push('Vaginal dryness');
      parsed.vaginalComfort = 'dryness';
    }
    if (lower.includes('bleed') || lower.includes('spotting') || lower.includes('blood')) {
      entities.push('Vaginal spotting / bleeding');
      parsed.bleedingLogged = true;
    }

    const count = entities.length;
    const confirmation = count > 0
      ? `I understood this as ${entities.join(' and ')}. Want me to save them to your health log?`
      : "I captured your note. Would you like to record this for today?";

    return {
      extractedEntities: entities,
      confirmationMessage: confirmation,
      parsedCheckin: parsed,
    };
  }

  /**
   * Generates a 1-Page Clinician Brief for upcoming doctor appointments.
   */
  static generateClinicianBrief({
    profile = {},
    checkins = [],
    myNormal = {},
    whatChanged = [],
    whatBeenSteady = [],
    treatments = [],
    questions = [],
  }) {
    const userName = profile.preferred_name || profile.name || 'Patient';
    const dateStr = new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });

    let briefText = `BLUSHY CLINICIAN SUMMARY: MENOPAUSE & HEALTH BASELINE\n`;
    briefText += `Patient: ${userName} | Date: ${dateStr}\n`;
    briefText += `Stage: Postmenopause (12+ months amenorrhea)\n`;
    briefText += `--------------------------------------------------------\n\n`;

    briefText += `1. LONGITUDINAL BASELINE ("MY NORMAL"):\n`;
    if (myNormal.markers) {
      for (const m of myNormal.markers) {
        briefText += `• ${m.domain}: ${m.baseline} (${m.status})\n`;
      }
    } else {
      briefText += `• Baseline establishing across recent entries.\n`;
    }
    briefText += `\n`;

    briefText += `2. RECENT SHIFTS NOTICED ("WHAT CHANGED"):\n`;
    for (const c of whatChanged) {
      briefText += `• ${c.title} (${c.timeframe}): ${c.detail}\n`;
    }
    briefText += `\n`;

    briefText += `3. WHAT HAS BEEN STEADY:\n`;
    for (const s of whatBeenSteady) {
      briefText += `• ${s.title}: ${s.detail}\n`;
    }
    briefText += `\n`;

    briefText += `4. CURRENT TREATMENTS & SUPPLEMENTS:\n`;
    if (treatments.length > 0) {
      for (const t of treatments) {
        briefText += `• ${t.name} (${t.category}): ${t.dose || 'Active'} | Started: ${t.startDate.slice(0, 10)}\n`;
        if (t.notes) briefText += `  Notes: ${t.notes}\n`;
      }
    } else {
      briefText += `• No active hormone therapy or prescription treatments recorded.\n`;
    }
    briefText += `\n`;

    briefText += `5. PATIENT QUESTIONS FOR THIS VISIT (${questions.length} saved):\n`;
    if (questions.length > 0) {
      for (let i = 0; i < questions.length; i++) {
        briefText += `[ ] Q${i + 1}: ${questions[i].text} (${questions[i].category})\n`;
      }
    } else {
      briefText += `• No specific questions saved in inbox.\n`;
    }
    briefText += `\n`;

    briefText += `--------------------------------------------------------\n`;
    briefText += `Generated securely via Blushy Women's Health OS.\n`;

    return {
      title: `${userName}'s Clinician Summary`,
      generatedAt: new Date().toISOString(),
      rawSummaryText: briefText,
      totalQuestions: questions.length,
      activeTreatmentsCount: treatments.length,
      recentShiftsCount: whatChanged.length,
    };
  }
}
