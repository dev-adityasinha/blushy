import { aiChatService } from '../services/aiChatService.js';
import { aiHistoryRepository } from '../repositories/aiHistoryRepository.js';
import { profileMemoryRepository } from '../repositories/profileMemoryRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { journalRepository } from '../repositories/journalRepository.js';
import { profileMemoryService } from '../services/profileMemoryService.js';
import { userPredictionContextService } from '../services/userPredictionContextService.js';
import { healthInsightsService } from '../services/healthInsightsService.js';
import { sleepFromChatService } from '../services/sleepFromChatService.js';
import { cycleFromChatService } from '../services/cycleFromChatService.js';
import { moodFromChatService } from '../services/moodFromChatService.js';
import { medicationFromChatService } from '../services/medicationFromChatService.js';
import { onboardingFromChatService } from '../services/onboardingFromChatService.js';
import { onboardingAuditRepository } from '../repositories/onboardingAuditRepository.js';
import { createHttpError } from '../utils/httpError.js';
import { normalizeRole as normalizeRoleValue } from '../utils/role.js';
import { buildPartnerCareSuggestions, buildCycleInfo } from '../services/partnerSuggestionService.js';
import { partnerRepository } from '../repositories/partnerRepository.js';
import { db } from '../utils/db.js';
import { parseAndSaveMedicalReport } from '../services/medicalReportService.js';
import fs from 'node:fs';
import { env } from '../utils/env.js';

function getUserKey(req, role = 'woman') {
  const roleLabel = normalizeRoleValue(role, 'woman');
  const userId = req.user?.userId;
  if (userId) {
    return `user:${userId}`;
  }

  return `anonymous:${roleLabel}`;
}

function latestUserMessage(messages) {
  if (!Array.isArray(messages)) {
    return '';
  }

  for (let index = messages.length - 1; index >= 0; index -= 1) {
    const message = messages[index];
    if (message?.role === 'user' && typeof message?.content === 'string' && message.content.trim().length > 0) {
      return message.content.trim();
    }
  }

  return '';
}

function buildOnboardingSummary(answers) {
  if (!answers || typeof answers !== 'object' || Array.isArray(answers)) {
    return '';
  }

  const priorityKeys = [
    'preferred_name',
    'date_of_birth',
    'medication_currently_taking',
    'taking_any_medication',
    'medication_type',
    'taking_any_medication_type',
    'medication_consistency',
    'medication_cycle_impact',
  ];
  const seenKeys = new Set();
  const orderedEntries = [];

  for (const key of priorityKeys) {
    const value = answers[key];
    if (typeof value === 'string' && value.trim().length > 0) {
      orderedEntries.push([key, value]);
      seenKeys.add(key);
    }
  }

  for (const entry of Object.entries(answers)) {
    const [key, value] = entry;
    if (seenKeys.has(key)) {
      continue;
    }
    if (typeof key === 'string' && key.trim().length > 0 && typeof value === 'string' && value.trim().length > 0) {
      orderedEntries.push(entry);
    }
  }

  const parts = orderedEntries
    .filter(([key, value]) => typeof key === 'string' && key.trim().length > 0 && typeof value === 'string' && value.trim().length > 0)
    .slice(0, 12)
    .map(([key, value]) => `${key.trim()}: ${value.trim()}`);

  return parts.join(' | ');
}

function summarizeCapture(label, capture, formatter) {
  if (!capture?.updated) {
    return '';
  }

  const detail = typeof formatter === 'function' ? formatter(capture) : '';
  return detail ? `${label}: ${detail}` : label;
}

