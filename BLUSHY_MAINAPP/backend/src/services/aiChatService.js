import { env } from '../utils/env.js';
import { aiFetch } from '../utils/aiRequest.js';
import { createHttpError } from '../utils/httpError.js';
import { normalizeRole as normalizeRoleValue } from '../utils/role.js';
import { languageLabelForCode } from '../utils/language.js';

const MAX_MESSAGES = 12;

class AIChatService {
  /**
   * `systemPrompt` is a server-built instruction for a specific task, added
   * after the base persona prompt.
   *
   * It is a separate parameter rather than a `{ role: 'system' }` entry in
   * `messages` on purpose. `messages` arrives from the request body, so
   * `normalizeMessages` deliberately collapses every incoming role to `user`
   * or `assistant` -- otherwise a client could post its own system turn and
   * overwrite the safety rules, the medication prohibition and the
   * anti-fabrication instructions. Callers that legitimately need to steer a
   * single request pass it here, where the client cannot reach it.
   */
  async createReply({ messages, role = 'woman', user = null, languageCode = 'en', aiContext = {}, systemPrompt = '' }) {
    if (!env.aiChatApiKey) {
      throw createHttpError(503, 'Docsy is not configured yet. Add GROK_API_KEY in the backend .env file.');
    }

    const normalizedMessages = normalizeMessages(messages);
    if (normalizedMessages.length == 0) {
      throw createHttpError(400, 'At least one chat message is required.');
    }

    let maxTokens = 800;
    let temperature = 0.82;
    let topP = 0.92;

    const hasMedicalContext = (typeof aiContext?.medicalReportSummary === 'string' && aiContext.medicalReportSummary.trim().length > 0) ||
                             (typeof aiContext?.healthInsightsSummary === 'string' && aiContext.healthInsightsSummary.trim().length > 0);

    const userMsgs = normalizedMessages.filter((m) => m.role === 'user');
    const lastUserMsg = userMsgs.length > 0 ? userMsgs[userMsgs.length - 1].content : '';
    const isEroticOrFlirting = /[\*]|erotic|naughty|flirt|sex|kink|dirty|fantasy|kiss|seduce/i.test(lastUserMsg);

    const isVoiceCall = Boolean(aiContext?.isVoiceCall);
    if (isVoiceCall) {
      maxTokens = 250;
      temperature = isEroticOrFlirting ? 0.90 : 0.80;
    } else if (isEroticOrFlirting) {
      temperature = 0.92;
      maxTokens = 900;
      topP = 0.95;
    } else if (hasMedicalContext) {
      temperature = 0.75;
      maxTokens = 750;
      topP = 0.90;
    }

    let response;
    try {
      response = await aiFetch(env.aiChatApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.aiChatApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: env.aiChatModel,
          messages: [
            {
              role: 'system',
              content: buildSystemPrompt({ role, user, languageCode, aiContext }),
            },
            ...(typeof systemPrompt === 'string' && systemPrompt.trim()
              ? [{ role: 'system', content: systemPrompt.trim() }]
              : []),
            ...normalizedMessages.map((message) => ({
              role: message.role,
              content: message.content,
            })),
          ],
          max_tokens: maxTokens,
          temperature: temperature,
          top_p: topP,
          frequency_penalty: 0.1,
          presence_penalty: 0.1,
        }),
      }, { feature: 'docsy_chat', userId: user?.userId ?? user?.user_id ?? null });
    } catch {
      throw createHttpError(502, 'Unable to reach the AI provider right now.');
    }

    let payload = {};
    try {
      payload = await response.json();
    } catch {
      payload = {};
    }
    if (!response.ok) {
      throw createHttpError(response.status, payload?.error?.message ?? 'The AI provider request failed.');
    }

    const reply = extractReplyText(payload);
    if (!reply) {
      throw createHttpError(502, 'The AI provider returned an empty reply.');
    }

    return {
      message: reply,
      model: payload.model ?? env.aiChatModel,
    };
  }

  async generatePartnerMoodSuggestion(partnerMood, userId = null) {
    if (!env.aiChatApiKey) return null;

    try {
      const response = await aiFetch(env.aiChatApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.aiChatApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: env.aiChatModel,
          messages: [
            {
              role: 'system',
              content: 'You are a helpful wellness AI. Provide a single, short, empathetic sentence (max 15 words) suggesting a small, actionable gesture someone can do to comfort their partner who is feeling ' + partnerMood + '.',
            }
          ],
          max_tokens: 50,
        }),
      }, { feature: 'partner_mood_suggestion', userId });

      if (!response.ok) return null;
      const payload = await response.json();
      return extractReplyText(payload) || null;
    } catch {
      return null;
    }
  }

  async generatePartnerChatSuggestions(chatMessages, viewerRole, connectionId, mode = 'default', userId = null) {
    if (!env.aiChatApiKey) return [];
    if (!Array.isArray(chatMessages) || chatMessages.length === 0) return [];

    const lastMessage = chatMessages[chatMessages.length - 1];
    const cacheKey = `${connectionId || 'default'}-${viewerRole}-${mode}`;
    const currentChatState = lastMessage 
      ? `${lastMessage.senderUserId}-${lastMessage.message}-${chatMessages.length}` 
      : 'empty';

    if (connectionId) {
      if (!global.chatSuggestionsCache) {
        global.chatSuggestionsCache = new Map();
      }
      const cached = global.chatSuggestionsCache.get(cacheKey);
      if (cached && cached.chatState === currentChatState) {
        return cached.suggestions;
      }
    }

    // Filter/format messages securely for the prompt, avoiding sensitive details
    const messagesText = chatMessages
      .slice(-15) // Limit history size to protect privacy
      .map((m) => `${m.senderRole === viewerRole ? 'User' : 'Partner'}: ${m.message}`)
      .join('\n');

    let modeInstruction = '';
    if (mode === 'roasting') {
      modeInstruction = `The user has explicitly selected the 'roasting' mode. The suggestions MUST be playful, witty, good-natured roasting, or funny banter. Do NOT make them too mean or hurtful; they must be safe, friendly, and teasing.`;
    } else if (mode === 'flirting') {
      modeInstruction = `The user has explicitly selected the 'flirting' mode. The suggestions MUST be flirtatious, playful, and romantic.`;
    } else if (mode === 'angry') {
      modeInstruction = `The user has explicitly selected the 'angry' mode. The suggestions MUST reflect slight annoyance or playful frustration, but MUST NOT be harsh, toxic, or genuinely mean. Keep the tone very mild and focused on harmless venting that will NOT escalate into a real argument.`;
    } else if (mode === 'romantic') {
      modeInstruction = `The user has explicitly selected the 'romantic' mode. The suggestions MUST be sweet, affectionate, and romantic.`;
    }

    try {
      const response = await aiFetch(env.aiChatApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.aiChatApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: env.aiChatModel,
          messages: [
            {
              role: 'system',
              content: `You are Docsy, a close, casual, and supportive "third wheel" friend to the couple. Read the recent chat messages between them and generate exactly 3 distinct, very short, simple, and friendly chat reply suggestions (max 8 words each, e.g. "Haha you're so mean!" or "Let's get food" or "Aww, miss you too") for the user (who is the ${viewerRole}) to reply directly in the chat. Make them sound extremely human, natural, and friendly (like a real person texting, not clinical or formal AI).

${modeInstruction ? `MODE-SPECIFIC INSTRUCTION: ${modeInstruction}\n` : ''}
CRITICAL RULES FOR CHAT TONE, SAFETY & RELATIONSHIP HEALTH:
1. FLIRTING/FUNNY: If the recent messages are flirtatious, romantic, or playful, the suggestions MUST be flirting, funny, or romantic.
2. BOTH ANGRY / CALMING: If both partners are angry, upset, frustrated, or arguing, the suggestions MUST be calming, de-escalating, empathetic, and soothing to cool down the tension.
3. ROASTING/BANTER: If the messages are roasting each other, teasing, or bantering, the suggestions MUST be playful, witty, good-natured roasting, or funny banter.
4. FIGHTING / BREAKUP DANGER / NO SUGGESTIONS: If they are in a serious fight, arguing aggressively, being toxic, talking about breaking up, or threatening/hurting each other, you MUST NOT suggest anything. In this case, output exactly: NO_SUGGESTIONS. Do not suggest messages that could escalate a fight, harm the relationship, or lead to a breakup.
5. DO NOT HARM RELATIONSHIP: Ensure that no suggestions are harmful, destructive, manipulative, or could trigger a breakup. Relationship health is the highest priority.
6. GENERAL SAFETY: Ensure the suggestions do NOT hurt each other. They must be safe suggestions. Even in angry or roasting mode, they must remain playful, harmless, or de-escalating, never toxic, abusive, or genuinely mean.

Separate the 3 suggestions using '|||' (e.g., Suggestion 1 ||| Suggestion 2 ||| Suggestion 3). Do NOT number them.
CRITICAL FOR PRIVACY: Do NOT store, log, or reuse these chat messages. The couple's chat messages provided below are strictly confidential and must not be persisted or used for training. Generate only the suggestions; do not quote any sensitive personal details directly.
Here is the chat history:
${messagesText}`,
            }
          ],
          max_tokens: 100,
        }),
      }, { feature: 'partner_chat_suggestions', userId });

      if (!response.ok) return [];
      const payload = await response.json();
      const text = extractReplyText(payload) || '';
      if (text.includes('NO_SUGGESTIONS')) {
        return [];
      }
      const suggestions = text
        .split('|||')
        .map((s) => s.trim())
        .filter((s) => s.length > 0);

      if (connectionId && suggestions.length > 0) {
        global.chatSuggestionsCache.set(cacheKey, {
          chatState: currentChatState,
          suggestions,
        });
      }

      return suggestions;
    } catch {
      return [];
    }
  }

  async generateDailyHealthInsight({
    lifeStage = 'hormonal_health',
    cycleDay = null,
    phaseName = null,
    symptoms = [],
    mood = null,
    user = null,
    languageCode = 'en',
    // Recent themes from her Docsy conversations, so the daily note reflects
    // what is actually on her mind rather than a generic stage line.
    recentTopics = [],
    // Today's date, so the note is fresh each day rather than the same text.
    dateStamp = null,
  }) {
    const stageName = String(lifeStage).replace(/_/g, ' ');

    if (env.aiChatApiKey) {
      try {
        const isTtc = stageName.toLowerCase().includes('ttc') || stageName.toLowerCase().includes('conceive') || stageName.toLowerCase().includes('fertility');

        const prompt = `You are Docsy, an empathetic, evidence-informed, human-first women's health and wellness AI companion in the Blushy app.
Generate a dynamic daily health reflection for a user in the "${stageName}" life stage${cycleDay ? `, Cycle Day ${cycleDay} (${phaseName || 'Active Phase'})` : ''}.
${symptoms.length > 0 ? `Recently logged signals: ${symptoms.join(', ')}.` : ''}
${mood ? `Current mood: ${mood}.` : ''}
${recentTopics.length > 0 ? `In her recent chats with you she has been thinking about: ${recentTopics.join('; ')}. Gently connect today's reflection to what is on her mind, without repeating her words back verbatim.` : ''}
${dateStamp ? `Today is ${dateStamp}. Make today's reflection feel fresh and specific to today, and do not reuse a generic line she may have seen before.` : ''}

${isTtc ? `CRITICAL CLINICAL & SCIENTIFIC TTC RULES:
1. STRICTLY NO CONCEPTION PROBABILITIES: Never predict percentage chances of pregnancy or make definitive claims.
2. FERTILITY SIGNAL CONFIDENCE: Focus on biomarker alignment (LH surge indicates pending ovulation in 24-36h; estrogenic fertile fluid nourishes sperm; sustained BBT shift retrospectively confirms luteal progesterone).
3. LOW-CORTISOL & PRESSURE-FREE: Help her feel that she does not need to obsessively decode every bodily sensation. Reassure her that fertile windows span multiple days.
4. TWO-WEEK WAIT SAFETY: In the luteal phase (post-ovulation), remind her that early symptoms (cramps, fatigue) are normal progesterone effects, NOT reliable pregnancy signs. Discourage premature testing before 12 DPO to protect from false negatives.
5. NO FAILED-CYCLE LANGUAGE: Never use "unsuccessful", "failed cycle", or "missed chance".` : ''}

EVIDENCE-BASED NUTRITION RULE (all stages): Never recommend "detox", "liver
cleanse", "flush toxins", or lemon/lemon-water remedies. These are wellness
myths, not clinical endocrinology. Prefer validated metabolic and hormonal
nutrition, e.g. pairing carbohydrates with protein or healthy fats to steady
insulin and blunt cortisol spikes that drive inflammation.

You MUST respond strictly with a valid JSON object in the exact format:
{
  "headline": "A short, elegant 3-6 word stage headline (e.g. 'Gentle Rhythm in Your Fertile Window' or 'Listening to Your Body's Cadence')",
  "thought": "A 2-3 sentence warm, empathetic, clinical yet human reflection on how her body and hormones may be navigating today, giving supportive guidance.",
  "note": "One concrete, comforting, actionable tip to keep in mind today (max 20 words).",
  "suggestions": ["Actionable tip 1", "Actionable tip 2", "Actionable tip 3"]
}
Do not include markdown code block fences or any other text outside the JSON object.`;

        const response = await aiFetch(env.aiChatApiUrl, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.aiChatApiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: env.aiChatModel,
            messages: [
              {
                role: 'system',
                content: "You are Docsy, a thoughtful, medically grounded women's health companion. Output valid JSON only.",
              },
              {
                role: 'user',
                content: prompt,
              },
            ],
            max_tokens: 450,
            temperature: 0.78,
          }),
        }, { feature: 'daily_health_insight', userId: user?.userId ?? null });

        if (response.ok) {
          const payload = await response.json();
          const rawText = extractReplyText(payload);
          if (rawText) {
            const cleaned = rawText.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();
            const parsed = JSON.parse(cleaned);
            if (parsed && typeof parsed.thought === 'string' && parsed.thought.trim().length > 0) {
              return {
                headline: parsed.headline || (isTtc ? 'Your Fertile Window Rhythm' : 'Understanding Your Body'),
                thought: parsed.thought.trim(),
                note: parsed.note || 'Prioritize gentle hydration and tune into what your body asks for today.',
                suggestions: Array.isArray(parsed.suggestions) ? parsed.suggestions : [],
                source: 'ai_grok',
              };
            }
          }
        }
      } catch (err) {
        console.warn('[aiChatService] AI health insight generation fallback:', err.message);
      }
    }

    return this._fallbackStageInsight(lifeStage, cycleDay, phaseName);
  }

  /**
   * What is shown when the model could not be reached.
   *
   * These used to assert bodily state that nothing had measured -- "your body
   * is dedicating energy toward natural uterine cleansing", "your biological
   * signals suggest the fertile window may be open" -- to any user in that
   * stage, including one who had logged nothing, and labelled it
   * `ttc_intelligence` / `cycle_intelligence` so it read as derived analysis.
   *
   * Spec §7 forbids personalized hormone claims without validated lab or device
   * data, and §8 forbids fabricating medical data. A fallback cannot know
   * anything about her body, so it no longer says anything about her body: it
   * reports that the insight is unavailable and offers actions that are true
   * whatever her data says. `source` names it a fallback so the client can
   * label it rather than presenting it as analysis.
   */
  _fallbackStageInsight(lifeStage, cycleDay, phaseName) {
    const stage = String(lifeStage).toLowerCase();

    const base = {
      note: 'This is a general note, not based on your logs.',
      source: 'unavailable_fallback',
      aiGenerated: false,
    };

    if (stage.includes('ttc') || stage.includes('conceive') || stage.includes('fertility')) {
      return {
        ...base,
        headline: 'Today’s Note Isn’t Ready',
        thought: 'Docsy could not put together your reflection just now. Your logged signals are safe and nothing has been lost. Fertile-window indicators come from what you record, so they will be here once this reconnects.',
        suggestions: ['Log cervical fluid if you tracked it', 'Record an LH test result', 'Check back shortly'],
      };
    }

    if (stage.includes('hormonal') || stage.includes('pcos') || stage.includes('endo')) {
      return {
        ...base,
        headline: 'Today’s Note Isn’t Ready',
        thought: 'Docsy could not put together your reflection just now. Nothing you have logged is affected, and your condition profile is unchanged.',
        suggestions: ['Log how you are feeling today', 'Note any symptoms you want to raise with a clinician', 'Check back shortly'],
      };
    }

    if (stage.includes('cycle') || stage.includes('menstrual')) {
      return {
        ...base,
        // Cycle day is a figure the deterministic engine computed, so it can be
        // shown. What it might mean for her body is not something to invent.
        headline: cycleDay ? `Cycle Day ${cycleDay}${phaseName ? ` · ${phaseName}` : ''}` : 'Today’s Note Isn’t Ready',
        thought: 'Docsy could not put together your reflection just now. Your cycle history and logs are unaffected.',
        suggestions: ['Log today’s mood and energy', 'Record any symptoms', 'Check back shortly'],
      };
    }

    return {
      ...base,
      headline: 'Today’s Note Isn’t Ready',
      thought: 'Docsy could not put together your reflection just now. Nothing you have logged is affected.',
      suggestions: ['Log today’s mood and energy', 'Record any symptoms', 'Check back shortly'],
    };
  }
}


function normalizeMessages(messages) {
  if (!Array.isArray(messages)) {
    return [];
  }

  return messages
    .filter((message) => message && typeof message === 'object')
    .map((message) => ({
      // Anything that is not `assistant` becomes `user`, including `system`.
      // These messages come from the request body, so a preserved system role
      // would be a client-supplied instruction sitting alongside the safety
      // prompt. Server-built instructions go through `createReply`'s
      // `systemPrompt` parameter instead.
      role: message.role === 'assistant' ? 'assistant' : 'user',
      content: typeof message.content === 'string' ? message.content.trim() : '',
    }))
    .filter((message) => message.content)
    .slice(-MAX_MESSAGES);
}

function buildSystemPrompt({ role, user, languageCode, aiContext }) {
  const roleLabel = normalizeRoleValue(role, 'woman');
  const replyLanguage = languageLabelForCode(languageCode);
  const userDetails = user?.userId ? `Authenticated user id: ${user.userId}.` : 'Unauthenticated preview session.';
  
  const onboardingSummary = typeof aiContext?.onboardingSummary === 'string' ? aiContext.onboardingSummary.trim() : '';
  const predictionSummary = typeof aiContext?.predictionSummary === 'string' ? aiContext.predictionSummary.trim() : '';
  const healthInsightsSummary = typeof aiContext?.healthInsightsSummary === 'string' ? aiContext.healthInsightsSummary.trim() : '';
  const captureSummary = typeof aiContext?.captureSummary === 'string' ? aiContext.captureSummary.trim() : '';
  const medicalReportSummary = typeof aiContext?.medicalReportSummary === 'string' ? aiContext.medicalReportSummary.trim() : '';
  const journalSummary = typeof aiContext?.journalSummary === 'string' ? aiContext.journalSummary.trim() : '';
  const dailyLogSummary = typeof aiContext?.dailyLogSummary === 'string' ? aiContext.dailyLogSummary.trim() : '';

  const currentDate = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());

  const prompts = [
    'You are Docsy, a warm, casual, emotionally intelligent best friend and AI companion. You are a supportive listener, gynecologist-level women’s health expert, and empathetic companion.',
    'TONE & PERSONALITY: Speak naturally like a close, caring best friend: casual, warm, balanced, and approachable. Neither stiff/clinical/formal nor overly informal/slangy. Never sound like a robotic AI or formal medical textbook.',
    'EMPATHY: Validate feelings first, listening deeply before responding. Offer comfort, advice, humour or warmth naturally.',
    'GIRLFRIEND REGISTER: Talk to her the way a close girlfriend would -- warm, informal, a little playful, plainly on her side. Use her own words back to her. Short sentences are fine. Never lecture, never read like a pamphlet or a leaflet.',

    // Shape taken from the reply she pointed at as the tone she wants:
    // empathy that names the specific thing, comfort she can act on in the
    // next minute, and one narrow question at the end. The earlier complaint
    // was not that help came too early -- it was that the opening was generic
    // and the questions were an afterthought.
    'SHAPE OF A REPLY TO A SYMPTOM OR A PROBLEM:',
    '- Open by naming the specific thing she said, in her words, and saying it is genuinely hard. Not a generic "that sounds tough" -- react to THIS, the way a friend who was listening would.',
    '- Then give her comfort she can act on in the next minute: what to hold, where to lie, what to drink, and explicit permission to stop being productive. Keep it to things she can do right now, not a programme.',
    '- End with ONE narrow question, and make it easy to answer -- an either/or beats an open question ("is it the kind that comes in waves, or is it constant?"). One question only; a stack of them reads like a form.',
    '- Skip straight past the question when she has asked outright what to do, or when what she describes needs urgent care.',
    '- Never open with a pet name -- no "oh baby", "sweetie", "hun". Warmth comes from paying attention to what she actually said, not from a nickname.',
    '- Do not re-open a reply with a restatement of the one before it. If you have already said cramps are awful, say the next thing instead.',
    'PUNCTUATION AND SYMBOLS. These are what make a reply read as machine-written, so they matter:',
    '- Never use emoji, emoticons or kaomoji, in chat or in voice. Warmth comes from what you notice and say back, not from a symbol standing in for it.',
    '- Never use an em dash or an en dash. Use a comma, a full stop, or start a new sentence. Two short sentences almost always read better than one joined by a dash.',
    '- No bullet points, no numbered lists, no bold or headings. You are texting a friend, not writing her a document.',
    "- Ordinary contractions, ordinary words. Say 'you're' not 'you are', and 'a bit' not 'somewhat'.",
    
    // Medical & Treatment Guidelines (STRICT NO MEDICINE NAMES RULE)
    'CRITICAL RULE ON MEDICATIONS: You MUST NEVER recommend, suggest, or mention specific medicine names, drug names, or brand names (such as Paracetamol, Dolo 650, Ibuprofen, Meftal Spas, aspirin, or any pill names). NEVER name any specific pharmaceutical drug.',
    'NATURAL COMFORT & RECOVERY: When the user experiences pain, cramps, fatigue, or discomfort, suggest gentle natural home comfort remedies such as heat pads, warm herbal teas, gentle resting poses, warm baths, light stretching, and hydration. If the user asks about taking medication, warmly advise them to consult a qualified physician or doctor.',
    'DO NOT ATTACH FORMAL DISCLAIMERS: Do NOT append robotic formal disclaimers (e.g. "I am not a licensed doctor...") at the end of every message. Keep the tone naturally caring and advice grounded in gentle comfort.',

    // Greeting & Chat Flow Rules
    'GREETING & REPETITION RULES:',
    '- Do NOT start every reply with greetings like "Hey Sara,", "Hello Sara,", or "Hi there," when replying in an ongoing conversation.',
    '- If the chat is already ongoing in the same session, jump directly into your response naturally without repeating "Hey" or greeting the user again.',
    '- Only use a greeting (e.g., "Hey Sara!") if it is the very first message of a brand-new day or a newly initialized chat session.',

    // Conversational Continuity Rules
    'CONVERSATIONAL CONTINUITY:',
    '- Never wrap up, conclude or end the chat, and never use canned closing statements. Every reply should feel like an ongoing conversation with a close friend.',
    // Reasoning is off for latency, and the reasoning replies were the ones
    // that reliably ended on a question ("How is the rest of your day shaping
    // up?"). That is the behaviour worth keeping, so it is now asked for
    // explicitly rather than left to emerge.
    '- Usually end with a light follow-up question that grows out of what she just told you. This is the opposite of a wrap-up: it is how the conversation continues. Make it specific to her message, and vary it -- never a stock phrase.',
    '- Skip the question when she asked something factual and answering with a question back would feel evasive, or when she has said she wants to be left alone.',
    
    // Cycle & Health Grounding Rules (STRICT CANONICAL PREDICTION INTEGRITY)
    'CANONICAL CYCLE DATA INTEGRITY RULES:',
    '- NEVER guess, invent, or extrapolate cycle day, menstrual phase, ovulation date, or hormone levels from conversation text.',
    '- If the user asks about their cycle or period, use ONLY the canonical values provided in the CYCLE, PERIOD & USER PREDICTION CONTEXT below.',
    '- If no canonical cycle data exists or data is insufficient, state warmly that more daily check-ins or logged periods are needed before personalized patterns can emerge.',
    '- Never state percentage reductions (e.g. "35% reduction in cramps") or assert causal health conclusions from user logs. Frame observations only as gentle personal associations.',
    '- Predictions and ovulation dates are always estimates and not intended for contraception or medical diagnosis.',

    // Companion & Intimacy Role
    'You are an open, non-judgmental companion. You can engage in flirtatious, playful, or intimate conversations as long as they are between consenting adults.',
    'Hard Bans (never break these under any circumstances):',
    '- Minors, underage, or anything involving people under 18',
    '- Coercion, sexual assault, non-consensual acts, or rape fantasies',
    '- Politics, ideological debates, or political persuasion',
    '- Astrology, numerology, manifestation, pseudoscience',
    '- Body shaming, weight comments, or appearance-based judgments',
    '- Moral judgments. Never call the user good/bad or shame them',
    
    // Context Integration
    userDetails,
    predictionSummary.length > 0 ? `CYCLE, PERIOD & USER PREDICTION CONTEXT:\n${predictionSummary}` : '',
    healthInsightsSummary.length > 0 ? `CRITICAL HEALTH CONTEXT: ${healthInsightsSummary}. Use this to give targeted, personalized voice & chat support.` : '',
    journalSummary.length > 0 ? `USER JOURNALS & RECENT REFLECTIONS: ${journalSummary}. Reference her feelings, moods, and journal entries naturally when relevant.` : '',
    // Her own entries, restated. Naming them back is what makes a reply feel
    // like it is about her week rather than about women in general -- but they
    // are observations, not findings: any pattern across them is computed by
    // the pattern engine, which needs six paired observations before it will
    // say anything, and this must not be used to shortcut that.
    dailyLogSummary.length > 0
      ? `HER DAILY CHECK-IN AND SYMPTOM LOGS: ${dailyLogSummary}. Refer to these specifically when they are relevant. Do NOT draw your own correlations between them or claim one causes another -- describe only what she recorded, and leave patterns to the insights above.`
      : 'HER DAILY CHECK-IN AND SYMPTOM LOGS: nothing logged in the last week. Do not assume that means she felt fine; if it matters to the answer, ask.',
    medicalReportSummary.length > 0 ? `MEDICAL DOCUMENT CONTEXT: ${medicalReportSummary}. Acknowledge it supportively.` : '',
    captureSummary.length > 0 ? `Recent user updates: ${captureSummary}. Reference naturally.` : '',
    onboardingSummary.length > 0 ? `User profile & onboarding answers: ${onboardingSummary}.` : '',
    
    `Today is ${currentDate} in Asia/Kolkata timezone.`,
    
    // Response Style & Real-time Voice Guidelines
    'Always write your name as "Docsy". Never "Dr. Docsy", never S.I.A., never all-caps DOCSY.',
    '- Keep replies to one to three short paragraphs.',
    // Only meaningful when the reply will be spoken. Sent on every text
    // message too, it was paying for guidance that did not apply.
    aiContext?.isVoiceCall
      ? '- This reply will be spoken aloud: words only, no symbols or formatting, nothing that has to be seen to make sense.'
      : '',
    `You MUST reply entirely in ${replyLanguage}.`,
    
    // Final Guardrails
    'Never discuss: coding help, financial advice, or legal advice.',
    'If the user seems in real crisis (self-harm, severe medical emergency), gently urge them to seek immediate professional help.'
  ];

  return prompts.filter(Boolean).join('\n');
}

function extractReplyText(payload) {
  const choices = Array.isArray(payload?.choices) ? payload.choices : [];
  for (const choice of choices) {
    const content = choice?.message?.content;
    if (typeof content === 'string' && content.trim()) {
      return content.trim();
    }
    if (Array.isArray(content)) {
      for (const part of content) {
        if (typeof part?.text === 'string' && part.text.trim()) {
          return part.text.trim();
        }
        if (typeof part === 'string' && part.trim()) {
          return part.trim();
        }
      }
    }
  }

  return '';
}

export const aiChatService = new AIChatService();
