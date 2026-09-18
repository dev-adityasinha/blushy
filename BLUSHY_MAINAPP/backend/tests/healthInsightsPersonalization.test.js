import test from 'node:test';
import assert from 'node:assert/strict';
import { healthInsightsService } from '../src/services/healthInsightsService.js';

test('health insights personalization: PCOS and Endometriosis conditions generate targeted guidance', () => {
  const result = healthInsightsService.analyzeUserHealth({
    userId: 'user_pcos_endo',
    role: 'woman',
    onboardingAnswers: {
      conditions: ['PCOS', 'Endometriosis'],
      symptoms: ['Menstrual cramps', 'Fatigue / Low energy'],
    },
  });

  assert.equal(result.hasData, true);
  
  // Verify condition insights
  const pcosInsight = result.insights.find((i) => i.type === 'condition_pcos');
  assert.ok(pcosInsight, 'PCOS insight must be present');
  assert.match(pcosInsight.message, /blood sugar stability/i);

  const endoInsight = result.insights.find((i) => i.type === 'condition_endometriosis');
  assert.ok(endoInsight, 'Endo insight must be present');
  assert.match(endoInsight.message, /anti-inflammatory nutrition/i);

  // Verify symptom alerts & suggestions
  const crampAlert = result.alerts.find((a) => a.type === 'symptom_cramps');
  assert.ok(crampAlert, 'Cramp alert must be present');

  const crampSuggestion = result.suggestions.find((s) => s.type === 'cramp_relief');
  assert.ok(crampSuggestion, 'Cramp relief suggestion must be present');
  assert.match(crampSuggestion.suggestion, /heating pad|ginger/i);
});

test('health insights personalization: Pregnancy stage generates gestational week and trimester care', () => {
  // Target 20 weeks along: 280 - 140 days = 140 days until due date
  const futureDue = new Date(Date.now() + 140 * 86400000).toISOString().split('T')[0];

  const result = healthInsightsService.analyzeUserHealth({
    userId: 'user_pregnant',
    role: 'woman',
    onboardingAnswers: {
      life_stage: 'pregnancy',
      due_date: futureDue,
      symptoms: ['Nausea or morning sickness', 'Fatigue / Low energy'],
    },
  });

  assert.equal(result.hasData, true);

  const gestInsight = result.insights.find((i) => i.type === 'pregnancy_gestational_progress');
  assert.ok(gestInsight, 'Gestational progress insight must be present');
  assert.match(gestInsight.message, /Trimester 2/i);

  const t2Suggestion = result.suggestions.find((s) => s.type === 'pregnancy_trimester_2');
  assert.ok(t2Suggestion, 'Trimester 2 suggestion must be present');
  assert.match(t2Suggestion.suggestion, /pelvic floor/i);
});

test('health insights personalization: Postpartum stage with breastfeeding produces lactation hydration and lochia care', () => {
  // 3 weeks postpartum
  const pastBirth = new Date(Date.now() - 21 * 86400000).toISOString().split('T')[0];

  const result = healthInsightsService.analyzeUserHealth({
    userId: 'user_postpartum',
    role: 'woman',
    onboardingAnswers: {
      life_stage: 'postpartum',
      baby_birth_date: pastBirth,
      postpartum_feeding: 'Exclusively breastfeeding',
      symptoms: ['Postpartum lochia', 'Perineal / pelvic soreness'],
    },
  });

  assert.equal(result.hasData, true);

  const postMilestone = result.insights.find((i) => i.type === 'postpartum_milestone');
  assert.ok(postMilestone, 'Postpartum milestone must be present');
  assert.match(postMilestone.message, /week 4/i);

  const lactation = result.suggestions.find((s) => s.type === 'lactation_hydration');
  assert.ok(lactation, 'Lactation hydration suggestion must be present');
  assert.match(lactation.suggestion, /electrolytes|nursing station/i);

  const earlyHealing = result.suggestions.find((s) => s.type === 'postpartum_early_healing');
  assert.ok(earlyHealing, 'Early postpartum healing suggestion must be present');
});

test('health insights personalization: First Period Not Started offers pubertal reassurance and backup kit prep', () => {
  const result = healthInsightsService.analyzeUserHealth({
    userId: 'user_puberty',
    role: 'woman',
    onboardingAnswers: {
      life_stage: 'firstPeriodNotStarted',
      symptoms: ['White or clear discharge', 'Growing taller rapidly'],
    },
  });

  assert.equal(result.hasData, true);

  const pubInsight = result.insights.find((i) => i.type === 'puberty_milestone');
  assert.ok(pubInsight, 'Puberty milestone insight must be present');
  assert.match(pubInsight.message, /physiological leukorrhea/i);

  const pubPrep = result.suggestions.find((s) => s.type === 'puberty_prep');
  assert.ok(pubPrep, 'Puberty prep suggestion must be present');
  assert.match(pubPrep.suggestion, /school bag|two pads/i);
});