const TRANSLATIONS = {
  en: {
    medication_saved: 'Medication saved',
    taking: 'taking',
    details_updated: 'medication details updated',
    onboarding_saved: 'Onboarding saved',
    updated: 'updated',
    profile_details_updated: 'profile details updated',
    sleep_saved: 'Sleep saved',
    hours_for: 'hours for',
    cycle_saved: 'Cycle saved',
    period_start_on: 'period start on',
    mood_saved: 'Mood saved',
    mood_for: 'mood for',
    memory_saved: 'Memory saved',
    details_remembered: 'personal details remembered'
  },
  hi: {
    medication_saved: 'दवा सहेजी गई',
    taking: 'ले रहे हैं',
    details_updated: 'दवा का विवरण अपडेट किया गया',
    onboarding_saved: 'ऑनबोर्डिंग सहेजी गई',
    updated: 'अपडेट किया गया',
    profile_details_updated: 'प्रोफ़ाइल विवरण अपडेट किया गया',
    sleep_saved: 'नींद सहेजी गई',
    hours_for: 'घंटे',
    cycle_saved: 'चक्र सहेजा गया',
    period_start_on: 'मासिक धर्म शुरू होने की तारीख',
    mood_saved: 'मूड सहेजा गया',
    mood_for: 'के लिए मूड',
    memory_saved: 'यादें सहेजी गईं',
    details_remembered: 'व्यक्तिगत विवरण याद रखा गया'
  },
  bn: {
    medication_saved: 'ওষুধ সংরক্ষণ করা হয়েছে',
    taking: 'নিচ্ছেন',
    details_updated: 'ওষুধের বিবরণ আপডেট করা হয়েছে',
    onboarding_saved: 'অনবোর্ডিং সংরক্ষণ করা হয়েছে',
    updated: 'আপডেট করা হয়েছে',
    profile_details_updated: 'প্রোফাইল বিবরণ আপডেট করা হয়েছে',
    sleep_saved: 'ঘুম সংরক্ষণ করা হয়েছে',
    hours_for: 'ঘন্টা',
    cycle_saved: 'ঋতুচক্র সংরক্ষণ করা হয়েছে',
    period_start_on: 'পিরিয়ড শুরু হয়েছে',
    mood_saved: 'মনোভাব সংরক্ষণ করা হয়েছে',
    mood_for: 'এর জন্য মনোভাব',
    memory_saved: 'মেমরি সংরক্ষণ করা হয়েছে',
    details_remembered: 'ব্যক্তিগত বিবরণ মনে রাখা হয়েছে'
  },
  ta: {
    medication_saved: 'மருந்து சேமிக்கப்பட்டது',
    taking: 'எடுத்துக்கொள்கிறார்',
    details_updated: 'மருந்து விவரங்கள் புதுப்பிக்கப்பட்டன',
    onboarding_saved: 'விவரங்கள் சேமிக்கப்பட்டன',
    updated: 'புதுப்பிக்கப்பட்டது',
    profile_details_updated: 'சுயவிவர விவரங்கள் புதுப்பிக்கப்பட்டன',
    sleep_saved: 'தூக்கம் சேமிக்கப்பட்டது',
    hours_for: 'மணி நேரம்',
    cycle_saved: 'மாதவிடாய் சுழற்சி சேமிக்கப்பட்டது',
    period_start_on: 'மாதவிடாய் தொடங்கிய தேதி',
    mood_saved: 'மனநிலை சேமிக்கப்பட்டது',
    mood_for: 'மனநிலை',
    memory_saved: 'நினைவகம் சேமிக்கப்பட்டது',
    details_remembered: 'தனிப்பட்ட விவரங்கள் நினைவில் கொள்ளப்பட்டன'
  },
  te: {
    medication_saved: 'మందులు సేవ్ చేయబడ్డాయి',
    taking: 'తీసుకుంటున్నారు',
    details_updated: 'మందుల వివరాలు నవీకరించబడ్డాయి',
    onboarding_saved: 'ఆన్‌బోర్డింగ్ సేవ్ చేయబడింది',
    updated: 'నవీకరించబడింది',
    profile_details_updated: 'ప్రొఫైల్ వివరాలు నవీకరించబడ్డాయి',
    sleep_saved: 'నిద్ర సేవ్ చేయబడింది',
    hours_for: 'గంటలు',
    cycle_saved: 'చక్రం సేవ్ చేయబడింది',
    period_start_on: 'పీరియడ్ ప్రారంభ తేదీ',
    mood_saved: 'మూడ్ సేవ్ చేయబడింది',
    mood_for: 'మూడ్',
    memory_saved: 'జ్ఞాపకం సేవ్ చేయబడింది',
    details_remembered: 'వ్యక్తిగత వివరాలు గుర్తుంచుకోబడ్డాయి'
  },
  mr: {
    medication_saved: 'औषध जतन केले',
    taking: 'घेत आहे',
    details_updated: 'औषध तपशील अद्यतनित केले',
    onboarding_saved: 'ऑनबोर्डिंग जतन केले',
    updated: 'अद्यतनित केले',
    profile_details_updated: 'प्रोफाइल तपशील अद्यतनित केले',
    sleep_saved: 'झोप जतन केली',
    hours_for: 'तास',
    cycle_saved: 'मासिक पाळी चक्र जतन केले',
    period_start_on: 'मासिक पाळी सुरू झाल्याची तारीख',
    mood_saved: 'मनःस्थिती जतन केली',
    mood_for: 'साठी मनःस्थिती',
    memory_saved: 'स्मरणशक्ती जतन केली',
    details_remembered: 'वैयक्तिक तपशील लक्षात ठेवले'
  },
  kn: {
    medication_saved: 'ಔಷಧಿ ಉಳಿಸಲಾಗಿದೆ',
    taking: 'ತೆಗೆದುಕೊಳ್ಳುತ್ತಿದ್ದಾರೆ',
    details_updated: 'ಔಷಧಿ ವಿವರಗಳನ್ನು ನವೀಕರಿಸಲಾಗಿದೆ',
    onboarding_saved: 'ಆನ್‌ಬೋರ್ಡಿಂಗ್ ಉಳಿಸಲಾಗಿದೆ',
    updated: 'ನವೀಕರಿಸಲಾಗಿದೆ',
    profile_details_updated: 'ಪ್ರೊಫೈಲ್ ವಿವರಗಳನ್ನು ನವೀಕರಿಸಲಾಗಿದೆ',
    sleep_saved: 'ನಿದ್ರೆ ಉಳಿಸಲಾಗಿದೆ',
    hours_for: 'ಗಂಟೆಗಳು',
    cycle_saved: 'ಚಕ್ರ ಉಳಿಸಲಾಗಿದೆ',
    period_start_on: 'ಋತುಚಕ್ರ ಪ್ರಾರಂಭವಾದ ದಿನಾಂಕ',
    mood_saved: 'ಮನಸ್ಥಿತಿ ಉಳಿಸಲಾಗಿದೆ',
    mood_for: 'ಮನಸ್ಥಿತಿ',
    memory_saved: 'ನೆನಪು ಉಳಿಸಲಾಗಿದೆ',
    details_remembered: 'ವೈಯಕ್ತಿಕ ವಿವರಗಳನ್ನು ನೆನಪಿಟ್ಟುಕೊಳ್ಳಲಾಗಿದೆ'
  }
};

