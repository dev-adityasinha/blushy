/**
 * docsyPerimenopauseService.js
 * Dedicated AI reasoning & synthesis engine for Perimenopause Docsy ("My Transition").
 * Implements the 4-tier confidence layer, "Why Today?" reasoning, and natural language note parsing.
 */

import { env } from '../utils/env.js';
import { jsonLanguageInstruction } from '../utils/language.js';

export class DocsyPerimenopauseService {
  /**
   * Generates the dynamic daily briefing for the Perimenopause dashboard.
   * Leverages real Grok/OpenRouter AI with short timeout and resilient clinical heuristic fallback.
   */
  static async generateDailyBrief({ profile = {}, recentCheckins = [], confidence = {}, deltas = {}, connections = [], focus = 'sleep', lifeMode = 'normal', languageCode = 'en' }) {
    const fallback = this.generateHeuristicBrief({ profile, recentCheckins, confidence, deltas, connections, focus, lifeMode });

    if (!env.grokApiKey) {
      return fallback;
    }

    try {
      const latest = recentCheckins[0] || {};
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 8000);

      const prompt = `You are Docsy, a compassionate, clinically grounded AI women's health companion for Blushy's midlife transition stage ("My Transition" / Perimenopause).
User context:
- Transition Onset: ${profile.onsetDuration || 'A few months'}
- Current Primary Focus: ${focus}
- Life Mode: ${lifeMode}
- Recent Checkin: Energy: ${latest.energyLevel || 'normal'}, Sleep: ${latest.sleepQuality || 'steady'}, Temperature/Flashes: ${latest.temperatureFlashes || 'none'}, Mood/Fog: ${latest.moodFog || 'balanced'}, Cycle Status: ${latest.cycleStatus || 'typical'}
- Observed Deltas: ${JSON.stringify(deltas)}
- What Blushy Sees: ${confidence.whatWereSeeing || 'Steady baseline'}
- Observed Connections: ${connections.map((c) => c.title).join('; ') || 'None prominent yet'}

CRITICAL RULES:
1. Speak in a warm, empathetic girlfriend register.
2. DO NOT make definitive diagnostic claims. Frame observations as personal associations (pattern, not causation).
3. NEVER prescribe or recommend specific pharmaceutical brand names.
4. Return ONLY a valid JSON object matching this schema (no markdown formatting, no code blocks):
{
  "openingGreeting": "Warm 1-2 sentence morning synthesis addressing how she feels today and validating her experience.",
  "whyToday": "Clear 1-sentence explanation of why this topic or focus is surfaced for her today.",
  "recoveryPoint": "Concise 1-sentence actionable comfort, cooling, or lifestyle suggestion she can act on today.",
  "noticePoint": "Concise 1-sentence gentle signal or body pattern to notice today without anxiety.",
  "promptPills": ["4 personalized, specific questions she might want to ask Docsy today"]
}${jsonLanguageInstruction(languageCode)}`;

      const res = await fetch(env.grokApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.grokApiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://blushy.app',
          'X-Title': 'Blushy Midlife Health AI',
        },
        body: JSON.stringify({
          model: env.grokApiModel || 'x-ai/grok-2-1212',
          messages: [{ role: 'user', content: prompt }],
          temperature: 0.72,
          max_tokens: 450,
        }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!res.ok) {
        return fallback;
      }

      const json = await res.json();
      const rawText = json?.choices?.[0]?.message?.content?.trim() || '';
      const cleanJson = rawText.replace(/```json/g, '').replace(/```/g, '').trim();
      const parsed = JSON.parse(cleanJson);

      return {
        openingGreeting: parsed.openingGreeting || fallback.openingGreeting,
        whyToday: parsed.whyToday || fallback.whyToday,
        recoveryPoint: parsed.recoveryPoint || fallback.recoveryPoint,
        noticePoint: parsed.noticePoint || fallback.noticePoint,
        promptPills: Array.isArray(parsed.promptPills) && parsed.promptPills.length >= 3 ? parsed.promptPills : fallback.promptPills,
        confidence,
      };
    } catch (err) {
      return fallback;
    }
  }

  /**
   * Resilient, clinically accurate heuristic briefing used when offline or on API timeout.
   */
  static generateHeuristicBrief({ recentCheckins = [], confidence = {}, deltas = {}, focus = 'sleep', lifeMode = 'normal' }) {
    const latest = recentCheckins[0] || {};
    const hasNightSweats = latest.temperatureFlashes === 'night_sweats' || latest.temperatureFlashes === 'severe';
    const hasSleepDisruption = latest.sleepQuality === 'fragmented' || latest.sleepQuality === 'insomnia' || latest.sleepQuality === 'woke_sweating';
    const hasBleedingShift = latest.cycleStatus === 'heavy' || latest.cycleStatus === 'irregular';

    if (hasNightSweats || hasSleepDisruption || lifeMode === 'terrible_sleep') {
      return {
        openingGreeting: "Your sleep was disrupted recently, and your body has been working through nighttime temperature surges. Be gentle with yourself today.",
        whyToday: "Sleep and night temperatures are on your radar today because you've logged nighttime heat surges this week.",
        recoveryPoint: "Drop the bedroom thermostat to 18°C tonight and keep an insulated tumbler of ice water right by your bedside.",
        noticePoint: "Notice if late-evening caffeine or heated room air correlates with midnight awakenings.",
        promptPills: [
          "Why am I waking up drenched?",
          "Is this night sweats or anxiety?",
          "What can help me sleep through tonight?",
          "Tell Docsy more about my symptoms",
        ],
        confidence,
      };
    }

    if (hasBleedingShift || focus === 'period_changes') {
      return {
        openingGreeting: "You've noticed shifts in your cycle flow and spacing. Transition rhythm shifts are completely normal and worth mapping.",
        whyToday: "Cycle timing is front and center today following your latest period and flow log.",
        recoveryPoint: "Keep an emergency care pouch ready in your bag so unexpected cycle arrival never causes unnecessary stress.",
        noticePoint: "Keep track of how many pads you use during heavy flow stretches so your clinician has clear data.",
        promptPills: [
          "Why are my periods suddenly irregular?",
          "How long can perimenopause cycles stretch?",
          "What should I ask my doctor about heavy flow?",
          "Tell Docsy more about my cycle",
        ],
        confidence,
      };
    }

    return {
      openingGreeting: "Your body is moving through its midlife transition rhythm. Your recent logs look steady today — give yourself credit for how you're navigating it.",
      whyToday: "Surfaced today based on your steady check-in and balanced daily energy logs.",
      recoveryPoint: "Take a 10-minute walk in natural morning sunlight to anchor your circadian rhythm and daytime focus.",
      noticePoint: "Notice the steady equilibrium in your body today — not every day requires fixing or adjusting.",
      promptPills: [
        "What should I expect next in my transition?",
        "How can I protect my bone density in midlife?",
        "Should I discuss HRT with my doctor?",
        "Ask Docsy anything about your body",
      ],
      confidence,
    };
  }

  /**
   * Parses natural language free-text or voice notes into structured logs.
   */
  static async parseNaturalNote(text = '') {
    if (!text || text.trim().length === 0) {
      return { success: false, message: 'Note text cannot be empty.' };
    }

    const lower = text.toLowerCase();
    const extracted = {
      temperatureFlashes: 'none',
      sleepQuality: 'normal',
      moodFog: 'balanced',
      cycleStatus: 'none',
      detectedItems: [],
      rawText: text.trim(),
    };

    if (lower.includes('sweat') || lower.includes('night sweat') || lower.includes('drenched') || lower.includes('hot flash') || lower.includes('flushes') || lower.includes('burning up')) {
      extracted.temperatureFlashes = lower.includes('night') || lower.includes('drenched') ? 'night_sweats' : 'moderate';
      extracted.detectedItems.push('Temperature Surge / Night Sweats');
    }

    if (lower.includes('woke up') || lower.includes('cannot sleep') || lower.includes('insomnia') || lower.includes('tossing') || lower.includes('exhausted') || lower.includes('tired')) {
      extracted.sleepQuality = lower.includes('sweat') ? 'woke_sweating' : 'fragmented';
      extracted.detectedItems.push('Disrupted Sleep');
    }

    if (lower.includes('fog') || lower.includes('brain fog') || lower.includes('forget') || lower.includes('anxious') || lower.includes('irritable') || lower.includes('mood')) {
      extracted.moodFog = lower.includes('fog') ? 'brain_fog' : 'mood_swings';
      extracted.detectedItems.push('Brain Fog / Emotional Shift');
    }

    if (lower.includes('period') || lower.includes('bleeding') || lower.includes('spotting') || lower.includes('cramps') || lower.includes('late')) {
      extracted.cycleStatus = lower.includes('heavy') ? 'heavy' : (lower.includes('spotting') ? 'spotting' : 'irregular');
      extracted.detectedItems.push('Cycle / Bleeding Change');
    }

    extracted.summary = extracted.detectedItems.length > 0
      ? `Identified: ${extracted.detectedItems.join(', ')}`
      : 'Saved personal reflection note to your health timeline.';

    return {
      success: true,
      extracted,
    };
  }
}
