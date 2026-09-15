/**
 * perimenopauseData.js
 * Comprehensive clinical references, transition phases, symptom action pathways,
 * and reviewed educational content for "My Transition" (Perimenopause).
 */

export const TRANSITION_PHASES = Object.freeze({
  EARLY: {
    key: 'early',
    name: 'Early Transition',
    description: 'Subtle shifts in cycle length (variable by 7+ days), occasional nighttime warmth, and emerging sleep changes.',
    markers: ['Cycle variation +/- 7 days', 'Occasional sleep disruption', 'Mild emotional shifts'],
    primaryFocus: ['Tracking cycle intervals', 'Optimizing sleep environment', 'Recognizing early indicators'],
  },
  ACTIVE: {
    key: 'active',
    name: 'Active Perimenopause',
    description: 'Noticeable hormone fluctuations, recurring vasomotor hot flashes or night sweats, variable bleeding flow, and brain fog.',
    markers: ['Skipped periods or spaced cycles', 'Hot flashes & night sweats', 'Brain fog & fatigue', 'Vaginal dryness or sensitivity'],
    primaryFocus: ['Vasomotor trigger management', 'Bedtime cooling routines', 'Doctor question preparation', 'Intimate health comfort'],
  },
  LATE: {
    key: 'late',
    name: 'Late Transition',
    description: 'Marked cycle spacing (periods skipped for 60+ days), significant estrogen shifts, and preparing for the 12-month menopause milestone.',
    markers: ['Cycles spaced 60+ days apart', 'Altered bone & metabolic markers', 'Pronounced temperature flushes'],
    primaryFocus: ['Bone density & resistance exercise', 'Cardiovascular health', 'Longitudinal physician reviews', 'Treatment & HRT discussion'],
  },
  STEADY: {
    key: 'steady',
    name: 'Rhythm Stabilization',
    description: 'Hormonal swings have leveled or symptom coping strategies are active and effective.',
    markers: ['Low symptom volatility', 'Consistent restorative sleep', 'Balanced daily vitality'],
    primaryFocus: ['Sustaining wellness habits', 'Strength and balance', 'Celebrating equilibrium'],
  },
});

export const ACTION_PATHWAYS = Object.freeze({
  sleep: {
    title: 'Sleep & Night Sweats',
    icon: 'nightlight_round',
    colorHex: '0xFF7209B7',
    bgHex: '0xFFF3E8FF',
    actions: [
      {
        id: 'cool_bedroom',
        headline: 'Drop bedroom thermostat to 18–19°C',
        reason: 'Cooler ambient air buffers the hypothalamus from triggering night sweats.',
        difficulty: 'Easy',
      },
      {
        id: 'breathable_bedding',
        headline: 'Switch to breathable bamboo or linen sheets',
        reason: 'Moisture-wicking natural fabrics prevent heat entrapment when night sweats occur.',
        difficulty: 'Medium',
      },
      {
        id: 'caffeine_curfew',
        headline: 'Set a 2 PM caffeine cutoff',
        reason: 'Adenosine receptors are more sensitive to caffeine during progesterone dips.',
        difficulty: 'Easy',
      },
    ],
  },
  temperature: {
    title: 'Hot Flashes & Temperature',
    icon: 'local_fire_department_rounded',
    colorHex: '0xFFDD0D22',
    bgHex: '0xFFFFECEB',
    actions: [
      {
        id: 'layer_clothing',
        headline: 'Wear light natural-fiber layers',
        reason: 'Allows rapid temperature shedding as soon as a flush onset is sensed.',
        difficulty: 'Easy',
      },
      {
        id: 'cold_water_sip',
        headline: 'Keep an insulated cold tumbler nearby',
        reason: 'Sipping ice-cold water at the very first aura can sometimes truncate a flare.',
        difficulty: 'Easy',
      },
      {
        id: 'identify_triggers',
        headline: 'Notice alcohol, spicy foods, or sudden stress',
        reason: 'These stimulate peripheral vasodilation and provoke immediate flushes.',
        difficulty: 'Medium',
      },
    ],
  },
  mind: {
    title: 'Mood & Brain Fog',
    icon: 'psychology_rounded',
    colorHex: '0xFFF72585',
    bgHex: '0xFFFFE5F0',
    actions: [
      {
        id: 'brain_dump',
        headline: 'Keep a quick notepad for mid-day thoughts',
        reason: 'Offloads cognitive working memory load when estrogen fluctuations affect word retrieval.',
        difficulty: 'Easy',
      },
      {
        id: 'morning_light',
        headline: '10 minutes of direct morning sunlight',
        reason: 'Anchors circadian cortisol and supports daytime serotonin synthesis.',
        difficulty: 'Easy',
      },
      {
        id: 'micro_pause',
        headline: 'Take a 3-minute slow exhale break',
        reason: 'Resets the autonomic nervous system during sudden emotional surges.',
        difficulty: 'Easy',
      },
    ],
  },
  intimate: {
    title: 'Intimate Health & Comfort',
    icon: 'favorite_rounded',
    colorHex: '0xFF0D9488',
    bgHex: '0xFFCCFBF1',
    actions: [
      {
        id: 'hyaluronic_moisturizer',
        headline: 'Consider a regular hyaluronic acid vaginal moisturizer',
        reason: 'Non-hormonal moisture restores tissue elasticity and relieves daily chafing.',
        difficulty: 'Easy',
      },
      {
        id: 'gentle_cleansing',
        headline: 'Use warm water only (avoid fragranced soaps)',
        reason: 'Alkaline soaps disrupt vaginal flora and aggravate dryness.',
        difficulty: 'Easy',
      },
      {
        id: 'discuss_topical_estrogen',
        headline: 'Ask doctor about local topical estrogen cream',
        reason: 'Has minimal systemic absorption and directly rejuvenates urogenital tissue.',
        difficulty: 'Medium',
      },
    ],
  },
  cycle: {
    title: 'Changing Periods & Flow',
    icon: 'water_drop_rounded',
    colorHex: '0xFF2563EB',
    bgHex: '0xFFDBEAFE',
    actions: [
      {
        id: 'emergency_pouch',
        headline: 'Keep an on-the-go backup kit in your bag',
        reason: 'Irregular cycles can arrive with zero prior warning.',
        difficulty: 'Easy',
      },
      {
        id: 'track_heaviness',
        headline: 'Note pad change frequency during heavy days',
        reason: 'Clinicians look for soaking through 2+ pads/hr as an indicator to investigate.',
        difficulty: 'Easy',
      },
      {
        id: 'iron_rich_foods',
        headline: 'Include spinach, lentils, and vitamin C',
        reason: 'Replenishes ferritin stores after heavy or prolonged menstrual bleeding.',
        difficulty: 'Medium',
      },
    ],
  },
});