function buildCaptureSummary({
  medicationCapture,
  onboardingCapture,
  sleepCapture,
  cycleCapture,
  moodCapture,
  memoryCapture,
}, languageCode = 'en') {
  const trans = TRANSLATIONS[languageCode] || TRANSLATIONS.en;

  return [
    summarizeCapture(trans.medication_saved, medicationCapture, (capture) =>
      capture.medicationType ? `${trans.taking} ${capture.medicationType}` : trans.details_updated),
    summarizeCapture(trans.onboarding_saved, onboardingCapture, (capture) =>
      Array.isArray(capture.changedKeys) && capture.changedKeys.length > 0
        ? `${trans.updated} ${capture.changedKeys.slice(0, 4).join(', ')}`
        : trans.profile_details_updated),
    summarizeCapture(trans.sleep_saved, sleepCapture, (capture) =>
      capture.durationMinutes ? `${Math.round(capture.durationMinutes / 60 * 10) / 10} ${trans.hours_for} ${capture.entryDate}` : ''),
    summarizeCapture(trans.cycle_saved, cycleCapture, (capture) =>
      capture.cycleStartDate ? `${trans.period_start_on} ${String(capture.cycleStartDate).slice(0, 10)}` : ''),
    summarizeCapture(trans.mood_saved, moodCapture, (capture) =>
      capture.mood ? `${capture.mood} ${trans.mood_for} ${capture.entryDate}` : ''),
    summarizeCapture(trans.memory_saved, memoryCapture, () => trans.details_remembered),
  ]
    .filter((item) => item.length > 0)
    .join(' | ');
}
async function transcribeAudioFile(file) {
  if (!env.grokApiKey) {
    throw new Error('AI API key is not configured.');
  }

  const base64Data = fs.readFileSync(file.path, 'base64');
  
  let format = 'webm';
  if (file.mimetype) {
    const match = file.mimetype.match(/audio\/(x-)?([a-z0-9]+)/i);
    if (match && match[2]) {
      let type = match[2].toLowerCase();
      if (type === 'mpeg') type = 'mp3';
      format = type;
    }
  } else if (file.originalname) {
    const ext = file.originalname.split('.').pop().toLowerCase();
    format = ext;
  }
  
  const supported = ['wav', 'mp3', 'webm', 'ogg', 'm4a', 'flac', 'aac'];
  if (!supported.includes(format)) {
    format = 'webm';
  }

  // Use Grok API & Whisper STT engine for ultra-fast, high-accuracy transcription
  try {
    const transUrl = env.grokApiUrl.includes('/chat/completions')
      ? env.grokApiUrl.replace('/chat/completions', '/audio/transcriptions')
      : 'https://openrouter.ai/api/v1/audio/transcriptions';

    const response = await fetch(transUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.grokApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'openai/whisper-large-v3-turbo',
        input_audio: {
          data: base64Data,
          format: format,
        },
        prompt: "Transcribe spoken English and regional Indian languages (Hindi, Tamil, Telugu, Kannada) accurately. Ignore background noise, hums, or silence.",
      }),
    });

    if (response.ok) {
      const json = await response.json();
      const rawText = (json.text || '').trim();

      const lower = rawText.toLowerCase();
      if (lower.includes("i'm not sure") || lower.includes("i am not sure") || lower.includes("unclear audio") || lower.includes("thank you for watching")) {
        console.log(`[INFO] Filtered out STT hallucination: "${rawText}"`);
        return '';
      }

      if (rawText.length > 0) {
        console.log(`[INFO] Grok/Whisper STT transcription succeeded: "${rawText}"`);
        return rawText;
      }
    } else {
      const errText = await response.text().catch(() => '');
      console.warn(`[WARN] Grok/Whisper STT failed (Status ${response.status}): ${errText}`);
    }
  } catch (err) {
    console.error('[ERROR] Error in Grok/Whisper STT transcription:', err);
  }
  return '';
}

