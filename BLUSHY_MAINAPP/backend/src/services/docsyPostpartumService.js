/**
 * docsyPostpartumService.js
 * Dedicated AI reasoning & synthesis engine for Postpartum Docsy.
 * Implements the Notice -> Explain -> Act reasoning chain and AI transparency.
 */

import { env } from '../utils/env.js';
import { jsonLanguageInstruction } from '../utils/language.js';

export class DocsyPostpartumService {
  /**
   * Generates the dynamic daily briefing for the postpartum dashboard.
   * Leverages real Grok/OpenRouter AI with short timeout and robust clinical fallback.
   */
  static async generateDailyBrief({ timing, todayCheckin, yesterdayCheckin, priorities = [], safetyStatus, languageCode = 'en' }) {
    const fallback = this.generateHeuristicBrief({ timing, todayCheckin, yesterdayCheckin, priorities, safetyStatus });

    if (!env.grokApiKey) {
      return fallback;
    }

    try {
      const daysSinceBirth = timing?.daysSinceBirth ?? 0;
      const phaseName = timing?.phaseName ?? 'Immediate Recovery';
      const sleepHours = todayCheckin?.sleepHours ?? yesterdayCheckin?.sleepHours ?? null;
      const bleeding = todayCheckin?.bleedingLevel ?? yesterdayCheckin?.bleedingLevel ?? null;
      const mood = todayCheckin?.mood ?? null;
      const physicalComfort = todayCheckin?.physicalComfort ?? null;
      const energy = todayCheckin?.energy ?? null;
      const needRightNow = todayCheckin?.needRightNow ?? null;
      const todayFeels = todayCheckin?.todayFeels ?? null;

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 8000);

      const prompt = `You are Docsy, a compassionate, clinically grounded AI obstetric and postpartum companion for Blushy.
Mother's profile:
- Postpartum Day: ${daysSinceBirth} (${phaseName})
- Physical Status: ${physicalComfort || 'Not logged yet'}
- Emotional Status: ${mood || 'Not logged yet'}
- Energy Level: ${energy || 'Not logged yet'}
- Immediate Need Right Now: ${needRightNow || 'Not logged yet'}
- Today Feels: ${todayFeels || 'Not logged yet'}
- Lochia Bleeding Level: ${bleeding || 'Not logged yet'}
- Sleep: ${sleepHours !== null ? `${sleepHours} hours` : 'Not logged yet'}
- Active Clinical Priorities: ${priorities.map((p) => p.headline).join(', ')}

Return ONLY a JSON object with this EXACT structure (no markdown, no other keys):
{
  "openingGreeting": "Warm 1-2 sentence morning greeting tailored to her exact day, energy, sleep, and emotional recovery.",
  "recoveryPoint": "Concise 1-sentence maternal physical guidance based on her physical status, lochia, and immediate need.",
  "babyPoint": "Concise 1-sentence newborn rhythm or feeding support.",
  "noticePoint": "Concise 1-sentence physical sensation or signal to gently observe today.",
  "promptPills": ["4 personalized questions she might want to ask Docsy today"]
}${jsonLanguageInstruction(languageCode)}`;

      const res = await fetch(env.grokApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.grokApiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://blushy.app',
          'X-Title': 'Blushy Docsy Postpartum',
        },
        body: JSON.stringify({
          model: env.grokModel,
          messages: [
            { role: 'system', content: 'You are Docsy, a clinically grounded, low-cortisol postpartum AI assistant. Return JSON only.' },
            { role: 'user', content: prompt },
          ],
          response_format: { type: 'json_object' },
          temperature: 0.7,
          max_tokens: 350,
        }),
        signal: controller.signal,
      });
      clearTimeout(timeoutId);

      if (res.ok) {
        const aiJson = await res.json();
        const contentStr = aiJson.choices?.[0]?.message?.content;
        if (contentStr) {
          const parsed = JSON.parse(contentStr);
          if (parsed.openingGreeting && parsed.recoveryPoint) {
            return {
              openingGreeting: parsed.openingGreeting,
              recoveryPoint: parsed.recoveryPoint,
              babyPoint: parsed.babyPoint || fallback.babyPoint,
              noticePoint: parsed.noticePoint || fallback.noticePoint,
              promptPills: Array.isArray(parsed.promptPills) && parsed.promptPills.length > 0 ? parsed.promptPills : fallback.promptPills,
              transparency: fallback.transparency,
              priorities,
              safetyStatus,
              timestamp: new Date().toISOString(),
            };
          }
        }
      }
    } catch (err) {
      // Graceful clinical heuristic fallback if AI call times out or fails
    }

    return fallback;
  }

  /**
   * Dynamic clinical heuristic briefing.
   */
  static generateHeuristicBrief({ timing, todayCheckin, yesterdayCheckin, priorities = [], safetyStatus }) {
    const daysSinceBirth = timing?.daysSinceBirth ?? 0;
    const phaseName = timing?.phaseName ?? 'Immediate Recovery';
    const sleepHours = todayCheckin?.sleepHours ?? yesterdayCheckin?.sleepHours ?? null;
    const bleeding = todayCheckin?.bleedingLevel ?? yesterdayCheckin?.bleedingLevel ?? null;
    const mood = todayCheckin?.mood ?? null;
    const physicalComfort = todayCheckin?.physicalComfort ?? null;
    const energy = todayCheckin?.energy ?? null;
    const needRightNow = todayCheckin?.needRightNow ?? null;

    // Notice -> Explain -> Act Synthesis
    let openingGreeting = 'Good morning. Your body is navigating an extraordinary physiological transformation right now.';
    if (energy === 'flat out') {
      openingGreeting = 'Good morning. You are running on empty today. Give yourself absolute permission to cancel all non-essentials and lean horizontally.';
    } else if (needRightNow === 'someone to hold baby') {
      openingGreeting = 'Good morning. You mentioned needing someone to hold baby right now. Handing off baby to your support circle is protective of your healing.';
    } else if (needRightNow === 'a good cry' || mood === 'tearful') {
      openingGreeting = 'Good morning. Emotional tenderness and tears are normal physiological responses to hormonal shifts. Honor what you feel today.';
    } else if (daysSinceBirth > 0) {
      if (sleepHours && sleepHours <= 4) {
        openingGreeting = `Good morning. You logged ${sleepHours} hours of rest and your body is carrying cumulative fatigue. Let's keep today unhurried and simple.`;
      } else if (bleeding === 'heavy') {
        openingGreeting = 'Good morning. Your lochia bleeding remains active today. Your pelvic tissues need horizontal rest and nourishment.';
      } else if (daysSinceBirth <= 7) {
        openingGreeting = `Good morning on Day ${daysSinceBirth} of your 4th trimester. Your hormones and body are recalibrating hour by hour.`;
      } else {
        openingGreeting = `Good morning. Entering ${phaseName}. Let's check what your body and baby are asking for today.`;
      }
    }

    // Synthesis points
    let recoveryPoint = 'Rest and hydration matter more than any household agenda today.';
    if (needRightNow === 'pain relief' || physicalComfort === 'sore') {
      recoveryPoint = 'Tissue soreness is present today; keep ice packs, perineal spray, or scheduled analgesics within reach.';
    } else if (needRightNow === 'rest' || energy === 'flat out') {
      recoveryPoint = 'Horizontal healing is your #1 clinical priority today; keep gravity off your pelvic floor.';
    } else if (needRightNow === 'food / hydration') {
      recoveryPoint = 'Lactation and uterine remodeling demand 2.5–3L of electrolytes and warm nutrient-dense meals today.';
    } else if (daysSinceBirth <= 14) {
      recoveryPoint = 'Rest and horizontal healing take priority as your placental wound finishes active remodeling.';
    } else {
      recoveryPoint = 'Steady tissue healing continues; honor your gradual, gentle pace without rushing.';
    }

    const babyPoint = todayCheckin?.feedingMethod
      ? `Feeding rhythm is set to ${todayCheckin.feedingMethod}. Keep water and nursing supplies within arm's reach.`
      : 'Keep newborn rhythms intuitive. Feeding and skin-to-skin are your main focus.';

    const noticePoint = bleeding
      ? `Your bleeding is currently logged as ${bleeding}. Notice whether flow increases after walking or standing.`
      : 'Notice how your body responds when moving from lying down to standing today.';

    // Dynamic prompt pills tailored to current phase & symptoms
    const promptPills = [];
    if (daysSinceBirth <= 7) {
      promptPills.push('Is this bleeding normal?');
      promptPills.push('My stitches / incision hurt');
      promptPills.push("I'm exhausted");
      promptPills.push('Soothing sore nipples');
    } else if (daysSinceBirth <= 28) {
      promptPills.push('Baby blues vs PPD: what am I feeling?');
      promptPills.push('Can I exercise yet?');
      promptPills.push('When does lochia stop?');
      promptPills.push('Increasing milk supply');
    } else {
      promptPills.push('Safe core & pelvic floor return');
      promptPills.push('Preparing for 6-week postnatal check');
      promptPills.push('Can I drive or lift yet?');
      promptPills.push('Postpartum hair loss');
    }

    // "Why am I seeing this?" -- only things she actually gave us.
    //
    // The postpartum-day line was pushed unconditionally, and `daysSinceBirth`
    // falls back to 0 when no delivery date is set. So an account with nothing
    // logged and nothing calibrated was shown a single "signal" reading "You
    // are on Postpartum Day 0 (Not Calibrated)", under a summary claiming it
    // came from her logs. Three things wrong at once: nothing had been logged,
    // Day 0 asserts she gave birth today, and the absence of data was being
    // counted as evidence -- in the one panel whose whole job is to show the
    // working.
    const observedSignals = [];
    if (sleepHours !== null) observedSignals.push(`You logged ${sleepHours} hours of sleep`);
    if (bleeding) observedSignals.push(`Your lochia bleeding is currently ${bleeding}`);
    if (mood) observedSignals.push(`You reported feeling ${mood}`);
    if (physicalComfort) observedSignals.push(`Your physical status is ${physicalComfort}`);
    if (timing?.isConfigured) {
      observedSignals.push(`You are on Postpartum Day ${daysSinceBirth} (${phaseName})`);
    }

    const transparency = {
      title: 'Why is Docsy suggesting this?',
      summary: observedSignals.length === 0
        ? 'None of this comes from your own entries yet. Set your delivery date and log a check-in, and this panel will show exactly what it drew on.'
        : `I drew on ${observedSignals.length} thing${observedSignals.length === 1 ? '' : 's'} you have logged:`,
      signals: observedSignals,
      rationale: `Because tissue remodeling and hormonal shifts require prioritizing ${priorities.map((p) => p.category).join(', ')} rather than demanding high output today.`,
    };

    return {
      openingGreeting,
      recoveryPoint,
      babyPoint,
      noticePoint,
      promptPills,
      transparency,
      priorities,
      safetyStatus,
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Builds the system prompt for live Docsy conversations in the Postpartum stage.
   */
  static buildDocsyPromptContext({ timing, checkin, deliveryPath = 'vaginal' }) {
    return `
You are Docsy, the compassionate, clinically grounded AI companion in Blushy.
You are supporting a mother in her 4th Trimester (Postpartum Recovery).

CURRENT CLINICAL CONTEXT:
- Postpartum Day: ${timing?.daysSinceBirth ?? 'Unknown'} (Phase: ${timing?.phaseName ?? 'Early Recovery'})
- Delivery Path: ${deliveryPath}
- Today's Bleeding: ${checkin?.bleedingLevel ?? 'Not logged today'}
- Pain Score: ${checkin?.painScore ?? 'Not logged'}/10
- Sleep: ${checkin?.sleepHours ?? 'Unknown'} hours
- Emotional State: ${checkin?.mood ?? 'Not logged'}

CORE COMMUNICATION PRINCIPLES:
1. Maternal-First: Always validate the mother's body and emotional reality first before newborn advice.
2. Low-Cortisol & Reassuring: Never create anxiety with clinical jargon; be warm, deeply respectful, and calm.
3. Non-Diagnostic: Patterns over time are observations, not medical diagnoses. Never say "X causes Y".
4. Clinical Safety: Immediately escalate high fever (>100.4°F), heavy hemorrhage (soaking 1+ pad/hr), severe throbbing headaches with vision changes (preeclampsia), and acute emotional crisis to medical providers.
`.trim();
  }
}
