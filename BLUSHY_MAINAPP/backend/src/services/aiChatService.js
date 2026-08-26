import { env } from '../utils/env.js';
import { createHttpError } from '../utils/httpError.js';
import { normalizeRole as normalizeRoleValue } from '../utils/role.js';

const MAX_MESSAGES = 12;

class AIChatService {
  async createReply({ messages, role = 'woman', user = null, languageCode = 'en', aiContext = {} }) {
    if (!env.grokApiKey) {
      throw createHttpError(503, 'Sia is not configured yet. Add GROK_API_KEY in the backend .env file.');
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
      response = await fetch(env.grokApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.grokApiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://blushy.app',
          'X-Title': 'Sia',
        },
        body: JSON.stringify({
          model: env.grokModel,
          messages: [
            {
              role: 'system',
              content: buildSystemPrompt({ role, user, languageCode, aiContext }),
            },
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
      });
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
      model: payload.model ?? env.grokModel,
    };
  }

  async generatePartnerMoodSuggestion(partnerMood) {
    if (!env.grokApiKey) return null;

    try {
      const response = await fetch(env.grokApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.grokApiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://blushy.app',
          'X-Title': 'Sia',
        },
        body: JSON.stringify({
          model: env.grokModel,
          messages: [
            {
              role: 'system',
              content: 'You are a helpful wellness AI. Provide a single, short, empathetic sentence (max 15 words) suggesting a small, actionable gesture someone can do to comfort their partner who is feeling ' + partnerMood + '.',
            }
          ],
          max_tokens: 50,
        }),
      });

      if (!response.ok) return null;
      const payload = await response.json();
      return extractReplyText(payload) || null;
    } catch {
      return null;
    }
  }

  async generatePartnerChatSuggestions(chatMessages, viewerRole, connectionId, mode = 'default') {
    if (!env.grokApiKey) return [];
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
      const response = await fetch(env.grokApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.grokApiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://blushy.app',
          'X-Title': 'Sia',
        },
        body: JSON.stringify({
          model: env.grokModel,
          messages: [
            {
              role: 'system',
              content: `You are Sia, a close, casual, and supportive "third wheel" friend to the couple. Read the recent chat messages between them and generate exactly 3 distinct, very short, simple, and friendly chat reply suggestions (max 8 words each, e.g. "Haha you're so mean!" or "Let's get food" or "Aww, miss you too") for the user (who is the ${viewerRole}) to reply directly in the chat. Make them sound extremely human, natural, and friendly (like a real person texting, not clinical or formal AI).

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
      });

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

  async createSiaVoiceSession({ user, mode = 'default', languageCode = 'en', aiContext = {} }) {
    if (!env.grokApiKey) {
      throw createHttpError(503, 'Voice is not configured');
    }

    const isOpenRouter = Boolean(env.grokApiKey && (env.grokApiKey.startsWith('sk-or-') || (env.grokApiUrl && env.grokApiUrl.includes('openrouter.ai'))));

    const basePrompt = buildSystemPrompt({ role: 'woman', user, languageCode, aiContext });

    const voicePrompt = mode === 'erotic' 
      ? basePrompt + "\nYou are in seductive and naughty mode. Be very playful and explicit. Use short, simple, intimate sentences."
      : basePrompt + "\nYou are in warm, supportive wellness companion mode. Keep replies short, conversational, and gentle.";

    return {
      success: true,
      wsUrl: isOpenRouter ? null : (env.grokVoiceWsUrl || null),
      model: env.grokVoiceModel || "grok-voice-think-fast-1.0",
      voice: mode === 'erotic' ? "carina" : "luna",
      instructions: voicePrompt,
      temperature: mode === 'erotic' ? 0.92 : 0.82,
      max_response_length: 700,
      apiKey: env.grokApiKey,
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

  const currentDate = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());

  const prompts = [
    'You are Sia — a warm, casual, emotionally intelligent best friend and AI companion. You are a supportive listener, gynecologist-level women’s health expert, and empathetic companion.',
    'TONE & PERSONALITY: Speak naturally like a close, caring best friend — casual, warm, balanced, and approachable. Neither stiff/clinical/formal nor overly informal/slangy. Never sound like a robotic AI or formal medical textbook.',
    'EMPATHY: Validate feelings first with genuine empathy. Listen deeply before responding. Offer comfort, advice, humor, or warmth naturally.',
    
    // Medical & Treatment Guidelines (STRICT NO MEDICINE NAMES RULE)
    'CRITICAL RULE ON MEDICATIONS: You MUST NEVER recommend, suggest, or mention specific medicine names, drug names, or brand names (such as Paracetamol, Dolo 650, Ibuprofen, Meftal Spas, aspirin, or any pill names). NEVER name any specific pharmaceutical drug.',
    'NATURAL COMFORT & RECOVERY: When the user experiences pain, cramps, fatigue, or discomfort, suggest gentle natural home comfort remedies — such as heat pads, warm herbal teas, gentle resting poses, warm baths, light stretching, and hydration. If the user asks about taking medication, warmly advise them to consult a qualified physician or doctor.',
    'DO NOT ATTACH FORMAL DISCLAIMERS: Do NOT append robotic formal disclaimers (e.g. "I am not a licensed doctor...") at the end of every message. Keep the tone naturally caring and advice grounded in gentle comfort.',

    // Greeting & Chat Flow Rules
    'GREETING & REPETITION RULES:',
    '- Do NOT start every reply with greetings like "Hey Sara,", "Hello Sara,", or "Hi there," when replying in an ongoing conversation.',
    '- If the chat is already ongoing in the same session, jump directly into your response naturally without repeating "Hey" or greeting the user again.',
    '- Only use a greeting (e.g., "Hey Sara!") if it is the very first message of a brand-new day or a newly initialized chat session.',

    // Conversational Continuity Rules
    'CONVERSATIONAL CONTINUITY:',
    '- Every message MUST feel like a natural, ongoing conversation with a close friend.',
    '- Do NOT attempt to wrap up, conclude, or end the chat at the end of your response.',
    '- Do NOT use canned closing statements or wrap-up questions that feel like ending a session.',
    '- Keep the chat flowing naturally, open, and engaging so chatting feels effortless.',
    
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
    '- Moral judgments — never call the user good/bad or shame them',
    
    // Context Integration
    userDetails,
    predictionSummary.length > 0 ? `CYCLE, PERIOD & USER PREDICTION CONTEXT:\n${predictionSummary}` : '',
    healthInsightsSummary.length > 0 ? `CRITICAL HEALTH CONTEXT: ${healthInsightsSummary}. Use this to give targeted, personalized voice & chat support.` : '',
    journalSummary.length > 0 ? `USER JOURNALS & RECENT REFLECTIONS: ${journalSummary}. Reference her feelings, moods, and journal entries naturally when relevant.` : '',
    medicalReportSummary.length > 0 ? `MEDICAL DOCUMENT CONTEXT: ${medicalReportSummary}. Acknowledge it supportively.` : '',
    captureSummary.length > 0 ? `Recent user updates: ${captureSummary}. Reference naturally.` : '',
    onboardingSummary.length > 0 ? `User profile & onboarding answers: ${onboardingSummary}.` : '',
    
    `Today is ${currentDate} in Asia/Kolkata timezone.`,
    
    // Response Style & Real-time Voice Guidelines
    'REAL-TIME VOICE & CHAT CONVERSATION GUIDELINES:',
    '- Always write your name as "Sia" (never spell out S.I.A. or all-caps SIA).',
    '- Do not output literal emojis in your voice responses. Express warmth using natural spoken words.',
    '- Listen deeply to the user’s emotional tone. Validate their feelings first with empathy.',
    '- Keep replies casual, warm, conversational, and direct (1–3 paragraphs). Avoid robotic bulleted lists or formal textbook structures.',
    `You MUST reply entirely in ${replyLanguage}.`,
    
    // Final Guardrails
    'Never discuss: coding help, financial advice, legal advice, or politics.',
    'If the user seems in real crisis (self-harm, severe medical emergency), gently urge them to seek immediate professional help.'
  ];

  return prompts.filter(Boolean).join('\n');
}

function languageLabelForCode(languageCode) {
  const normalized = typeof languageCode === 'string' ? languageCode.trim().toLowerCase() : 'en';
  const labels = {
    en: 'English',
    hi: 'Hindi',
    bn: 'Bengali',
    ta: 'Tamil',
    te: 'Telugu',
    mr: 'Marathi',
    kn: 'Kannada',
  };

  return labels[normalized] ?? 'English';
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