export async function createChatReply(req, res, next) {
  try {
    let { messages, message, mode, role, languageCode, isVoiceCall } = req.body ?? {};
    if (typeof messages === 'string') {
      try {
        messages = JSON.parse(messages);
      } catch (_) {}
    }
    if ((!messages || (Array.isArray(messages) && messages.length === 0)) && typeof message === 'string' && message.trim().length > 0) {
      messages = [{ role: 'user', content: message.trim() }];
    }
    const safeRole = normalizeRoleValue(role, 'woman');

    // Determine effective language code: prefer explicit request, then user's stored onboarding preference, then default.
    let effectiveLanguageCode = 'en';
    if (typeof languageCode === 'string' && languageCode.trim().length > 0) {
      effectiveLanguageCode = normalizeLanguageCode(languageCode);
    }
    const userKey = getUserKey(req, safeRole);
    const userId = req.user?.userId ?? null;

    let userMessage = latestUserMessage(messages);

    let isVoiceMessage = false;
    let transcription = '';
    if (req.file) {
      const lowerName = req.file.originalname.toLowerCase();
      if (req.file.mimetype?.startsWith('audio/') || /\.(webm|wav|mp3|m4a|ogg)$/i.test(lowerName)) {
        isVoiceMessage = true;
        try {
          transcription = await transcribeAudioFile(req.file);
          if (transcription) {
            console.log(`[INFO] Transcribed voice message "${req.file.originalname}": "${transcription}"`);
            userMessage = transcription;
            if (Array.isArray(messages) && messages.length > 0) {
              for (let i = messages.length - 1; i >= 0; i--) {
                if (messages[i].role === 'user') {
                  messages[i].content = transcription;
                  break;
                }
              }
            }
          }
        } catch (err) {
          console.error('Audio transcription error:', err);
        }
      }
    }

    if (userMessage.length === 0 && req.file) {
      userMessage = `Uploaded file: ${req.file.originalname}`;
    }

    let userProfile = userId ? await userRepository.getUserById(userId) : null;
    let medicationCapture = null;
    let onboardingCapture = null;
    let assistantReply = null;
    let memoryCapture = null;

    let medicalReport = null;
    let medicalReportSummary = '';
    if (userId) {
      if (req.file && !isVoiceMessage) {
        const parseResult = await parseAndSaveMedicalReport({
          userId,
          file: req.file,
        });
        if (parseResult.isMedicalReport) {
          medicalReport = parseResult.report;
          medicationCapture = {
            updated: true,
            medicationType: parseResult.medications.join(', '),
            medicationNote: parseResult.details,
            source: 'medical-report-upload',
          };
          medicalReportSummary = `File: "${req.file.originalname}" | Extracted Medications: ${parseResult.medications.join(', ')} | Details: ${parseResult.details}`;
        }
      } else {
        try {
          const latestReport = await db.collection('medical_reports')
            .findOne({ user_id: userId }, { sort: { created_at: -1 } });
          if (latestReport) {
            const meds = latestReport.extracted_medication || 'No medications extracted';
            medicalReportSummary = `Previously uploaded file: "${latestReport.file_name}" | Extracted Medications: ${meds} | Details: ${latestReport.details || 'No details extracted.'}`;
          }
        } catch (err) {
          console.error('Error fetching latest medical report:', err);
        }
      }
    }

    if (userId && userMessage.length > 0) {
      if (!medicationCapture) {
        medicationCapture = await medicationFromChatService.upsertMedicationFromChatMessage({
          userId,
          message: userMessage,
        });
      }

      if (medicationCapture?.updated) {
        userProfile = await userRepository.getUserById(userId);
      }

      onboardingCapture = await onboardingFromChatService.upsertOnboardingFromChatMessage({
        userId,
        message: userMessage,
      });

      if (onboardingCapture.updated) {
        userProfile = await userRepository.getUserById(userId);
      }

      if (medicationCapture?.needsFollowUp) {
        assistantReply = {
          message: medicationCapture.followUpQuestion,
          model: 'rule-based',
        };
      }

      try {
        const memoryAnalysis = profileMemoryService.analyzeConversation(userMessage);
        if (memoryAnalysis.store) {
          const persistedMemory = await profileMemoryRepository.upsertProfileMemory({
            userId,
            profileData: memoryAnalysis.profile_data,
          });
          memoryCapture = {
            updated: Boolean(persistedMemory),
            source: 'ai-chat',
          };
        } else {
          memoryCapture = {
            updated: false,
            reason: memoryAnalysis.reason ?? 'not-stored',
          };
        }
      } catch {
        memoryCapture = {
          updated: false,
          reason: 'capture-failed',
        };
      }
    }

    let sleepCapture = null;
    let cycleCapture = null;
    let moodCapture = null;

    if (userId && userMessage.length > 0) {
      try {
        sleepCapture = await sleepFromChatService.upsertSleepFromChatMessage({
          userId,
          message: userMessage,
        });
      } catch {
        sleepCapture = {
          updated: false,
          reason: 'capture-failed',
        };
      }

      try {
        cycleCapture = await cycleFromChatService.upsertCycleStartFromChatMessage({
          userId,
          role: safeRole,
          message: userMessage,
        });
      } catch {
        cycleCapture = {
          updated: false,
          reason: 'capture-failed',
        };
      }

      try {
        moodCapture = await moodFromChatService.upsertMoodFromChatMessage({ userId, message: userMessage });
      } catch {
        moodCapture = {
          updated: false,
          reason: 'capture-failed',
        };
      }
    }

    if (userId && (
      medicationCapture?.updated
      || onboardingCapture?.updated
      || sleepCapture?.updated
      || cycleCapture?.updated
      || moodCapture?.updated
    )) {
      userProfile = await userRepository.getUserById(userId);
    }

    let extraContextSummary = '';
    if (req.body?.context && typeof req.body.context === 'object') {
      const entries = Object.entries(req.body.context)
        .filter(([_, v]) => v !== null && v !== undefined && String(v).trim().length > 0)
        .map(([k, v]) => `${k}: ${v}`);
      if (entries.length > 0) {
        extraContextSummary = entries.join(' | ');
      }
    }

    let onboardingSummary = buildOnboardingSummary(userProfile?.onboardingAnswers);
    if (extraContextSummary) {
      onboardingSummary = onboardingSummary
        ? `${onboardingSummary} | ${extraContextSummary}`
        : extraContextSummary;
    }

    const predictionContext = userId
      ? await userPredictionContextService.buildUserPredictionContext({
          userId,
          userKey,
          role: safeRole,
        })
      : null;

    const predictionSummary = predictionContext
      ? userPredictionContextService.summarizeForPrompt(predictionContext)
      : '';

    let healthInsightsSummary = '';
    if (req.user?.userId && predictionContext) {
      const healthAnalysis = healthInsightsService.analyzeUserHealth({
        userId: req.user.userId,
        role: safeRole,
        dailyMoods: predictionContext.moodHistory || [],
        sleepLogs: predictionContext.sleepHistory || [],
        onboardingAnswers: userProfile?.onboardingAnswers || {},
        cycleStartDate: userProfile?.cycleStartDate,
      });

      if (healthAnalysis.alerts.length > 0 || healthAnalysis.suggestions.length > 0) {
        const alertMessages = healthAnalysis.alerts
          .map((item) => `ALERT: ${item.title} - ${item.message}`)
          .join(' | ');
        const suggestionMessages = healthAnalysis.suggestions
          .map((item) => `SUGGESTION: ${item.suggestion}`)
          .join(' | ');

        healthInsightsSummary = [alertMessages, suggestionMessages]
          .filter((segment) => segment.length > 0)
          .join(' | ');
      }
    }

    // If no explicit language was provided, check the stored onboarding answers for a preferred_language.
    if ((typeof languageCode !== 'string' || languageCode.trim().length === 0) && userProfile?.onboardingAnswers) {
      try {
        const pref = userProfile.onboardingAnswers?.preferred_language;
        if (typeof pref === 'string' && pref.trim().length > 0) {
          effectiveLanguageCode = normalizeLanguageCode(pref);
        }
      } catch (_) {
        // ignore and fall back to existing effectiveLanguageCode
      }
    }

    const captureSummary = buildCaptureSummary({
      medicationCapture,
      onboardingCapture,
      sleepCapture,
      cycleCapture,
      moodCapture,
      memoryCapture,
    }, effectiveLanguageCode);

    let journalSummary = '';
    if (userId) {
      try {
        const recentJournals = await journalRepository.getJournalsByUserId(userId, 5);
        if (recentJournals && recentJournals.length > 0) {
          journalSummary = recentJournals.map(j => {
            const entryTexts = (j.entries || []).map(e => `${e.title || e.type || 'Note'}: ${e.content || ''}`).join('; ');
            return `[${j.date || 'Journal Entry'}]: ${j.summary || entryTexts}`;
          }).join(' | ');
        }
      } catch (_) {}
    }

    const result = assistantReply ?? await aiChatService.createReply({
      messages,
      role: safeRole,
      user: req.user,
      languageCode: effectiveLanguageCode,
      aiContext: {
        onboardingSummary,
        predictionSummary,
        healthInsightsSummary,
        captureSummary,
        medicalReportSummary,
        journalSummary,
        isVoiceCall: Boolean(req.body?.isVoiceCall),
      },
    });

    if (userMessage.length > 0 && result.message.length > 0) {
      await aiHistoryRepository.appendConversation({
        userKey,
        role: safeRole,
        userMessage,
        assistantMessage: result.message,
        model: result.model,
      });
    }

    res.status(200).json({
      ...result,
      medicationCapture,
      onboardingCapture,
      sleepCapture,
      cycleCapture,
      moodCapture,
      memoryCapture,
      captureSummary,
      medicalReport,
    });
  } catch (error) {
    next(error);
  }
}

