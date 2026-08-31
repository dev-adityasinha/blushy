import { userRepository } from '../repositories/userRepository.js';
import { dailyMoodRepository } from '../repositories/dailyMoodRepository.js';
import { sleepRepository } from '../repositories/sleepRepository.js';
import { partnerRepository } from '../repositories/partnerRepository.js';
import { env } from '../utils/env.js';
import { aiFetch } from '../utils/aiRequest.js';
import { normalizePermissions, hasGrant } from '../domain/partnerPermissions.js';
import { createHttpError } from '../utils/httpError.js';

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

function fallbackDecoder({ messageText, cyclePhase, mood, energyLevel, sleepHours, partnerName }) {
  const text = (messageText || '').trim().toLowerCase();
  let decodedMeaning = `She is reaching out to connect with you. Her message reflects her current emotional rhythm.`;
  let emotionalTone = 'Neutral / Reaching Out';
  let recommendedReply = `Hey love, I'm thinking of you! How is your day going?`;
  let actionTip = `Send a warm, affectionate note or ask if there's anything she needs today.`;

  // 1. Brief / One-word answers (e.g. "k", "fine", "ok", "nothing", "nm")
  if (/^(fine|ok|okay|k|nothing|nm|whatever|idk|nothing much)$/i.test(text) || (text.length <= 4 && /fine|ok|k/i.test(text))) {
    if (cyclePhase === 'Luteal phase' || mood === 'irritated' || mood === 'anxious') {
      decodedMeaning = `Her short response likely means she is feeling low on mental energy or emotionally overwhelmed right now, rather than being cold.`;
      emotionalTone = 'Low Battery / Emotionally Overwhelmed';
      recommendedReply = `I hear you love. You don't have to explain anything right now, I'm just sending you a big warm hug. I'm here whenever you need me.`;
      actionTip = `Do not push for an immediate conversation. Offer peaceful space and a small thoughtful gesture like food or water.`;
    } else {
      decodedMeaning = `She might be preoccupied or in the middle of something, keeping her response concise.`;
      emotionalTone = 'Busy / Distracted';
      recommendedReply = `Got it love! Take your time, let me know when you're free to catch up ❤️`;
      actionTip = `Give her time to wrap up whatever she's doing and check in later tonight.`;
    }
  }
  // 2. Tired / Exhausted
  else if (/tired|exhausted|sleepy|drained|burnout|headache|cramps|pain|hurts/.test(text)) {
    decodedMeaning = `She is experiencing physical or emotional exhaustion. She wants you to know she has low capacity and would appreciate nurturing support.`;
    emotionalTone = 'Fatigued / In Need of Comfort';
    recommendedReply = `I'm so sorry you're feeling this way love. Please rest up, I'll take care of dinner and anything else you need tonight.`;
    actionTip = `Bring a heating pad, warm tea, or handle an evening chore so she can rest guilt-free.`;
  }
  // 3. Asking questions ("What are you doing?", "Are you free?", "How are you?")
  else if (/what are you doing|are you free|how are you|where are you|busy\?/.test(text)) {
    decodedMeaning = `She is seeking your presence, attention, and a moment of shared intimacy or reassurance.`;
    emotionalTone = 'Seeking Connection / Affection';
    recommendedReply = `I was just thinking about you! Always free for you. How are you feeling right now sweetheart?`;
    actionTip = `Give her your full undivided attention and show enthusiasm in your response.`;
  }
  // 4. Emotional / Stressed ("I can't anymore", "Everything is annoying", "I'm stressed")
  else if (/stress|annoyed|mad|sad|crying|upset|hate this|can't deal|overwhelmed/.test(text)) {
    decodedMeaning = `Her stress bucket is full. She is not blaming you; she is venting to her safe person and needs validation rather than quick problem-solving.`;
    emotionalTone = 'High Stress / Vulnerable';
    recommendedReply = `That sounds really exhausting, and you have every right to feel that way. I'm right by your side, what can I take off your plate today?`;
    actionTip = `Listen and validate first before offering solutions. Validate her feelings with empathy.`;
  }
  // 5. Playful / Affectionate / Happy ("love you", "miss you", "hehe", "can't wait")
  else if (/love you|miss you|cutie|babe|sweet|happy|excited|yay|can't wait/.test(text)) {
    decodedMeaning = `She is feeling warm, connected, and appreciative of you. She wants to celebrate your bond.`;
    emotionalTone = 'Affectionate / Happy';
    recommendedReply = `I love you more! Seeing your text made my whole day brighter 🥰`;
    actionTip = `Match her enthusiastic energy and send a sweet compliment or voice note.`;
  }

  const cycleContextParts = [];
  if (cyclePhase) cycleContextParts.push(`${cyclePhase}`);
  if (mood) cycleContextParts.push(`Logged mood: ${mood}`);
  if (sleepHours !== null && sleepHours !== undefined) cycleContextParts.push(`${sleepHours} hrs sleep`);

  return {
    decodedMeaning,
    emotionalTone,
    // Empty when nothing was shared. This used to read "Standard Wellness
    // Rhythm", which sounds like a reading taken from her data rather than the
    // absence of any.
    cycleMoodContext: cycleContextParts.join(' • '),
    recommendedReply,
    actionTip,
  };
}

