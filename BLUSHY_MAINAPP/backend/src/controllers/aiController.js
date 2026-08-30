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
async function transcribeAudioFile(file) {
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

  try {
    const formData = new FormData();
    formData.append('file', new Blob([fs.readFileSync(file.path)], {
      type: file.mimetype || 'application/octet-stream',
    }), path.basename(file.originalname || `audio.${format}`));
    formData.append('model', env.speechToTextModel);
    formData.append('prompt', 'Transcribe spoken English and regional Indian languages (Hindi, Tamil, Telugu, Kannada) accurately. Ignore background noise, hums, or silence.');

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
      console.warn(`[WARN] Grok/Whisper STT failed (Status ${response.status}): ${errText}`);
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
          transcription = await transcribeAudioFile(req.file);
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
        console.error('[safety] evaluation failed for Sia chat:', safetyError.message);
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
    // has no Sia and no M Studio. There was never an answer to give.
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
      `You are Sia, giving short, practical relationship guidance to someone about ${partnerName}.`,
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
      throw createHttpError(503, 'Sia could not answer just now. Please try again shortly.', {
        code: 'AI_UNAVAILABLE',
      });
    }

    const replyText = typeof answer === 'string' ? answer : (answer?.message ?? answer?.content ?? '');
    if (!replyText || replyText.trim().length === 0) {
      throw createHttpError(503, 'Sia could not answer just now. Please try again shortly.', {
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
 * tab -- which said letters would appear once you had talked with Sia.
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
        const prompt = `You are Sia, an expert women's health and wellness AI guide for Blushy.
Today is ${dateStr} (Day ${dayIndex} of rotation cycle).
${userContext ? `User Research Context: ${userContext}` : `No specific user data available yet (Cold Start). Default 24h featured topic: "${fallbackFeaturedTopic}".`}
${seenPromptContext}

Task:
1. Recommend today's 24-hour primary featured topic from these choices: ["Women's Health", "Nutrition", "Exercise", "Mental Wellbeing", "Sleep", "Stress", "Productivity", "Cycle Health", "Movement", "Sexual Wellness", "Relationships"].
2. Generate 2 to 3 engaging, evidence-based, actionable article cards for EACH of the topics above.

Return ONLY a valid JSON object matching this exact structure:
{
  "featuredTopic": "Selected Topic Name",
  "topicArticles": {
    "Women's Health": [
      {"title": "Unique Title 1", "desc": "Short 1-2 sentence description.", "content": "Detailed educational advice..."},
      {"title": "Unique Title 2", "desc": "Short 1-2 sentence description.", "content": "Detailed educational advice..."}
    ],
    "Nutrition": [ ... ],
    ... include articles for all topics
  }
}`;

        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 5000);

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
            max_tokens: 1800,
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