function normalizeLanguageCode(languageCode) {
  const value = typeof languageCode === 'string' ? languageCode.trim().toLowerCase() : '';
  const supported = new Set(['en', 'hi', 'bn', 'ta', 'te', 'mr', 'kn']);
  return supported.has(value) ? value : 'en';
}

export async function getPartnerSuggestions(req, res, next) {
  try {
    if (!req.user?.userId) {
      throw createHttpError(401, 'Authentication required to get partner suggestions.');
    }

    const connectionId = String(req.params?.connectionId ?? '').trim();
    if (!connectionId) {
      throw createHttpError(400, 'Connection id is required.');
    }

    const connection = await partnerRepository.getConnectionForUser(connectionId, req.user.userId);
    if (!connection) {
      throw createHttpError(404, 'Connection not found.');
    }

    const partnerUserId = connection.partnerUserId;
    const partnerProfile = await userRepository.getUserById(partnerUserId);
    const viewerOnboarding = await userRepository.getOnboardingAnswers(req.user.userId);
    if (!partnerProfile) {
      throw createHttpError(404, 'Partner user not found.');
    }

    const permissions = connection.permissions ?? {};
    const safeRole = normalizeRoleValue(partnerProfile?.role, 'woman');

    const predictionContext = await userPredictionContextService.buildUserPredictionContext({
      userId: partnerUserId,
      userKey: `user:${partnerUserId}`,
      role: safeRole,
    });

    const dailyMoods = permissions.shareMood ? (predictionContext.moodHistory || []) : [];
    const sleepLogs = permissions.shareSleep ? (predictionContext.sleepHistory || []) : [];
    const onboardingAnswers = permissions.shareOnboarding ? (predictionContext.onboardingAnswers || {}) : {};
    const cycleStartDate = permissions.shareCycle ? (partnerProfile?.cycleStartDate ?? null) : null;

    const healthAnalysis = healthInsightsService.analyzeUserHealth({
      userId: partnerUserId,
      role: safeRole,
      dailyMoods,
      sleepLogs,
      onboardingAnswers,
      cycleStartDate,
    });

    const latestMood = dailyMoods.length > 0 ? dailyMoods[dailyMoods.length - 1] : null;
    const latestSleep = sleepLogs.length > 0 ? sleepLogs[sleepLogs.length - 1] : null;
    const cycleInfo = cycleStartDate ? buildCycleInfo(cycleStartDate, onboardingAnswers) : null;

    let personalizedSuggestions = [];
    if (latestMood || latestSleep || cycleInfo) {
      personalizedSuggestions = buildPartnerCareSuggestions({
        latestMood,
        latestSleep,
        cycleInfo,
        viewerOnboardingAnswers: viewerOnboarding?.onboardingAnswers ?? {},
      }).map((suggestion) => ({
        type: 'partner_support',
        suggestion,
      }));
    }

    // Fetch viewer profile and check if viewer has AI suggestions enabled
    const viewerProfile = await userRepository.getUserById(req.user.userId);
    const viewerRole = normalizeRoleValue(viewerProfile?.role, 'woman');
    const isViewerAiSuggestionsEnabled = viewerRole === 'woman'
      ? permissions.allowAiSuggestionsWoman
      : permissions.allowAiSuggestionsMan;

    let aiChatSuggestions = [];
    if (isViewerAiSuggestionsEnabled) {
      const chatMessages = await partnerRepository.listMessagesForConnection(connectionId, req.user.userId);
      if (chatMessages && chatMessages.length > 0) {
        const mode = String(req.query?.mode ?? 'default').trim();
        aiChatSuggestions = await aiChatService.generatePartnerChatSuggestions(chatMessages, viewerRole, connectionId, mode);
      }
    }

    res.status(200).json({
      hasData: healthAnalysis.hasData,
      dataPoints: healthAnalysis.dataPoints,
      insights: healthAnalysis.insights,
      alerts: healthAnalysis.alerts,
      suggestions: [
        ...(Array.isArray(aiChatSuggestions) ? aiChatSuggestions.map(s => ({ type: 'ai_chat_suggestion', suggestion: s })) : []),
        ...healthAnalysis.suggestions,
        ...personalizedSuggestions,
      ],
      permissions,
    });
  } catch (error) {
    next(error);
  }
}