export const CLINICIAN_DISCUSSION_TOPICS = Object.freeze([
  {
    id: 'hrt_eligibility',
    topic: 'Hormone Replacement Therapy (HRT / MHT)',
    summary: 'Evaluating benefits, timing window (within 10 years of transition), and safety profile.',
    keyQuestions: [
      'Am I a candidate for HRT based on my symptom burden and family medical history?',
      'What are the differences between transdermal estradiol and oral options?',
      'Do I need micronized progesterone to protect my uterine lining?',
    ],
  },
  {
    id: 'cycle_investigation',
    topic: 'Heavy or Irregular Menstrual Bleeding',
    summary: 'Differentiating normal perimenopausal anovulation from fibroids, polyps, or hyperplasia.',
    keyQuestions: [
      'Are my current bleeding changes typical for my stage of perimenopause?',
      'Should we check my iron / ferritin levels or perform a pelvic ultrasound?',
      'At what bleeding threshold should I seek urgent clinical evaluation?',
    ],
  },
  {
    id: 'urogenital_health',
    topic: 'Genitourinary Symptoms of Menopause (GSM)',
    summary: 'Addressing vaginal dryness, painful intimacy, or recurrent urinary urgency.',
    keyQuestions: [
      'Is local vaginal estrogen safe for long-term comfort?',
      'Could my recurring bladder discomfort be linked to tissue estrogen changes?',
    ],
  },
  {
    id: 'bone_metabolic',
    topic: 'Bone Density & Cardiovascular Screening',
    summary: 'Assessing lipid shifts and baseline bone mineral status as estrogen drops.',
    keyQuestions: [
      'When should I schedule my first DEXA bone density scan?',
      'Should we check my cholesterol / lipid profile given midlife hormonal shifts?',
    ],
  },
]);

export const CONTEXTUAL_ARTICLES = Object.freeze([
  {
    id: 'the_perimenopause_transition',
    title: 'The Perimenopause Transition',
    readTime: '4 min read',
    topic: 'Understanding',
    summary: 'What actually happens inside your ovaries and hypothalamus as cycle spacing changes.',
    badge: 'Core Guide',
    colorHex: '0xFF0D9488',
    bgHex: '0xFFCCFBF1',
  },
  {
    id: 'science_of_vasomotor_symptoms',
    title: 'Science of Vasomotor Symptoms',
    readTime: '3 min read',
    topic: 'Temperature',
    summary: 'Why sudden estrogen drops trick your brain into triggering full cooling flushes.',
    badge: 'Clinical Evidence',
    colorHex: '0xFFDD0D22',
    bgHex: '0xFFFFECEB',
  },
  {
    id: 'tackling_sleep_fragmentation',
    title: 'Tackling Sleep Fragmentation',
    readTime: '5 min read',
    topic: 'Sleep',
    summary: 'Why progesterone loss impairs melatonin release, and practical ways to protect deep sleep.',
    badge: 'Practical Protocol',
    colorHex: '0xFF7209B7',
    bgHex: '0xFFF3E8FF',
  },
  {
    id: 'estrogen_progesterone_fluctuations',
    title: 'Estrogen & Progesterone Swings',
    readTime: '4 min read',
    topic: 'Hormones',
    summary: 'Understanding the roller-coaster hormone swings behind unexpected irritability and fatigue.',
    badge: 'Biology',
    colorHex: '0xFFF72585',
    bgHex: '0xFFFFE5F0',
  },
  {
    id: 'maintaining_bone_mineral_density',
    title: 'Protecting Bone Density in Midlife',
    readTime: '4 min read',
    topic: 'Bone Health',
    summary: 'Why estrogen declines accelerate bone loss, and the proven power of resistance exercises.',
    badge: 'Longevity',
    colorHex: '0xFF2563EB',
    bgHex: '0xFFDBEAFE',
  },
  {
    id: 'coping_with_night_sweats',
    title: 'Coping with Night Sweats',
    readTime: '3 min read',
    topic: 'Sleep',
    summary: 'Sleep hygiene, fabric choices, and immediate cooling steps when waking drenched.',
    badge: 'Night Guide',
    colorHex: '0xFFD97706',
    bgHex: '0xFFFEF3C7',
  },
]);