export async function decodePartnerMessage({
  messageText,
  connectionId,
  partnerUserId,
  viewerUserId,
}) {
  const connection = await partnerRepository.getConnectionForUser(connectionId, viewerUserId);
  if (!connection) {
    // A plain Error surfaced as a 500, which reads as a server fault rather
    // than "you are not in this connection".
    throw createHttpError(404, 'Connection not found.');
  }

  const effectivePartnerId = partnerUserId || connection.partnerUserId;
  // The date is deliberately not computed here. Each repository defaults to
  // its own notion of "today" and writes rows under it -- and those notions
  // disagree: dailyMoodRepository uses Asia/Kolkata, sleepRepository uses UTC.
  // Passing a UTC date to both meant her mood was written under the IST date
  // and read back under the UTC one, so between 00:00 and 05:30 IST the
  // decoder silently found nothing and told him nothing had been shared.
  // Letting each repository answer for itself keeps every read on the same
  // calendar as the write it is looking for.
  const [partnerUser, todayMood, todaySleep] = await Promise.all([
    userRepository.getUserById(effectivePartnerId),
    dailyMoodRepository.getDailyMood(effectivePartnerId),
    sleepRepository.getSleepByDate(effectivePartnerId),
  ]);

  // Every signal below is gated on the permission that covers it, the same way
  // getPartnerSuggestions gates them. This read used to be ungated: it fetched
  // the partner's mood, sleep and cycle regardless of what they had agreed to
  // share, then printed them back to the other person in cycleMoodContext.
  // Normalised first: connections written under the v2 matrix store `mood`,
  // `sleep` and `cycle_insights`, so reading the legacy `shareMood` names gave
  // undefined and the decoder behaved as if nothing had ever been shared.
  const permissions = normalizePermissions(connection.permissions);

  const onboardingAnswers = hasGrant(permissions, 'insight.general')
    ? (partnerUser?.onboardingAnswers ?? {})
    : {};
  const partnerName = partnerUser?.display_name || partnerUser?.email?.split('@')[0] || 'She';

  // Null when unknown, never a guess. This defaulted to 'Follicular phase',
  // which was then stated as fact to the partner and fed to the model as
  // context -- producing confident advice built on a phase nobody reported.
  let cyclePhase = null;
  const cycleStart = hasGrant(permissions, 'cycle.phase')
    ? (partnerUser?.cycleStartDate ||
       onboardingAnswers?.period_last_start_date ||
       onboardingAnswers?.cycle_last_period_start ||
       onboardingAnswers?.last_period ||
       null)
    : null;

  if (cycleStart) {
    try {
      const start = new Date(cycleStart);
      const now = new Date();
      const diffDays = Math.floor((now.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) % 28;
      if (diffDays >= 0 && diffDays < 5) cyclePhase = 'Menstrual phase';
      else if (diffDays >= 5 && diffDays < 12) cyclePhase = 'Follicular phase';
      else if (diffDays >= 12 && diffDays < 16) cyclePhase = 'Ovulation phase';
      else cyclePhase = 'Luteal phase';
    } catch (_) {}
  }

  const mood = hasGrant(permissions, 'log.mood')
    ? (todayMood?.primaryMood || todayMood?.mood || null)
    : null;
  const energyLevel = hasGrant(permissions, 'log.mood')
    ? (todayMood?.energyLevel || (hasGrant(permissions, 'log.sleep') ? todaySleep?.energyLevel : null) || null)
    : null;
  const sleepHours = hasGrant(permissions, 'log.sleep') && todaySleep?.durationMinutes
    ? (Number(todaySleep.durationMinutes) / 60).toFixed(1)
    : null;

  // Attempt Grok / Dr. Docsy LLM call
  if (env.aiChatApiKey && env.aiChatApiUrl) {
    try {
      const prompt = `You are Dr. Docsy, an expert relationship wellness and empathy AI inside Blushy.
You are helping a man understand and decode what his romantic partner is communicating beneath the surface of her text message.

Context about her:
- Name: ${partnerName}
- Biological/Cycle Phase: ${cyclePhase ?? 'Not shared with him - do not refer to her cycle at all'}${cyclePhase ? ' (Note: Menstrual = cramping/low energy, Follicular = rising energy, Ovulation = high connection/creativity, Luteal = PMS/mood sensitivity/craving safety)' : ''}
- Today's Mood: ${mood ?? 'Not shared - do not guess it'}
- Energy Level: ${energyLevel ?? 'Not shared - do not guess it'}
- Recent Sleep: ${sleepHours ? `${sleepHours} hours` : 'Not shared - do not guess it'}

Only use the context above that was actually shared. Do not invent a cycle
phase, mood, energy level or sleep figure that is not listed, and do not imply
you know something about her that you were not told.

Her Message to him:
"${messageText}"

Please analyze this message with high emotional intelligence and provide a structured JSON response:
{
  "decodedMeaning": "A clear, empathetic 1-2 sentence explanation of what she is truly feeling and coming to tell him underneath her words.",
  "emotionalTone": "A 2-3 word summary of her emotional state (e.g., 'Overwhelmed & Tired', 'Seeking Affection', 'Quiet Reassurance')",
  "cycleMoodContext": "${cyclePhase || mood ? `A short summary of only the shared context (e.g., '${[cyclePhase, mood].filter(Boolean).join(' • ')}')` : 'Return an empty string, because nothing about her state was shared'}",
  "recommendedReply": "A warm, deeply supportive, natural reply he can send back to her.",
  "actionTip": "A practical 1-sentence tip on what thoughtful gesture or action he can do in real life right now."
}

Return ONLY raw valid JSON. Do not include markdown formatting or extra text.`;

      const response = await aiFetch(env.aiChatApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.aiChatApiKey}`,
          'Content-Type': 'application/json',
          'X-Title': 'Blushy Dr. Docsy Message Decoder',
        },
        body: JSON.stringify({
          model: env.aiChatModel || 'grok-beta',
          messages: [
            {
              role: 'system',
              content: 'You are Dr. Docsy, Blushy\'s relationship empathy decoder. Always return valid JSON with decodedMeaning, emotionalTone, cycleMoodContext, recommendedReply, and actionTip.',
            },
            {
              role: 'user',
              content: prompt,
            },
          ],
          temperature: 0.75,
          max_tokens: 500,
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const content = data?.choices?.[0]?.message?.content;
        const parsed = parseJsonSafely(content);
        if (parsed && parsed.decodedMeaning && parsed.recommendedReply) {
          return {
            decodedMeaning: parsed.decodedMeaning,
            emotionalTone: parsed.emotionalTone || 'Empathetic Connection',
            // Falls back to the shared signals only; empty when none were.
            cycleMoodContext: parsed.cycleMoodContext
              || [cyclePhase, mood].filter(Boolean).join(' • '),
            recommendedReply: parsed.recommendedReply,
            actionTip: parsed.actionTip || 'Show patience and offer proactive comfort.',
          };
        }
      }
    } catch (err) {
      console.error('Error during AI message decoding, falling back to heuristic:', err);
    }
  }

  // Fallback heuristic decoder
  return fallbackDecoder({
    messageText,
    cyclePhase,
    mood,
    energyLevel,
    sleepHours,
    partnerName,
  });
}