export async function getHealthInsights(req, res, next) {
  try {
    if (!req.user?.userId) {
      throw createHttpError(401, 'Authentication required to get health insights.');
    }

    const userProfile = await userRepository.getUserById(req.user.userId);
    const safeRole = normalizeRoleValue(userProfile?.role, 'woman');

    const predictionContext = await userPredictionContextService.buildUserPredictionContext({
      userId: req.user.userId,
      userKey: `user:${req.user.userId}`,
      role: safeRole,
    });

    const healthAnalysis = healthInsightsService.analyzeUserHealth({
      userId: req.user.userId,
      role: safeRole,
      dailyMoods: predictionContext.moodHistory || [],
      sleepLogs: predictionContext.sleepHistory || [],
      onboardingAnswers: userProfile?.onboardingAnswers || {},
      cycleStartDate: userProfile?.cycleStartDate,
    });

    res.status(200).json({
      hasData: healthAnalysis.hasData,
      dataPoints: healthAnalysis.dataPoints,
      insights: healthAnalysis.insights,
      alerts: healthAnalysis.alerts,
      suggestions: healthAnalysis.suggestions,
    });
  } catch (error) {
    next(error);
  }
}

export async function getChatHistory(req, res, next) {
  try {
    const role = normalizeRoleValue(req.query?.role, 'woman');
    const userKey = getUserKey(req, role);
    const history = await aiHistoryRepository.listHistory(userKey);

    res.status(200).json({ history });
  } catch (error) {
    next(error);
  }
}

export async function clearChatHistory(req, res, next) {
  try {
    const role = normalizeRoleValue(req.body?.role, 'woman');
    const userKey = getUserKey(req, role);

    await aiHistoryRepository.clearHistory(userKey);
    res.status(200).json({ ok: true });
  } catch (error) {
    next(error);
  }
}

export async function getOnboardingAuditTrail(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required to view onboarding audit trail.');
    }

    const limitRaw = Number.parseInt(String(req.query?.limit ?? ''), 10);
    const limit = Number.isFinite(limitRaw) ? limitRaw : 50;

    const history = await onboardingAuditRepository.listAuditTrailByUser({
      userId,
      limit,
    });

    res.status(200).json({
      history,
    });
  } catch (error) {
    next(error);
  }
}

