/**
 * Deterministic red flag / safety engine (spec §15 "Pregnancy Safety",
 * §22 "AI Architecture", §26 "AI MUST NOT BE RESPONSIBLE FOR ... Red flag
 * detection").
 *
 * Rules are data, not generated text. Every rule carries a version, a review
 * status and a reviewer so it can be audited and emergency-retired. AI cannot
 * override these outputs; the safety layer runs *after* any AI generation and
 * before a response leaves the server.
 *
 * Pure module: no database, no network, so critical safety guidance never
 * depends solely on a network request (spec §25).
 */

export const RED_FLAG_RULESET_VERSION = 'redflag-v1.0.0';

export const ESCALATION_LEVELS = Object.freeze({
  EMERGENCY: 'emergency',        // seek emergency care now
  URGENT: 'urgent',              // contact provider today
  CONTACT_PROVIDER: 'contact_provider', // contact provider soon
  MONITOR: 'monitor',            // keep an eye on it
});

const LEVEL_RANK = {
  [ESCALATION_LEVELS.MONITOR]: 1,
  [ESCALATION_LEVELS.CONTACT_PROVIDER]: 2,
  [ESCALATION_LEVELS.URGENT]: 3,
  [ESCALATION_LEVELS.EMERGENCY]: 4,
};

/**
 * Every rule: id, applicable life stages, deterministic match, escalation
 * level, the reviewed instruction shown to the user, and review metadata.
 *
 * `instruction` text is intentionally stored here (not AI-generated) so it can
 * be shown offline. `contentId` points at the fuller reviewed article.
 */
