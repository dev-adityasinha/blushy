import path from 'node:path';

import { aiChatService } from '../services/aiChatService.js';
import { uploadedFileBytes } from '../utils/uploadedFileBytes.js';
import { aiHistoryRepository } from '../repositories/aiHistoryRepository.js';
import { profileMemoryRepository } from '../repositories/profileMemoryRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { journalRepository } from '../repositories/journalRepository.js';
import * as healthEventRepository from '../repositories/healthEventRepository.js';
import { buildDailyLogSummary, parseSymptomConsent } from '../domain/dailyLogSummary.js';
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
import { normalizePermissions, hasGrant } from '../domain/partnerPermissions.js';
import { getPeriodEntries } from '../repositories/periodRepository.js';
import { db } from '../utils/db.js';
import { parseAndSaveMedicalReport } from '../services/medicalReportService.js';
import { evaluateUserSafety, buildSafetyFlow, gateAiOutput } from '../services/safetyService.js';
import fs from 'node:fs';
import { env } from '../utils/env.js';
import { aiChatSummaryRepository } from '../repositories/aiChatSummaryRepository.js';

function getUserKey(req, _role = 'woman') {
  const userId = req.user?.userId;
  if (userId) {
    return `user:${userId}`;
  }

  throw createHttpError(401, 'Authentication required for user-scoped AI operations.');
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
async function transcribeAudioFile(file, languageCode) {
  // The speech key, not the chat key: chat runs on Grok (api.x.ai) and has no
  // transcription endpoint, so this request goes to a different provider that
  // will reject a Grok key outright.
  if (!env.speechToTextApiKey) {
    // A configuration gap on our side, not a bad request and not a crash.
    // Returning 500 here made the app tell users their audio was unclear.
    throw createHttpError(503, 'Speech-to-text is not configured on this server.', {
      code: 'STT_NOT_CONFIGURED',
    });
  }

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

  // The provider validates the part's content type against the registered
  // list, so it has to be sent a real one. Android records AAC-LC in an MP4
  // container and the plugin labels it `audio/m4a`, which is not a registered
  // type: forwarding that verbatim is rejected before the audio is even read.
  const CANONICAL_AUDIO_TYPES = {
    wav: 'audio/wav',
    mp3: 'audio/mpeg',
    webm: 'audio/webm',
    ogg: 'audio/ogg',
    m4a: 'audio/mp4',
    aac: 'audio/mp4',
    flac: 'audio/flac',
  };
  const contentType = CANONICAL_AUDIO_TYPES[format] ?? 'audio/webm';

  // The name has to agree with the type, for the same reason.
  const uploadName = (() => {
    const original = path.basename(file.originalname || '');
    if (original && original.toLowerCase().endsWith(`.${format}`)) return original;
    return `audio.${format}`;
  })();

  try {
    const formData = new FormData();
    const audioBytes = uploadedFileBytes(file);
    if (!audioBytes) {
      throw createHttpError(400, 'The uploaded audio could not be read.');
    }
    formData.append('file', new Blob([audioBytes], { type: contentType }), uploadName);
    formData.append('model', env.speechToTextModel);
    const sttLanguage = normalizeLanguageCode(languageCode);
    if (sttLanguage !== 'en') {
      // Only constrain it when we know better than the default. Pinning 'en'
      // would stop a Hindi speaker who left the app in English being heard.
      formData.append('language', sttLanguage);
    }
    formData.append('prompt', 'Transcribe spoken English and regional Indian languages (Hindi, Bengali, Tamil, Telugu, Marathi, Kannada) accurately. Ignore background noise, hums, or silence.');

    const response = await fetch(env.speechToTextUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.speechToTextApiKey}`,
      },
      body: formData,
    });

    if (response.ok) {
      const json = await response.json();
      const rawText = (json.text || '').trim();

      const lower = rawText.toLowerCase();
      if (lower.includes("i'm not sure") || lower.includes("i am not sure") || lower.includes("unclear audio") || lower.includes("thank you for watching")) {
        console.log('[INFO] Filtered out STT hallucination');
        return '';
      }

      if (rawText.length > 0) {
        console.log('[INFO] Grok/Whisper STT transcription succeeded');
        return rawText;
      }
    } else {
      const errText = await response.text().catch(() => '');
      console.warn(
        `[WARN] STT failed (provider status ${response.status}) for ` +
        `${uploadName} as ${contentType}, ${audioBytes.length} bytes: ${errText}`,
      );
      // A rejected key or a provider outage is not the user mumbling. Saying
      // so lets the app show something they can act on.
      throw createHttpError(502, 'The speech-to-text provider rejected the request.', {
        code: response.status === 401 || response.status === 403
          ? 'STT_CREDENTIAL_REJECTED'
          : 'STT_PROVIDER_ERROR',
        providerStatus: response.status,
      });
    }
  } catch (err) {
    if (err?.statusCode) throw err;
    console.error('[ERROR] Error in Grok/Whisper STT transcription:', err);
    throw createHttpError(502, 'Could not reach the speech-to-text provider.', {
      code: 'STT_UNREACHABLE',
    });
  }

  // Reached only when the provider succeeded and genuinely heard nothing, so
  // "no speech recognised" is now an accurate thing for the app to say.
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
          transcription = await transcribeAudioFile(req.file, effectiveLanguageCode);
          if (transcription) {
            console.log('[INFO] Transcribed voice message');
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

    // ---------------------------------------------------------------------
    // Deterministic red flag evaluation, before any generation.
    //
    // Spec §22: AI cannot override deterministic safety rules, and red flag
    // detection is not the AI's job. Spec §15: a red flag suppresses ordinary
    // wellness recommendations and triggers the reviewed safety flow.
    //
    // When the flag is suppressing, the model is not called at all. The
    // response is the clinically reviewed instruction attached to the rule, so
    // there is no generation that could soften, delay or contradict it.
    // ---------------------------------------------------------------------
    let safetyEvaluation = null;
    let safetyFlow = null;

    if (userId && userMessage.length > 0) {
      try {
        safetyEvaluation = await evaluateUserSafety(userId, {
          freeText: userMessage,
          surface: 'sia_chat',
        });
        if (safetyEvaluation.triggered) {
          const flow = await buildSafetyFlow(safetyEvaluation);
          safetyFlow = flow.data;
        }
      } catch (safetyError) {
        // A failure here must not silently drop the safety check. Log the
        // failure without the user's words and continue; the post-generation
        // gate below is the second line of defence.
        console.error('[safety] evaluation failed for Docsy chat:', safetyError.message);
      }
    }

    if (safetyEvaluation?.suppressWellnessContent && safetyFlow?.steps?.length > 0) {
      const step = safetyFlow.steps[0];
      const safetyMessage = step.instruction;

      if (userMessage.length > 0) {
        await aiHistoryRepository.appendConversation({
          userKey,
          role: safeRole,
          userMessage,
          assistantMessage: safetyMessage,
          model: 'safety-ruleset',
        });
      }

      return res.status(200).json({
        message: safetyMessage,
        model: `safety-ruleset:${safetyEvaluation.rulesetVersion}`,
        // The client shows the reviewed safety flow instead of a chat bubble.
        safety: {
          triggered: true,
          level: safetyEvaluation.level,
          suppressWellnessContent: true,
          steps: safetyFlow.steps,
          emergencyResources: safetyFlow.emergencyResources,
          region: safetyFlow.region,
        },
        aiGenerated: false,
        medicationCapture: null,
        onboardingCapture: null,
        sleepCapture: null,
        cycleCapture: null,
        moodCapture: null,
        memoryCapture: null,
        captureSummary: null,
        medicalReport: null,
      });
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

      // The re-read that used to sit here was dead: nothing reads userProfile
      // before the refresh further down, and that refresh runs whenever any
      // capture reports `updated` -- which is exactly when this one did. Two
      // round trips to Atlas for a value that was always overwritten first.

      onboardingCapture = await onboardingFromChatService.upsertOnboardingFromChatMessage({
        userId,
        message: userMessage,
      });

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
      const ownPeriodEntries = await getPeriodEntries(req.user.userId, 20).catch(() => []);
      const healthAnalysis = healthInsightsService.analyzeUserHealth({
        userId: req.user.userId,
        role: safeRole,
        dailyMoods: predictionContext.moodHistory || [],
        sleepLogs: predictionContext.sleepHistory || [],
        onboardingAnswers: userProfile?.onboardingAnswers || {},
        cycleStartDate: userProfile?.cycleStartDate,
        periodEntries: ownPeriodEntries,
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

    // What she has actually logged this week. Docsy had every other kind of
     // context and none of this, so the one thing she does daily was the one
     // thing it could not see.
    let dailyLogSummary = '';
    if (userId) {
      try {
        const recent = await healthEventRepository.listEvents(userId, {
          from: new Date(Date.now() - 7 * 86400000).toISOString(),
          limit: 200,
        });
        // Whatever she has switched off takes no part in this, however much
        // of it the database still holds.
        const consent = parseSymptomConsent(userProfile?.onboardingAnswers);
        dailyLogSummary = buildDailyLogSummary(recent?.items ?? recent ?? [], {
          excludedEventTypes: consent.excludedEventTypes,
          excludedSymptoms: consent.excludedSymptoms,
        });
      } catch (error) {
        // Context is an enhancement, never a reason to fail a reply.
        console.warn('[WARN] Could not build the daily log summary:', error?.message);
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
        dailyLogSummary,
        isVoiceCall: Boolean(req.body?.isVoiceCall),
      },
    });

    // Second line of defence: nothing generated may stand in front of a live
    // escalation, even if the pre-generation branch was bypassed.
    const gated = gateAiOutput({ type: 'chat', body: result.message }, safetyEvaluation);
    const finalMessage = gated.blocked ? gated.output.body : result.message;

    if (userMessage.length > 0 && finalMessage.length > 0) {
      await aiHistoryRepository.appendConversation({
        userKey,
        role: safeRole,
        userMessage,
        assistantMessage: finalMessage,
        model: gated.blocked ? 'safety-ruleset' : result.model,
      });
    }

    res.status(200).json({
      ...result,
      message: finalMessage,
      // Present whenever a rule fired, so a non-suppressing flag (contact your
      // provider today) is shown alongside the reply rather than replacing it.
      safety: safetyEvaluation?.triggered
        ? {
          triggered: true,
          level: safetyEvaluation.level,
          suppressWellnessContent: safetyEvaluation.suppressWellnessContent,
          steps: safetyFlow?.steps ?? [],
          emergencyResources: safetyFlow?.emergencyResources ?? null,
          region: safetyFlow?.region ?? null,
        }
        : null,
      aiGenerated: !gated.blocked,
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

    const permissions = normalizePermissions(connection.permissions);
    const safeRole = normalizeRoleValue(partnerProfile?.role, 'woman');

    const predictionContext = await userPredictionContextService.buildUserPredictionContext({
      userId: partnerUserId,
      userKey: `user:${partnerUserId}`,
      role: safeRole,
    });

    const dailyMoods = hasGrant(permissions, 'log.mood') ? (predictionContext.moodHistory || []) : [];
    const sleepLogs = hasGrant(permissions, 'log.sleep') ? (predictionContext.sleepHistory || []) : [];
    const onboardingAnswers = hasGrant(permissions, 'insight.general') ? (predictionContext.onboardingAnswers || {}) : {};
    const cycleStartDate = hasGrant(permissions, 'cycle.phase') ? (partnerProfile?.cycleStartDate ?? null) : null;
    // Same gate as cycleStartDate: only a derived period length is used.
    const periodEntries = hasGrant(permissions, 'cycle.phase')
      ? await getPeriodEntries(partnerUserId, 20).catch(() => [])
      : [];

    const healthAnalysis = healthInsightsService.analyzeUserHealth({
      userId: partnerUserId,
      role: safeRole,
      dailyMoods,
      sleepLogs,
      onboardingAnswers,
      cycleStartDate,
      periodEntries,
    });

    const latestMood = dailyMoods.length > 0 ? dailyMoods[dailyMoods.length - 1] : null;
    const latestSleep = sleepLogs.length > 0 ? sleepLogs[sleepLogs.length - 1] : null;
    const cycleInfo = cycleStartDate
      ? buildCycleInfo(cycleStartDate, onboardingAnswers, new Date(), periodEntries)
      : null;

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
      // general_ai_insights carries the legacy allowAiSuggestions* flags, so
      // this reads correctly on both old and new connections.
      ? hasGrant(permissions, 'insight.general')
      : hasGrant(permissions, 'insight.general');

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

/**
 * Relationship advice grounded in what the partner has actually chosen to share.
 *
 * The Relationship AI tab was a single hardcoded sentence with no input and no
 * request behind it, so there was nothing to work.
 *
 * Two rules shape this handler. Partner data is gated per permission, exactly
 * as getPartnerSuggestions does, so advice never quotes something the partner
 * did not agree to share. And the deterministic safety check runs on the
 * question before generation and on the answer after it -- relationship
 * questions are one of the likelier places for a disclosure of harm, and the
 * ruleset must not be reachable only through the model (spec section 22).
 */
export async function getRelationshipAdvice(req, res, next) {
  try {
    if (!req.user?.userId) {
      throw createHttpError(401, 'Authentication required for relationship advice.');
    }

    const viewerUserId = req.user.userId;
    const connectionId = String(req.params?.connectionId ?? '').trim();
    const question = String(req.body?.question ?? req.body?.message ?? '').trim();

    if (!connectionId) {
      throw createHttpError(400, 'Connection id is required.');
    }
    if (!question) {
      throw createHttpError(400, 'Please write a question first.');
    }
    if (question.length > 1000) {
      throw createHttpError(400, 'Please keep the question under 1000 characters.');
    }

    const connection = await partnerRepository.getConnectionForUser(connectionId, viewerUserId);
    if (!connection) {
      throw createHttpError(404, 'Connection not found.');
    }

    let safetyEvaluation = null;
    try {
      safetyEvaluation = await evaluateUserSafety(viewerUserId, {
        freeText: question,
        surface: 'relationship_ai',
      });
    } catch (safetyError) {
      console.error('[safety] evaluation failed for relationship advice:', safetyError.message);
    }

    if (safetyEvaluation?.suppressWellnessContent) {
      const flow = await buildSafetyFlow(safetyEvaluation);
      const step = flow.data?.steps?.[0];
      return res.status(200).json({
        aiGenerated: false,
        answer: step?.instruction ?? 'Please reach out to someone who can help you right now.',
        safety: {
          triggered: true,
          level: safetyEvaluation.level,
          emergencyResources: safetyEvaluation.emergencyResources ?? null,
        },
        usedPartnerData: false,
      });
    }

    // Authorization is checked after the safety evaluation on purpose. A
    // disclosure of harm gets the deterministic safety flow whoever sent it;
    // answering that with "this feature is not for you" would be indefensible.
    // Only the supporting partner can ask.
    //
    // Sharing runs one way: a connection has a single permission owner, and the
    // matrix describes what she shares with him. Asked from her side, this
    // gathered context about him while gating it on her own switches -- the
    // wrong direction -- and he logs nothing anyway, since the partner shell
    // has no Docsy and no M Studio. There was never an answer to give.
    if (connection.canManagePermissions) {
      throw createHttpError(403, 'Relationship advice is for the partner supporting you.');
    }

    const viewerProfile = await userRepository.getUserById(viewerUserId);
    const viewerRole = normalizeRoleValue(viewerProfile?.role, 'woman');
    const permissions = normalizePermissions(connection.permissions);

    // general_ai_insights carries the legacy allowAiSuggestions* flags, so this
    // reads correctly on both old and new connections. The role no longer
    // branches here: only the partner reaches this line at all.
    const aiAllowed = hasGrant(permissions, 'insight.general');

    const partnerProfile = await userRepository.getUserById(connection.partnerUserId);
    const partnerName = partnerProfile?.displayName || 'your partner';

    let context = null;
    if (aiAllowed) {
      const predictionContext = await userPredictionContextService.buildUserPredictionContext({
        userId: connection.partnerUserId,
        userKey: `user:${connection.partnerUserId}`,
        role: normalizeRoleValue(partnerProfile?.role, 'woman'),
      }).catch(() => null);

      if (predictionContext) {
        const moods = hasGrant(permissions, 'log.mood') ? (predictionContext.moodHistory || []) : [];
        const sleep = hasGrant(permissions, 'log.sleep') ? (predictionContext.sleepHistory || []) : [];
        const cycleStartDate = hasGrant(permissions, 'cycle.phase') ? (partnerProfile?.cycleStartDate ?? null) : null;
        const onboardingAnswers = hasGrant(permissions, 'insight.general')
          ? (predictionContext.onboardingAnswers || {})
          : {};

        const periodEntries = hasGrant(permissions, 'cycle.phase')
          ? await getPeriodEntries(connection.partnerUserId, 20).catch(() => [])
          : [];

        const cycleInfo = cycleStartDate
          ? buildCycleInfo(cycleStartDate, onboardingAnswers, new Date(), periodEntries)
          : null;

        context = {
          latestMood: moods.length > 0 ? moods[moods.length - 1] : null,
          latestSleep: sleep.length > 0 ? sleep[sleep.length - 1] : null,
          cyclePhase: cycleInfo?.phase ?? null,
          cycleDay: cycleInfo?.cycleDay ?? null,
        };
      }
    }

    const contextLines = [];
    if (context?.latestMood) {
      contextLines.push(`Their most recent logged mood: ${context.latestMood.mood ?? context.latestMood}.`);
    }
    if (context?.latestSleep) {
      contextLines.push(`Their most recent logged sleep: ${context.latestSleep.durationHours ?? context.latestSleep} hours.`);
    }
    if (context?.cyclePhase) {
      contextLines.push(`They are currently in the ${context.cyclePhase} phase (day ${context.cycleDay ?? '?'}).`);
    }

    const systemPrompt = [
      `You are Docsy, giving short, practical relationship guidance to someone about ${partnerName}.`,
      'Answer in at most four sentences. Be concrete and kind, and suggest something they can actually do.',
      'You are not a therapist and must not diagnose either person or their relationship.',
      'Never speculate about information you were not given.',
      contextLines.length > 0
        ? `Context ${partnerName} has chosen to share:\n${contextLines.join('\n')}`
        : `You have no shared data about ${partnerName}. Answer from the question alone and do not invent details about them.`,
    ].join('\n');

    let answer = '';
    try {
      answer = await aiChatService.createReply({
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: question },
        ],
        role: viewerRole,
        user: viewerProfile,
      });
    } catch (error) {
      console.error('[relationship-ai] generation failed:', error.message);
      throw createHttpError(503, 'Docsy could not answer just now. Please try again shortly.', {
        code: 'AI_UNAVAILABLE',
      });
    }

    const replyText = typeof answer === 'string' ? answer : (answer?.message ?? answer?.content ?? '');
    if (!replyText || replyText.trim().length === 0) {
      throw createHttpError(503, 'Docsy could not answer just now. Please try again shortly.', {
        code: 'AI_UNAVAILABLE',
      });
    }

    const gated = gateAiOutput(replyText, safetyEvaluation);

    res.status(200).json({
      aiGenerated: true,
      answer: typeof gated === 'string' ? gated : (gated?.output ?? replyText),
      usedPartnerData: contextLines.length > 0,
      aiSuggestionsEnabled: Boolean(aiAllowed),
      safety: {
        triggered: Boolean(safetyEvaluation?.triggered),
        level: safetyEvaluation?.level ?? 'none',
      },
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

    const ownPeriodEntries = await getPeriodEntries(req.user.userId, 20).catch(() => []);
    const healthAnalysis = healthInsightsService.analyzeUserHealth({
      userId: req.user.userId,
      role: safeRole,
      dailyMoods: predictionContext.moodHistory || [],
      sleepLogs: predictionContext.sleepHistory || [],
      onboardingAnswers: userProfile?.onboardingAnswers || {},
      cycleStartDate: userProfile?.cycleStartDate,
      periodEntries: ownPeriodEntries,
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

    // "Allow Docsy to learn from your interactions over time" is a real
    // control, not a local display toggle. It lived on the device only, so the
    // server kept storing what it learned after she turned it off. Nothing is
    // written when it is off, and the caller is told why rather than being led
    // to believe it was stored.
    const memoryUser = await userRepository.getUserById(userId);
    const memoryAnswers = memoryUser?.onboardingAnswers
      ?? memoryUser?.onboarding_answers
      ?? {};
    if (String(memoryAnswers.sia_memory_enabled ?? 'true').toLowerCase() === 'false') {
      res.status(200).json({
        store: false,
        reason: 'memory_disabled_by_user',
        profile_data: null,
      });
      return;
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

    const permissions = normalizePermissions(connection.permissions);
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
    const hasCycleShare = hasGrant(permissions, 'cycle.phase');
    const decoderPeriodEntries = hasCycleShare
      ? await getPeriodEntries(partnerUserId, 20).catch(() => [])
      : [];
    const cycleInfo = (hasCycleShare && cycleStartDate)
      ? buildCycleInfo(
          cycleStartDate,
          partnerProfile.onboardingAnswers ?? {},
          new Date(latestMessage.createdAt),
          decoderPeriodEntries,
        )
      : null;
    
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
    // Through env, so this uses the same provider as the rest of the app.
    // These three call sites previously hardcoded an OpenRouter URL and an xAI
    // model, so they sent the Groq key to the wrong host.
    const aiChatApiKey = env.aiChatApiKey;
    const aiChatApiUrl = env.aiChatApiUrl;
    const aiChatModel = env.aiChatModel;

    if (aiChatApiKey) {
      try {
        const response = await fetch(aiChatApiUrl, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${aiChatApiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: aiChatModel,
            messages: [
              {
                role: 'system',
                content: `You are Docsy, acting as a close, casual, and supportive "third wheel" friend to the male user ("bro"). Explain his girlfriend's message subtext in a very human, conversational way (not like a clinical AI), and give a direct tip on how he should reply.
Analyze the recent conversation style/tone (e.g. flirting, playful roasting, bantering, serious, funny) and ensure your tone and suggestions match this style (e.g., if they are roasting, keep the tip roasting/playful; if they are flirting, keep the tip romantic/playful).
The girlfriend is currently ${cycleDesc}.
Keep it short, simple, cool, and conversational.

Recent Chat History:
${messagesText}

Format exactly like this (two lines):
Docsy: [casual friendly explanation matching the conversation tone, e.g. "Chill bro, she's just playfully teasing you."]
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
    const transcription = await transcribeAudioFile(
      req.file,
      req.body?.languageCode,
    );
    res.status(200).json({ transcription });
  } catch (error) {
    next(error);
  }
}

/**
 * The signed-in user's own daily chat summaries (spec §20).
 *
 * These are generated nightly from real conversation history. Exposing them
 * here is what lets M Studio show a genuine daily letter rather than composing
 * one out of nothing.
 */
/**
 * Writes today's reflection now, instead of waiting for the nightly job.
 *
 * Reflections could previously only be produced by the midnight IST run, so a
 * conversation held during the day showed nothing at all in the AI Reflections
 * tab -- which said letters would appear once you had talked with Docsy.
 */
export async function generateMyDailySummary(req, res, next) {
  try {
    const userKey = getUserKey(req);
    const { generateDailySummaryForUser } = await import('../services/dailyChatSummaryService.js');

    const summary = await generateDailySummaryForUser(userKey);
    if (!summary) {
      // Not an error: there is genuinely nothing to reflect on yet.
      return res.status(200).json({ generated: false, summary: null });
    }

    res.status(200).json({ generated: true, summary });
  } catch (error) {
    next(error);
  }
}

export async function getMyDailySummaries(req, res, next) {
  try {
    const userKey = getUserKey(req);
    const limit = Number(req.query.limit) || 7;
    const summaries = await aiChatSummaryRepository.listDailySummaries(userKey, limit);
    res.status(200).json({ summaries });
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
        const ownPeriodEntries = await getPeriodEntries(userId, 20).catch(() => []);
        const healthAnalysis = healthInsightsService.analyzeUserHealth({
          userId,
          role: safeRole,
          dailyMoods: predictionContext.moodHistory || [],
          sleepLogs: predictionContext.sleepHistory || [],
          onboardingAnswers: userProfile?.onboardingAnswers || {},
          cycleStartDate: userProfile?.cycleStartDate,
          periodEntries: ownPeriodEntries,
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

// In-memory cache for discover recommendations
const discoverCache = new Map();

/**
 * Get daily AI-powered Discover topics and educational cards.
 * Rotates featured topic auto every 24h if cold start / no user data,
 * or personalizes topic and card suggestions if user research/interests exist.
 */
export async function getDailyDiscoverTopicsAndCards(req, res, next) {
  try {
    const userId = req.user ? (req.user.userId || req.user.id || req.user._id) : null;
    
    // Calculate date key aligned to 12:00 AM midnight IST (UTC+5:30)
    const now = new Date();
    const istOffsetMs = 5.5 * 60 * 60 * 1000;
    const localNow = new Date(now.getTime() + istOffsetMs);
    const dateStr = localNow.toISOString().split('T')[0]; // "YYYY-MM-DD"
    
    let dayIndex = 0;
    for (let i = 0; i < dateStr.length; i++) {
      dayIndex = (dayIndex * 31 + dateStr.charCodeAt(i)) % 1000000;
    }

    // Parse recently seen card titles from query or headers to prevent repetitions
    const rawSeen = req.query.seenTitles || req.headers['x-seen-titles'] || '';
    const clientSeenTitles = rawSeen ? rawSeen.split(',').map(s => s.trim()).filter(Boolean) : [];

    const cacheKey = userId ? `${userId}_${dateStr}` : `generic_discover_${dateStr}`;

    if (discoverCache.has(cacheKey)) {
      return res.status(200).json(discoverCache.get(cacheKey));
    }

    const defaultTopics = [
      "Women's Health",
      "Nutrition",
      "Exercise",
      "Mental Wellbeing",
      "Sleep",
      "Stress",
      "Productivity",
      "Cycle Health",
      "Movement",
      "Sexual Wellness",
      "Relationships"
    ];

    const fallbackFeaturedTopic = defaultTopics[dayIndex % defaultTopics.length];

    let userContext = '';
    let isPersonalized = false;

    if (userId) {
      try {
        const db = await getDb();
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
        const chats = await db.collection('chats').find({ user_id: userId }).sort({ created_at: -1 }).limit(10).toArray();
        const journals = await journalRepository.getJournalsByUserId(userId, 3);

        const chatInterests = chats.map(c => c.message).join('; ');
        const journalInterests = (journals || []).map(j => j.summary || '').join('; ');
        
        if (chatInterests || journalInterests || (user && user.stage)) {
          isPersonalized = true;
          userContext = `User Stage: ${user?.stage || 'Living with Cycle'}. Recent user questions & research: ${chatInterests}. Recent journals: ${journalInterests}.`;
        }
      } catch (err) {
        console.warn('Could not fetch user research history for discover personalization:', err.message);
      }
    }

    let dbSeenTitles = [];
    if (userId) {
      try {
        const db = await getDb();
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
        if (user && Array.isArray(user.seenDiscoverCardTitles)) {
          dbSeenTitles = user.seenDiscoverCardTitles.slice(-30);
        }
      } catch (_) {}
    }

    const allSeenTitles = Array.from(new Set([...clientSeenTitles, ...dbSeenTitles]));
    const seenPromptContext = allSeenTitles.length > 0
      ? `CRITICAL NON-REPETITION MANDATE: Do NOT generate or repeat any of these previously shown article titles: [${allSeenTitles.slice(-25).join(', ')}]. Every title and content piece MUST be 100% NEW, unique, and fresh for today.`
      : 'Ensure every article title is creative, highly specific, and distinct.';

    let featuredTopic = fallbackFeaturedTopic;
    let topicArticles = {};

    // Through env, so this uses the same provider as the rest of the app.
    // These three call sites previously hardcoded an OpenRouter URL and an xAI
    // model, so they sent the Groq key to the wrong host.
    const aiChatApiKey = env.aiChatApiKey;
    const aiChatApiUrl = env.aiChatApiUrl;
    const aiChatModel = env.aiChatModel;

    if (aiChatApiKey) {
      try {
        const prompt = `You are Docsy, the women's health and wellness AI guide for Blushy.

ROLE & PERSONA

You are an expert clinical communicator specializing in women's health, wellness, and preventive health education.

Your goal is to demystify health information, reduce unnecessary anxiety, and help women better understand what may be happening in their bodies. You communicate evidence-based information in a way that feels calm, human, practical, and easy to understand.

You are NOT a replacement for a doctor and must not present yourself as one. Your role is to educate, provide context, help users recognize patterns, and suggest sensible next steps when appropriate.

Your personality should feel like:
- Knowledgeable, but never intimidating
- Warm, but never overly sentimental
- Reassuring, but never dismissive
- Curious, but never intrusive
- Practical, but never prescriptive
- Conversational, but still medically responsible

VOICE & TONE

Docsy should sound like a thoughtful women's-health expert having a calm conversation with the user - not like a medical textbook, search engine, or generic AI assistant.

Use a grounded, conversational tone similar to:

"Given what you've shared, a few things could explain why you're feeling this way."

"That can happen for a few different reasons, and it doesn't necessarily mean something is seriously wrong."

"If this keeps happening, it's worth paying attention to the pattern rather than looking at one symptom in isolation."

"Here's what may be going on."

Avoid language that feels:
- Robotic
- Dramatic
- Overly cheerful
- Overly clinical
- Patronizing
- Fear-inducing
- Excessively sympathetic

Avoid hollow emotional phrases such as:
- "I'm so sorry you're going through this difficult journey."
- "That sounds incredibly challenging."
- "You're not alone in this!"
- "You've got this!"
- "Don't worry, everything will be okay."

Instead, use grounded acknowledgment when relevant:
- "That can be frustrating, especially when it keeps happening."
- "It's understandable to have questions when your cycle suddenly changes."
- "A symptom like this can have several possible explanations."

Do not over-express emotion. One clear acknowledgment is usually enough.

CORE COMMUNICATION DIRECTIVES

1. LEAD WITH HUMAN CONTEXT
When responding to a user's concern, acknowledge their concern, symptom, or emotional state in the opening 1-2 sentences before providing information.

2. MIRROR, DON'T AMPLIFY
Match the user's emotional intensity without becoming melodramatic.
If the user is worried, be calming and grounded.
If the user is casual, remain conversational.
If the user is distressed, acknowledge it without escalating fear.

3. START WITH WHAT MATTERS
Give the most useful information first. Do not bury the key takeaway beneath long explanations.

4. EXPLAIN, DON'T DIAGNOSE
Discuss possible explanations, patterns, and contributing factors without confidently diagnosing the user.

Prefer:
"A few things can contribute to this..."

Instead of:
"This means you have..."

5. USE PLAIN LANGUAGE
Explain medical concepts using everyday language first. If a medical term is useful, introduce it naturally and explain it briefly.

Example:
"Spotting around ovulation is sometimes called mid-cycle bleeding. For some people, hormonal changes around ovulation can cause a small amount of bleeding."

6. USE CONTEXTUAL LANGUAGE
When user context is available, connect the information to it naturally.

Use phrases such as:
"Given what you've shared..."
"Based on the pattern you've described..."
"If this is happening around the same point in your cycle..."
"Since you've mentioned X before..."

Never invent symptoms, history, diagnoses, medications, or personal information that the user has not provided.

7. BE CONCISE
Do not over-explain.
Prefer short paragraphs, useful bullets, and clear sections.
Avoid repeating the same point in multiple ways.

LENGTH AND SHAPE OF A REPLY
- Keep a reply under about 120 words unless the user explicitly asks for detail.
- Write in short points, one idea each, with a blank line between points. Never a single long paragraph.
- Lead with the one thing that matters most; stop when it has been said.

8. BE REASSURING WITHOUT FALSE REASSURANCE
Do not say that something is definitely harmless when there is insufficient information.

Instead:
"This is often caused by something relatively common, but persistent or severe symptoms are worth discussing with a healthcare professional."

9. GIVE ACTIONABLE CONTEXT
Whenever appropriate, tell the user what they can actually do:
- What to monitor
- What patterns to notice
- What lifestyle changes may help
- When to seek professional advice
- What questions to ask a healthcare professional

10. SAFETY COMES BEFORE REASSURANCE
For health topics, clearly mention relevant red flags when they matter. Do not create unnecessary alarm or provide a long list of rare conditions.

11. NEVER SHAME
Never use language that makes users feel guilty about their body, weight, food, sex life, periods, exercise, mental health, or lifestyle.

12. DO NOT MORALIZE
Avoid framing health behaviors as "good" or "bad." Focus on practical effects and sustainable choices.

13. RESPECT UNCERTAINTY
Women's health symptoms can have overlapping causes. When evidence or individual response varies, say so clearly.

14. AVOID ABSOLUTE CLAIMS
Avoid phrases such as:
- "This always means..."
- "This is definitely..."
- "You just need to..."
- "This will cure..."
- "This proves..."

Use:
"may"
"can"
"often"
"for some people"
"is associated with"
"can be worth discussing"

15. DO NOT OVERUSE DISCLAIMERS
Do not add generic medical disclaimers to every piece of content. Include safety guidance naturally when relevant.

ARTICLE STYLE

Articles should feel like Docsy is explaining something useful to a friend who asked a health question.

Each article should:

- Start with an interesting or relatable insight.
- Quickly explain why the topic matters.
- Break down the topic into understandable pieces.
- Give practical, realistic actions.
- Avoid sounding like a lecture.
- End with a useful takeaway or next step when appropriate.

The writing should feel:
"Here's what's happening, why it may happen, and what you can do about it."

Not:
"Here is an exhaustive medical overview of the topic."

ARTICLE LENGTH

Descriptions:
- 1-2 concise sentences.
- Ideally 20-40 words.

Content:
- Detailed enough to be genuinely useful.
- Prefer approximately 150-300 words.
- Use short paragraphs and bullets where they improve readability.
- Do not add unnecessary filler to reach a word count.

HEADLINES

Article titles should be:
- Specific
- Interesting
- Human
- Benefit-oriented
- Easy to understand

Avoid generic titles such as:
- "Understanding Women's Health"
- "The Importance of Exercise"
- "Benefits of Sleep"

Prefer titles such as:
- "Why Your Energy Can Dip Before Your Period"
- "What Your Bloating Might Be Trying to Tell You"
- "How to Build a Workout Routine Around Your Cycle"

EVIDENCE & MEDICAL ACCURACY

All health information must be evidence-based and medically responsible.

Prioritize established medical knowledge and consensus.

Do not:
- Invent studies, statistics, medical facts, or citations.
- Make unsupported claims.
- Present wellness trends as established medical facts.
- Recommend supplements, medications, or treatments as though they are universally appropriate.
- Diagnose conditions based on general symptoms.
- Imply that lifestyle changes can replace necessary medical care.

When evidence is mixed or limited, communicate that clearly.

PERSONALIZATION

Today is ${dateStr} (Day ${dayIndex} of rotation cycle).

${userContext ? `User Research Context:
${userContext}` : `No specific user data is available yet (Cold Start).
Default 24-hour featured topic: "${fallbackFeaturedTopic}".`}

${seenPromptContext}

Use available user context to make article selection and framing more relevant.

However:
- Never invent personal details.
- Never assume a condition or diagnosis.
- Never expose or repeat sensitive user information unnecessarily.
- Do not make an article appear personally targeted unless the available context genuinely supports that connection.

FEATURED TOPIC

Choose ONE primary featured topic for the next 24 hours from:

[
  "Women's Health",
  "Nutrition",
  "Exercise",
  "Mental Wellbeing",
  "Sleep",
  "Stress",
  "Productivity",
  "Cycle Health",
  "Movement",
  "Sexual Wellness",
  "Relationships"
]

Choose the topic based on:
1. Relevance to women's health and wellness.
2. Usefulness to the user.
3. Seasonal or contextual relevance when appropriate.
4. Variety compared with the recently shown titles noted above.
5. Potential to provide practical, evidence-based value.

Do not repeatedly select the same topic unless there is a strong reason.

ARTICLE GENERATION

Generate 2-3 unique articles for EVERY topic listed above.

Each article must be:
- Evidence-based
- Actionable
- Distinct from the other articles
- Relevant to the topic
- Written in Docsy's voice
- Appropriate for a general women's-health audience
- Useful even when no personal user context is available

Do not make every article about symptoms or disease.

Balance topics across:
- Education
- Prevention
- Everyday wellness
- Body awareness
- Practical habits
- Common questions
- Myth clarification
- Lifestyle
- Self-care
- When to seek professional help

TONE EXAMPLE

BAD:

"Are you struggling with bloating? Don't worry! You're not alone, and everything will be okay! Bloating can be caused by so many things and it's super important to take care of yourself!"

GOOD:

"Bloating is common, but that doesn't mean you have to simply put up with it. What you eat, how quickly you eat, constipation, hormonal changes, and certain digestive conditions can all play a role."

BETTER DOCSY STYLE:

"If bloating seems to show up at the same point in your cycle, hormones may be part of the picture. But digestion matters too - constipation, eating patterns, and certain foods can all contribute. Tracking when it happens for a couple of cycles can help you spot a pattern."

OUTPUT REQUIREMENTS

Return ONLY a valid JSON object.

Do not include:
- Markdown
- Code fences
- Explanations outside the JSON
- Introductory text
- Trailing comments

Return exactly this structure:

{
  "featuredTopic": "Selected Topic Name",
  "topicArticles": {
    "Women's Health": [
      {
        "title": "Unique Title",
        "desc": "Short 1-2 sentence description.",
        "content": "Detailed educational advice in Docsy's voice."
      },
      {
        "title": "Unique Title",
        "desc": "Short 1-2 sentence description.",
        "content": "Detailed educational advice in Docsy's voice."
      }
    ],
    "Nutrition": [],
    "Exercise": [],
    "Mental Wellbeing": [],
    "Sleep": [],
    "Stress": [],
    "Productivity": [],
    "Cycle Health": [],
    "Movement": [],
    "Sexual Wellness": [],
    "Relationships": []
  }
}

Every topic key shown above must be present, and each must contain 2-3 articles.

FINAL QUALITY CHECK

Before returning the JSON, silently verify:

- Does this sound like a knowledgeable human women's-health communicator?
- Is the tone calm, warm, and conversational?
- Is it concise rather than overly expressive?
- Does it explain rather than diagnose?
- Is the advice evidence-based?
- Is the language easy to understand?
- Are the titles engaging without being clickbait?
- Is each article genuinely actionable?
- Are the articles sufficiently different from one another?
- Did I avoid unnecessary fear, reassurance, jargon, and medical disclaimers?
- Did I avoid inventing user information?
- Is the JSON valid and does it contain every required topic?`;

        const controller = new AbortController();
        // Generating ~28 articles takes far longer than a chat reply. The
        // result is cached per user per day, so this is paid once, and the
        // static fallback below still covers a timeout.
        const timeoutId = setTimeout(() => controller.abort(), 45000);

        const aiRes = await fetch(aiChatApiUrl, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${aiChatApiKey}`,
            'Content-Type': 'application/json',
            'X-Title': 'Blushy AI Discover',
          },
          body: JSON.stringify({
            model: aiChatModel,
            messages: [{ role: 'system', content: prompt }],
            response_format: { type: 'json_object' },
            max_tokens: 16000,
          }),
          signal: controller.signal,
        });

        clearTimeout(timeoutId);

        if (aiRes.ok) {
          const aiJson = await aiRes.json();
          const contentStr = aiJson.choices?.[0]?.message?.content || '';
          const parsed = JSON.parse(contentStr);
          if (parsed.topicArticles && parsed.featuredTopic) {
            featuredTopic = parsed.featuredTopic;
            topicArticles = parsed.topicArticles;
          }
        }
      } catch (aiErr) {
        console.warn('AI Discover fetch fallback triggered:', aiErr.message);
      }
    }

    // Fallback topic articles generator if AI response was not available or incomplete
    if (Object.keys(topicArticles).length === 0) {
      topicArticles = {
        "Women's Health": [
          { title: "Balancing Daily Schedules", desc: "How tracking non-reproductive health symptoms (mood, focus, sleep) builds body awareness.", content: "Consistent symptom logging helps identify hormone sensitivity across your 28-day cycle." },
          { title: "Hormones & Lifestyle Baselines", desc: "Understanding minor endocrine cycles and adjusting exercise patterns accordingly.", content: "Dynamic rest days during luteal phases improve recovery and baseline metabolic health." }
        ],
        "Nutrition": [
          { title: "Curbing Luteal Cravings", desc: "Magnesium-rich foods to natural calm sugar spikes.", content: "Dark chocolate, pumpkin seeds, and spinach balance blood sugar naturally during PMS." },
          { title: "Hydration & Fluid Balance", desc: "How water and electrolyte intake balances bloating.", content: "Increasing potassium and hydration prevents hormonal water retention during bleeding." }
        ],
        "Exercise": [
          { title: "Syncing Workouts with Cycle", desc: "High intensity in Follicular phase vs soothing Yoga during Menstruation.", content: "Estrogen surges enable peak strength PRs in week 2." },
          { title: "Pelvic Floor & Lower Back Care", desc: "Gentle stretches designed for premenstrual tension relief.", content: "Child pose and cat-cow relieve uterine spasm pressure." }
        ],
        "Mental Wellbeing": [
          { title: "Managing PMS Mood Oscillations", desc: "Journaling prompts to separate emotional waves from reality.", content: "Acknowledge feelings without judgment during progesterone drops." },
          { title: "The Post-Ovulation Calm Routine", desc: "Slowing down sensory input for emotional balance.", content: "Reduce evening screen exposure to keep baseline anxiety low." }
        ],
        "Sleep": [
          { title: "Progesterone & Nighttime Rest", desc: "Why falling asleep is harder in the week leading up to your period.", content: "Basal body temperature increases slightly in luteal phase; cool room settings promote deep sleep." },
          { title: "Optimizing REM Sleep Cycles", desc: "Magnesium glycinate and calming rituals for hormone balance.", content: "A warm tea ritual 45 mins before bedtime boosts slow-wave sleep quality." }
        ],
        "Stress": [
          { title: "Cortisol & Progesterone Shield", desc: "How acute stress alters cycle timing and ovulation.", content: "Box breathing for 3 minutes dampens sympathetic nervous system activation." },
          { title: "Boundaries for Burnout Prevention", desc: "Protecting your calendar during high-sensitivity days.", content: "Saying no to extra evening events safeguards cortisol spikes." }
        ],
        "Productivity": [
          { title: "The Follicular Focus Peak", desc: "Planning complex tasks during high-concentration days.", content: "Schedule brain-heavy strategy sessions when estrogen is rising." },
          { title: "Luteal Phase Reflection Cycles", desc: "Slowing down output to prioritize administration and planning.", content: "Use late-cycle weeks for editing and organization rather than launching new initiatives." }
        ]
      };
    }

    const newTitles = [];
    Object.values(topicArticles).forEach(list => {
      if (Array.isArray(list)) {
        list.forEach(card => {
          if (card.title) newTitles.push(card.title);
        });
      }
    });

    if (userId && newTitles.length > 0) {
      try {
        const db = await getDb();
        await db.collection('users').updateOne(
          { _id: new ObjectId(userId) },
          { $addToSet: { seenDiscoverCardTitles: { $each: newTitles } } }
        );
      } catch (_) {}
    }

    const payload = {
      success: true,
      featuredTopic,
      topics: defaultTopics,
      topicArticles,
      isPersonalized,
      dayIndex,
      dateStr,
      lastUpdated: new Date().toISOString(),
    };

    discoverCache.set(cacheKey, payload);

    return res.status(200).json(payload);
  } catch (error) {
    next(error);
  }
}

/**
 * A reflection on what the user actually wrote in their journal.
 *
 * This used to be a fixed lookup table keyed only on life stage: it read no
 * journal, yet the app displayed it as "AI Reflection". The default asserted
 * "Estrogen is naturally rising. Your focus and mental clarity are at peak
 * rhythm today." to anyone who opened the tab, and the menopause branch went
 * further with "Your reflection logs indicate balanced energy" -- a claim to
 * have read logs it never opened.
 *
 * Two rules now hold. It is derived from the entries themselves, and it says
 * nothing about the body: spec 14 forbids displaying estimated hormone levels
 * without validated lab or device data, which Blushy does not ingest.
 */
export async function getTodayMemorySummary(req, res, next) {
  try {
    if (!req.user?.userId) {
      throw createHttpError(401, 'Authentication required to get memory summary.');
    }

    let lifeStage = 'everydayWellness';
    let userName = 'there';
    try {
      const userProfile = await userRepository.getUserById(req.user.userId);
      const answers = userProfile?.onboardingAnswers || {};
      lifeStage = answers.lifeStage || userProfile?.lifeStage || 'everydayWellness';
      userName = answers.preferred_name || userProfile?.name || 'there';
    } catch (_) {}

    const { getJournalReflection } = await import('../services/journalReflectionService.js');
    const reflection = await getJournalReflection(req.user.userId, { days: 7 });

    // Nothing written is a real answer, not a cue to compose one.
    if (!reflection) {
      return res.status(200).json({
        success: true,
        hasJournal: false,
        reflection: null,
        themes: [],
        lifeStage,
        userName,
      });
    }

    return res.status(200).json({
      success: true,
      hasJournal: true,
      reflection: reflection.reflection,
      themes: reflection.themes,
      wordCount: reflection.wordCount,
      entryCount: reflection.entryCount,
      dayCount: reflection.dayCount,
      version: reflection.version,
      lifeStage,
      userName,
    });
  } catch (error) {
    next(error);
  }
}