export async function extractAndStoreProfileMemory(req, res, next) {
  try {
    const conversation = req.body?.conversation;
    const message = req.body?.message;

    const analyzed = profileMemoryService.analyzeConversation(
      Array.isArray(conversation) ? conversation : (typeof message === 'string' ? message : ''),
    );

    if (!analyzed.store) {
      res.status(200).json(analyzed);
      return;
    }

    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required to store profile memory.');
    }

    const persisted = await profileMemoryRepository.upsertProfileMemory({
      userId,
      profileData: analyzed.profile_data,
    });

    res.status(200).json({
      store: true,
      profile_data: {
        ...(persisted?.profile_data ?? analyzed.profile_data),
        user_id: persisted?.user_id ?? userId,
        created_at: persisted?.created_at ?? null,
        updated_at: persisted?.updated_at ?? null,
      },
    });
  } catch (error) {
    next(error);
  }
}

function extractReplyText(payload) {
  const choices = Array.isArray(payload?.choices) ? payload.choices : [];
  for (const choice of choices) {
    const content = choice?.message?.content;
    if (typeof content === 'string' && content.trim()) {
      return content.trim();
    }
  }
  return '';
}

export async function decodePartnerMessage(req, res, next) {
  try {
    if (!req.user || !req.user.userId) {
      throw createHttpError(401, 'Unauthorized');
    }

    const connectionId = String(req.params?.connectionId ?? '').trim();
    if (!connectionId) {
      throw createHttpError(400, 'Connection id is required.');
    }

    const connection = await partnerRepository.getConnectionForUser(connectionId, req.user.userId);
    if (!connection) {
      throw createHttpError(404, 'Connection not found.');
    }

    const viewerProfile = await userRepository.getUserById(req.user.userId);
    const viewerRole = normalizeRoleValue(viewerProfile?.role, 'woman');

    if (viewerRole !== 'man') {
      return res.status(200).json({ canDecode: false, message: 'Decoder is only available for the man.' });
    }

    const permissions = connection.permissions ?? {};
    if (!permissions.allowDecoderMan) {
      return res.status(200).json({ canDecode: false, message: 'Decoder is disabled in settings.' });
    }

    const partnerUserId = connection.partnerUserId;
    const partnerProfile = await userRepository.getUserById(partnerUserId);
    if (!partnerProfile) {
      throw createHttpError(404, 'Partner user not found.');
    }

    const partnerRole = normalizeRoleValue(partnerProfile.role, 'woman');
    if (partnerRole !== 'woman') {
      return res.status(200).json({ canDecode: false, message: 'Partner must be a woman to decode cycle-based context.' });
    }

    const chatMessages = await partnerRepository.listMessagesForConnection(connectionId, req.user.userId);
    if (!chatMessages || chatMessages.length === 0) {
      return res.status(200).json({ canDecode: false, reason: 'No messages yet.' });
    }

    const latestMessage = chatMessages[chatMessages.length - 1];

    const cycleStartDate = partnerProfile.cycleStartDate ?? null;
    const hasCycleShare = permissions.shareCycle;
    const cycleInfo = (hasCycleShare && cycleStartDate) ? buildCycleInfo(cycleStartDate, latestMessage.createdAt) : null;
    
    if (latestMessage.senderRole !== 'woman') {
      return res.status(200).json({ canDecode: false, reason: 'Latest message is not from partner.' });
    }

    // Check Cache
    const cacheKey = `${connectionId}-decoder`;
    const messageState = `${latestMessage.senderUserId}-${latestMessage.message}-${chatMessages.length}`;
    if (!global.partnerDecoderCache) {
      global.partnerDecoderCache = new Map();
    }
    const cached = global.partnerDecoderCache.get(cacheKey);
    if (cached && cached.messageState === messageState) {
      return res.status(200).json({
        canDecode: true,
        decodedText: cached.decodedText,
        cyclePhase: cycleInfo ? cycleInfo.phase : 'Unknown',
        currentCycleDay: cycleInfo ? cycleInfo.currentCycleDay : null,
      });
    }

    const cycleDesc = cycleInfo 
      ? `on Day ${cycleInfo.currentCycleDay} of her menstrual cycle (${cycleInfo.phase} phase)`
      : `in an unknown phase of her menstrual cycle`;

    const messagesText = chatMessages
      .slice(-10)
      .map((m) => `${m.senderRole === 'man' ? 'User (Man)' : 'Partner (Woman)'}: ${m.message}`)
      .join('\n');

    let decodedText = '';
    const grokApiKey = process.env.GROK_API_KEY || '';
    const grokApiUrl = process.env.GROK_API_URL || 'https://openrouter.ai/api/v1/chat/completions';
    const grokModel = process.env.GROK_MODEL || 'x-ai/grok-4.3';

    if (grokApiKey) {
      try {
        const response = await fetch(grokApiUrl, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${grokApiKey}`,
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://blushy.app',
            'X-Title': 'Sia',
          },
          body: JSON.stringify({
            model: grokModel,
            messages: [
              {
                role: 'system',
                content: `You are Sia, acting as a close, casual, and supportive "third wheel" friend to the male user ("bro"). Explain his girlfriend's message subtext in a very human, conversational way (not like a clinical AI), and give a direct tip on how he should reply.
Analyze the recent conversation style/tone (e.g. flirting, playful roasting, bantering, serious, funny) and ensure your tone and suggestions match this style (e.g., if they are roasting, keep the tip roasting/playful; if they are flirting, keep the tip romantic/playful).
The girlfriend is currently ${cycleDesc}.
Keep it short, simple, cool, and conversational.

Recent Chat History:
${messagesText}

Format exactly like this (two lines):
Sia: [casual friendly explanation matching the conversation tone, e.g. "Chill bro, she's just playfully teasing you."]
Tip: [casual, actionable reply advice matching the conversation tone, e.g. "Laugh it off and suggest buying a toy car instead."]

Latest Partner Message to Decode: "${latestMessage.message}"`,
              }
            ],
            max_tokens: 80,
          }),
        });

        if (response.ok) {
          const payload = await response.json();
          decodedText = extractReplyText(payload) || '';
        }
      } catch (err) {
        console.error('Error calling Grok for decoding:', err);
      }
    }

    if (!decodedText) {
      decodedText = `She sent: "${latestMessage.message}". Try responding with warmth and understanding.`;
    }

    global.partnerDecoderCache.set(cacheKey, {
      messageState,
      decodedText,
    });

    res.status(200).json({
      canDecode: true,
      decodedText,
      cyclePhase: cycleInfo ? cycleInfo.phase : 'Unknown',
      currentCycleDay: cycleInfo ? cycleInfo.currentCycleDay : null,
    });
  } catch (error) {
    next(error);
  }
}

export async function getMedicalReports(req, res, next) {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      throw createHttpError(401, 'Authentication required to get medical reports.');
    }
    const reports = await db.collection('medical_reports').find({ user_id: userId }).sort({ created_at: -1 }).toArray();
    res.status(200).json({ reports });
  } catch (error) {
    next(error);
  }
}

export async function transcribeAudio(req, res, next) {
  try {
    if (!req.file) {
      throw createHttpError(400, 'Audio file is required.');
    }
    const transcription = await transcribeAudioFile(req.file);
    res.status(200).json({ transcription });
  } catch (error) {
    next(error);
  }
}

export async function createVoiceSession(req, res, next) {
  try {
    const { mode, languageCode } = req.body ?? {};
    const user = req.user ?? null;
    const userId = user?.userId;
    const safeRole = normalizeRoleValue(user?.role, 'woman');
    const userKey = userId ? `user:${userId}` : (req.ip ?? 'anonymous');

    let onboardingSummary = '';
    let predictionSummary = '';
    let healthInsightsSummary = '';
    let medicalReportSummary = '';
    let journalSummary = '';

    if (userId) {
      const userProfile = await userRepository.getUserById(userId);
      onboardingSummary = buildOnboardingSummary(userProfile?.onboardingAnswers);

      const predictionContext = await userPredictionContextService.buildUserPredictionContext({
        userId,
        userKey,
        role: safeRole,
      });

      predictionSummary = predictionContext
        ? userPredictionContextService.summarizeForPrompt(predictionContext)
        : '';

      if (predictionContext) {
        const healthAnalysis = healthInsightsService.analyzeUserHealth({
          userId,
          role: safeRole,
          dailyMoods: predictionContext.moodHistory || [],
          sleepLogs: predictionContext.sleepHistory || [],
          onboardingAnswers: userProfile?.onboardingAnswers || {},
          cycleStartDate: userProfile?.cycleStartDate,
        });

        const alertMessages = healthAnalysis.alerts
          .map((item) => `ALERT: ${item.title} - ${item.message}`)
          .join(' | ');
        const suggestionMessages = healthAnalysis.suggestions
          .map((item) => `SUGGESTION: ${item.suggestion}`)
          .join(' | ');
        const insightMessages = healthAnalysis.insights
          .map((item) => `INSIGHT: ${item.message}`)
          .join(' | ');

        healthInsightsSummary = [alertMessages, suggestionMessages, insightMessages]
          .filter(Boolean)
          .join(' | ');
      }

      // Fetch latest medical report
      try {
        const latestReport = await db.collection('medical_reports')
          .findOne({ user_id: userId }, { sort: { created_at: -1 } });
        if (latestReport) {
          const meds = latestReport.extracted_medication || 'No medications extracted';
          medicalReportSummary = `Medical Report (${latestReport.file_name}): Extracted Medications: ${meds} | Details: ${latestReport.details || 'None'}`;
        }
      } catch (_) {}

      // Fetch user journals
      try {
        const recentJournals = await journalRepository.getJournalsByUserId(userId, 5);
        if (recentJournals && recentJournals.length > 0) {
          journalSummary = recentJournals.map(j => {
            const entryTexts = (j.entries || []).map(e => `${e.title || e.type || 'Note'}: ${e.content || ''}`).join('; ');
            return `[${j.date || 'Journal Entry'}]: ${j.summary || entryTexts}`;
          }).join(' | ');
        }
      } catch (_) {}
    }

    const session = await aiChatService.createSiaVoiceSession({
      user,
      mode: mode || 'default',
      languageCode: languageCode || 'en',
      aiContext: {
        onboardingSummary,
        predictionSummary,
        healthInsightsSummary,
        medicalReportSummary,
        journalSummary,
      },
    });
    res.status(200).json(session);
  } catch (error) {
    next(error);
  }
}