export const RED_FLAG_RULES = Object.freeze([
  // ---------------- Pregnancy ----------------
  {
    id: 'rf_pg_heavy_bleeding',
    lifeStages: ['pregnancy'],
    symptoms: ['heavy bleeding', 'vaginal bleeding', 'bleeding', 'soaking pad'],
    minSeverity: null,
    level: ESCALATION_LEVELS.EMERGENCY,
    title: 'Bleeding during pregnancy',
    instruction: 'Vaginal bleeding in pregnancy needs to be assessed straight away. Contact your maternity unit or emergency services now.',
    contentId: 'mc_pregnancy_redflag_bleeding',
    source: 'NICE NG121 / WHO antenatal care guidance',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
  },
  {
    id: 'rf_pg_severe_headache_vision',
    lifeStages: ['pregnancy'],
    symptoms: ['severe headache', 'blurred vision', 'vision changes', 'seeing spots', 'flashing lights'],
    minSeverity: null,
    level: ESCALATION_LEVELS.EMERGENCY,
    title: 'Severe headache or vision changes',
    instruction: 'A severe headache or sudden vision changes after 20 weeks can be a sign of pre-eclampsia. Contact your maternity unit or emergency services now.',
    contentId: 'mc_pregnancy_redflag_preeclampsia',
    source: 'NICE NG133 hypertension in pregnancy',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
  },
  {
    id: 'rf_pg_reduced_movements',
    lifeStages: ['pregnancy'],
    symptoms: ['reduced movement', 'no movement', 'baby not moving', 'less movement'],
    minSeverity: null,
    minGestationalWeek: 24,
    level: ESCALATION_LEVELS.EMERGENCY,
    title: 'Reduced fetal movements',
    instruction: 'Reduced or changed movements should always be checked the same day. Contact your maternity unit now - do not wait until your next appointment.',
    contentId: 'mc_pregnancy_redflag_movements',
    source: 'RCOG Green-top Guideline No. 57',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
  },
  {
    id: 'rf_pg_severe_abdominal_pain',
    lifeStages: ['pregnancy'],
    symptoms: ['abdominal pain', 'severe cramping', 'stomach pain', 'constant pain'],
    minSeverity: 7,
    level: ESCALATION_LEVELS.EMERGENCY,
    title: 'Severe abdominal pain in pregnancy',
    instruction: 'Severe or constant abdominal pain in pregnancy needs urgent assessment. Contact your maternity unit or emergency services now.',
    contentId: 'mc_pregnancy_redflag_abdominal_pain',
    source: 'NICE NG121',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
  },
  {
    id: 'rf_pg_fluid_leak',
    lifeStages: ['pregnancy'],
    symptoms: ['waters broke', 'fluid leaking', 'leaking fluid', 'water leaking'],
    minSeverity: null,
    level: ESCALATION_LEVELS.URGENT,
    title: 'Fluid leaking',
    instruction: 'Contact your maternity unit today so they can check whether your waters have broken.',
    contentId: 'mc_pregnancy_redflag_fluid',
    source: 'NICE NG121',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
  },
  {
    id: 'rf_pg_fever',
    lifeStages: ['pregnancy', 'postpartum'],
    symptoms: ['fever', 'high temperature', 'chills'],
    minSeverity: null,
    level: ESCALATION_LEVELS.URGENT,
    title: 'Fever',
    instruction: 'A fever during pregnancy or after birth should be assessed today. Contact your provider or maternity unit.',
    contentId: 'mc_perinatal_redflag_fever',
    source: 'WHO postnatal care guidance',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
  },

  // ---------------- Postpartum ----------------
  {
    id: 'rf_pp_heavy_bleeding',
    lifeStages: ['postpartum'],
    symptoms: ['heavy bleeding', 'soaking pad', 'large clots', 'bleeding'],
    minSeverity: null,
    level: ESCALATION_LEVELS.EMERGENCY,
    title: 'Heavy bleeding after birth',
    instruction: 'Soaking a pad in under an hour, or passing large clots, needs emergency assessment. Contact emergency services now.',
    contentId: 'mc_postpartum_redflag_haemorrhage',
    source: 'WHO postnatal care guidance',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
  },
  {
    id: 'rf_pp_calf_pain_breathlessness',
    lifeStages: ['pregnancy', 'postpartum'],
    symptoms: ['calf pain', 'leg swelling', 'chest pain', 'shortness of breath', 'breathless'],
    minSeverity: null,
    level: ESCALATION_LEVELS.EMERGENCY,
    title: 'Possible clot symptoms',
    instruction: 'Calf pain, chest pain or breathlessness can indicate a blood clot. Seek emergency care now.',
    contentId: 'mc_perinatal_redflag_vte',
    source: 'RCOG Green-top Guideline No. 37b',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
  },

  // ---------------- Mental health (all stages) ----------------
  {
    id: 'rf_mh_self_harm',
    lifeStages: null, // all stages
    symptoms: ['suicidal', 'self harm', 'end my life', 'kill myself', 'hurt myself', 'no reason to live'],
    minSeverity: null,
    level: ESCALATION_LEVELS.EMERGENCY,
    title: 'Thoughts of self-harm',
    instruction: 'You deserve support right now. Please contact your local emergency number or a crisis line straight away, or reach someone you trust and stay with them.',
    contentId: 'mc_mentalhealth_crisis',
    source: 'WHO mhGAP intervention guide',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
    suppressesWellnessContent: true,
  },
  {
    id: 'rf_mh_harm_to_baby',
    lifeStages: ['postpartum'],
    symptoms: ['hurt the baby', 'harm my baby', 'harm the baby'],
    minSeverity: null,
    level: ESCALATION_LEVELS.EMERGENCY,
    title: 'Thoughts of harm',
    instruction: 'These thoughts are more common than people realise and they are treatable. Please contact your provider or local emergency number now, and stay with someone you trust.',
    contentId: 'mc_postpartum_crisis',
    source: 'WHO mhGAP intervention guide',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
    suppressesWellnessContent: true,
  },

  // ---------------- Gynaecological ----------------
  {
    id: 'rf_gyn_severe_pelvic_pain',
    lifeStages: ['cycle_tracking', 'hormonal_health', 'ttc', 'perimenopause', 'everyday_wellness', 'first_period'],
    symptoms: ['pelvic pain', 'severe cramps', 'unbearable pain', 'cramps'],
    minSeverity: 9,
    level: ESCALATION_LEVELS.URGENT,
    title: 'Severe pelvic pain',
    instruction: 'Pain at this level that stops you functioning should be assessed by a clinician today.',
    contentId: 'mc_gyn_redflag_pelvic_pain',
    source: 'NICE NG73 endometriosis',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
  },
  {
    id: 'rf_gyn_postmenopausal_bleeding',
    lifeStages: ['menopause'],
    symptoms: ['bleeding', 'spotting', 'vaginal bleeding'],
    minSeverity: null,
    level: ESCALATION_LEVELS.URGENT,
    title: 'Bleeding after menopause',
    instruction: 'Any bleeding after menopause should always be checked by a clinician. Please arrange an appointment promptly.',
    contentId: 'mc_menopause_redflag_bleeding',
    source: 'NICE NG12 suspected cancer referral',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
  },
  {
    id: 'rf_gyn_prolonged_bleeding',
    lifeStages: ['cycle_tracking', 'hormonal_health', 'ttc', 'perimenopause', 'first_period', 'everyday_wellness'],
    symptoms: ['bleeding for weeks', 'prolonged bleeding', 'flooding', 'soaking pad'],
    minSeverity: null,
    level: ESCALATION_LEVELS.CONTACT_PROVIDER,
    title: 'Prolonged or very heavy bleeding',
    instruction: 'Bleeding that is unusually heavy or lasts longer than usual should be reviewed by a clinician.',
    contentId: 'mc_gyn_redflag_heavy_bleeding',
    source: 'NICE NG88 heavy menstrual bleeding',
    reviewer: 'Blushy Clinical Review Board',
    reviewDate: '2025-08-14',
    version: '1.0.0',
    status: 'approved',
  },
]);

