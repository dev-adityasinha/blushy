/**
 * postpartumSafetyService.js
 * Clinical safety engine, red flag detection, and emergency interruption triage.
 */

export class PostpartumSafetyService {
  /**
   * Evaluates symptoms for emergency or urgent clinical escalation.
   */
  static evaluateSafety({
    bleedingLevel,
    clotSize,
    padSaturationHours,
    hasSevereHeadache,
    hasVisualChanges,
    feverTempF,
    incisionCondition,
    calfPainUnilateral,
    chestPainOrShortBreath,
    mood,
    harmThoughts,
    epdsScore,
  }) {
    const flags = [];
    let severity = 'low'; // 'low' | 'moderate' | 'urgent' | 'emergency'

    // 1. Postpartum Hemorrhage (PPH)
    if (padSaturationHours && Number(padSaturationHours) <= 1 && bleedingLevel === 'heavy') {
      flags.push({
        code: 'PPH_SATURATION',
        title: 'Possible Postpartum Hemorrhage',
        detail: 'Soaking through one or more large maternity pads per hour is a critical indicator of excessive uterine bleeding.',
        action: 'Seek emergency medical attention or call emergency services immediately.',
        level: 'emergency',
      });
      severity = 'emergency';
    }

    if (clotSize === 'golf_ball_or_larger' || clotSize === 'large') {
      flags.push({
        code: 'PPH_CLOT',
        title: 'Large Blood Clots Detected',
        detail: 'Passing blood clots larger than a golf ball requires urgent clinical evaluation of uterine contraction.',
        action: 'Contact your OB/GYN, midwife, or maternity triage unit immediately.',
        level: 'urgent',
      });
      if (severity !== 'emergency') severity = 'urgent';
    }

    // 2. Postpartum Preeclampsia
    if (hasSevereHeadache && hasVisualChanges) {
      flags.push({
        code: 'PREECLAMPSIA_NEURO',
        title: 'Neurological Preeclampsia Warning Signs',
        detail: 'A severe, throbbing headache combined with blurred vision or seeing spots/flashes can signal sudden hypertensive spike.',
        action: 'Proceed to the nearest Emergency Room or maternity assessment center right away.',
        level: 'emergency',
      });
      severity = 'emergency';
    } else if (hasSevereHeadache) {
      flags.push({
        code: 'HEADACHE_PERSISTENT',
        title: 'Persistent Severe Headache',
        detail: 'Headaches that do not respond to ordinary pain relief require blood pressure measurement in postpartum mothers.',
        action: 'Check your blood pressure and contact your maternity triage line.',
        level: 'urgent',
      });
      if (severity === 'low') severity = 'urgent';
    }

    // 3. Infection / Sepsis
    if (feverTempF && Number(feverTempF) >= 100.4) {
      flags.push({
        code: 'FEVER_INFECTION',
        title: 'Postpartum Fever (>= 100.4°F / 38°C)',
        detail: 'Fever in the weeks following birth can indicate uterine infection (endometritis), incision infection, or mastitis.',
        action: 'Contact your healthcare provider promptly for clinical evaluation and possible antibiotic therapy.',
        level: 'urgent',
      });
      if (severity === 'low') severity = 'urgent';
    }

    if (incisionCondition === 'pus' || incisionCondition === 'opening' || incisionCondition === 'red_spreading') {
      flags.push({
        code: 'INCISION_INFECTION',
        title: 'Incision Healing Complication',
        detail: 'Drainage, wound separation, or spreading warmth/redness requires urgent inspection.',
        action: 'Do not squeeze or apply ointments; see your obstetric team today.',
        level: 'urgent',
      });
      if (severity === 'low') severity = 'urgent';
    }

    // 4. Thromboembolism (DVT / PE)
    if (chestPainOrShortBreath) {
      flags.push({
        code: 'PE_CARDIOPULMONARY',
        title: 'Sudden Chest Pain or Shortness of Breath',
        detail: 'New mothers are at heightened risk for pulmonary embolism during the first 6 weeks postpartum.',
        action: 'Call emergency services (911 / local emergency number) immediately.',
        level: 'emergency',
      });
      severity = 'emergency';
    }

    if (calfPainUnilateral) {
      flags.push({
        code: 'DVT_CALF',
        title: 'Unilateral Swelling or Pain in One Leg',
        detail: 'Swelling, heat, or pain in only one calf can indicate a deep vein blood clot.',
        action: 'Urgent medical examination required today. Avoid rubbing or massaging the calf.',
        level: 'urgent',
      });
      if (severity !== 'emergency') severity = 'urgent';
    }

    // 5. Mental Health Crisis / Severe PPD
    if (harmThoughts === true || (epdsScore && Number(epdsScore) >= 13)) {
      flags.push({
        code: 'PPD_CRISIS',
        title: 'Emotional Support & Crisis Care',
        detail: 'You are carrying an immense hormonal and emotional load right now. You do not have to carry this alone.',
        action: 'Immediate 24/7 confidential postpartum support is available.',
        level: 'urgent',
        contacts: [
          { name: 'National Maternal Mental Health Hotline', phone: '1-833-834-4536' },
          { name: 'Crisis Text Line', text: 'HOME to 741741' },
          { name: 'Postpartum Support International (PSI)', phone: '1-800-944-4773' },
        ],
      });
      if (severity === 'low') severity = 'urgent';
    }

    const shouldInterrupt = severity === 'emergency' || severity === 'urgent';

    return {
      severity,
      shouldInterrupt,
      flags,
      hasConcerns: flags.length > 0,
      timestamp: new Date().toISOString(),
    };
  }
}