function normalizeText(value) {
  return String(value ?? '').toLowerCase().replace(/\s+/g, ' ').trim();
}

function ruleApplies(rule, lifeStage) {
  if (!rule.lifeStages) return true;
  return rule.lifeStages.includes(lifeStage);
}

/**
 * Evaluate red flags against structured inputs.
 *
 * @param {object} input
 * @param {string} input.lifeStage        normalized life stage key
 * @param {Array}  input.symptoms         [{ symptom, severity }] from health events
 * @param {string} input.freeText         journal / Dr. Docsy message text to scan
 * @param {number} input.gestationalWeek  when known
 * @returns {{ triggered: boolean, level: string|null, rules: Array, suppressWellnessContent: boolean, rulesetVersion: string, evaluatedAt: string }}
 */
export function evaluateRedFlags({ lifeStage = null, symptoms = [], freeText = '', gestationalWeek = null } = {}) {
  const haystackParts = [normalizeText(freeText)];
  const severityBySymptom = new Map();

  for (const entry of Array.isArray(symptoms) ? symptoms : []) {
    const name = normalizeText(entry?.symptom ?? entry);
    if (!name) continue;
    haystackParts.push(name);
    const severity = Number(entry?.severity);
    if (Number.isFinite(severity)) {
      severityBySymptom.set(name, Math.max(severityBySymptom.get(name) ?? -1, severity));
    }
  }

  const haystack = haystackParts.filter(Boolean).join(' | ');
  const matched = [];

  for (const rule of RED_FLAG_RULES) {
    if (rule.status !== 'approved') continue;
    if (!ruleApplies(rule, lifeStage)) continue;

    if (rule.minGestationalWeek !== undefined && rule.minGestationalWeek !== null) {
      if (gestationalWeek === null || gestationalWeek === undefined || gestationalWeek < rule.minGestationalWeek) {
        continue;
      }
    }

    const hitTerm = rule.symptoms.find((term) => haystack.includes(normalizeText(term)));
    if (!hitTerm) continue;

    if (rule.minSeverity !== null && rule.minSeverity !== undefined) {
      // A severity-gated rule needs an explicit logged severity at or above the
      // threshold. Free text alone never satisfies it - that would be inference.
      let severityMet = false;
      for (const term of rule.symptoms) {
        const normalized = normalizeText(term);
        for (const [name, severity] of severityBySymptom.entries()) {
          if (name.includes(normalized) && severity >= rule.minSeverity) {
            severityMet = true;
            break;
          }
        }
        if (severityMet) break;
      }
      if (!severityMet) continue;
    }

    matched.push({
      ruleId: rule.id,
      title: rule.title,
      level: rule.level,
      instruction: rule.instruction,
      contentId: rule.contentId,
      matchedTerm: hitTerm,
      source: rule.source,
      reviewer: rule.reviewer,
      reviewDate: rule.reviewDate,
      ruleVersion: rule.version,
      suppressesWellnessContent: Boolean(rule.suppressesWellnessContent),
    });
  }

  matched.sort((a, b) => (LEVEL_RANK[b.level] ?? 0) - (LEVEL_RANK[a.level] ?? 0));

  const highest = matched[0]?.level ?? null;
  const suppressWellnessContent = matched.length > 0 && (
    highest === ESCALATION_LEVELS.EMERGENCY || matched.some((m) => m.suppressesWellnessContent)
  );

  return {
    triggered: matched.length > 0,
    level: highest,
    rules: matched,
    suppressWellnessContent,
    rulesetVersion: RED_FLAG_RULESET_VERSION,
    evaluatedAt: new Date().toISOString(),
  };
}

/**
 * Location-aware emergency and support resources (spec §15: "do not hardcode
 * one country's number"). Region is resolved from the user profile / locale;
 * `default` is used only when the region is genuinely unknown, and it tells the
 * user to use their own local number rather than inventing one.
 */
export const EMERGENCY_RESOURCES = Object.freeze({
  IN: {
    region: 'IN',
    emergencyNumber: '112',
    labels: { emergency: 'Emergency services (112)' },
    resources: [
      { id: 'in_emergency', name: 'National Emergency Number', contact: '112', type: 'emergency' },
      { id: 'in_ambulance', name: 'Ambulance', contact: '108', type: 'emergency' },
      { id: 'in_mental_health', name: 'Tele-MANAS mental health helpline', contact: '14416', type: 'mental_health' },
      { id: 'in_women', name: 'Women helpline', contact: '181', type: 'support' },
    ],
  },
  US: {
    region: 'US',
    emergencyNumber: '911',
    labels: { emergency: 'Emergency services (911)' },
    resources: [
      { id: 'us_emergency', name: 'Emergency services', contact: '911', type: 'emergency' },
      { id: 'us_988', name: 'Suicide & Crisis Lifeline', contact: '988', type: 'mental_health' },
      { id: 'us_postpartum', name: 'Postpartum Support International Helpline', contact: '1-800-944-4773', type: 'mental_health' },
    ],
  },
  GB: {
    region: 'GB',
    emergencyNumber: '999',
    labels: { emergency: 'Emergency services (999)' },
    resources: [
      { id: 'gb_emergency', name: 'Emergency services', contact: '999', type: 'emergency' },
      { id: 'gb_nhs111', name: 'NHS 111', contact: '111', type: 'urgent_care' },
      { id: 'gb_samaritans', name: 'Samaritans', contact: '116 123', type: 'mental_health' },
    ],
  },
  EU: {
    region: 'EU',
    emergencyNumber: '112',
    labels: { emergency: 'Emergency services (112)' },
    resources: [
      { id: 'eu_emergency', name: 'European emergency number', contact: '112', type: 'emergency' },
    ],
  },
  AU: {
    region: 'AU',
    emergencyNumber: '000',
    labels: { emergency: 'Emergency services (000)' },
    resources: [
      { id: 'au_emergency', name: 'Emergency services', contact: '000', type: 'emergency' },
      { id: 'au_lifeline', name: 'Lifeline', contact: '13 11 14', type: 'mental_health' },
      { id: 'au_panda', name: 'PANDA perinatal helpline', contact: '1300 726 306', type: 'mental_health' },
    ],
  },
  default: {
    region: 'default',
    emergencyNumber: null,
    labels: { emergency: 'Your local emergency number' },
    resources: [
      {
        id: 'default_emergency',
        name: 'Local emergency services',
        contact: null,
        type: 'emergency',
        note: 'Use your country emergency number. Add your region in settings so Blushy can show it directly.',
      },
    ],
  },
});

const EU_REGIONS = new Set(['DE', 'FR', 'ES', 'IT', 'NL', 'BE', 'PT', 'IE', 'AT', 'SE', 'DK', 'FI', 'PL', 'CZ', 'GR', 'RO', 'HU']);

export function getEmergencyResources(region) {
  const code = typeof region === 'string' ? region.trim().toUpperCase() : '';
  if (!code) return EMERGENCY_RESOURCES.default;
  if (EMERGENCY_RESOURCES[code]) return EMERGENCY_RESOURCES[code];
  if (EU_REGIONS.has(code)) return EMERGENCY_RESOURCES.EU;
  return EMERGENCY_RESOURCES.default;
}

/**
 * Derives a region code from an explicit profile region or a locale string
 * such as `en-IN`. Returns null when it genuinely cannot tell.
 */
export function resolveRegion({ region, locale, timezone } = {}) {
  if (typeof region === 'string' && region.trim()) return region.trim().toUpperCase();
  if (typeof locale === 'string') {
    const match = /[-_]([A-Za-z]{2})$/.exec(locale.trim());
    if (match) return match[1].toUpperCase();
  }
  if (typeof timezone === 'string') {
    if (timezone.startsWith('Asia/Kolkata') || timezone.startsWith('Asia/Calcutta')) return 'IN';
    if (timezone.startsWith('Europe/London')) return 'GB';
    if (timezone.startsWith('Australia/')) return 'AU';
    if (timezone.startsWith('America/')) return 'US';
    if (timezone.startsWith('Europe/')) return 'EU';
  }
  return null;
}

/**
 * Final gate applied to every AI response before it leaves the server
 * (spec §22: "AI cannot override deterministic safety rules").
 */
export function applySafetyGate({ aiOutput, redFlagResult, emergencyResources }) {
  if (!redFlagResult?.triggered) {
    return { blocked: false, output: aiOutput, safety: null };
  }

  if (!redFlagResult.suppressWellnessContent) {
    return {
      blocked: false,
      output: aiOutput,
      safety: {
        level: redFlagResult.level,
        rules: redFlagResult.rules,
        rulesetVersion: redFlagResult.rulesetVersion,
        resources: emergencyResources ?? null,
      },
    };
  }

  // Emergency: ordinary wellness recommendations are suppressed entirely and
  // replaced with the reviewed instruction.
  return {
    blocked: true,
    output: {
      type: 'safety_escalation',
      title: redFlagResult.rules[0].title,
      body: redFlagResult.rules[0].instruction,
      contentId: redFlagResult.rules[0].contentId,
      source: 'medical_reference',
    },
    safety: {
      level: redFlagResult.level,
      rules: redFlagResult.rules,
      rulesetVersion: redFlagResult.rulesetVersion,
      resources: emergencyResources ?? null,
    },
  };
}
