/**
 * postpartumData.js
 * Comprehensive clinical references, recovery milestones, lochia staging,
 * "Can I do this yet?" guidance, and educational micro-reads for the 4th Trimester.
 */

export const POSTPARTUM_PHASES = Object.freeze({
  IMMEDIATE: {
    key: 'immediate',
    name: 'Immediate Recovery',
    range: 'Days 1 – 7',
    description: 'Initial acute physiological healing, milk coming in, dramatic hormonal shift, and lochia rubra.',
    primaryFocus: ['Rest & horizontal healing', 'Lochia monitoring', 'Colostrum & lactation onset', 'Perineal / C-section care'],
  },
  EARLY: {
    key: 'early',
    name: 'Early Healing',
    range: 'Days 8 – 42 (Weeks 2 – 6)',
    description: 'Tissue rebuilding, lochia serosa transitions, emotional recalibration, and emerging newborn rhythm.',
    primaryFocus: ['Pelvic floor rest & breath', 'Baby blues vs PPD screening', 'Incision scar settling', 'Gentle walking'],
  },
  EXTENDED: {
    key: 'extended',
    name: 'Extended 4th Trimester',
    range: 'Weeks 7 – 24 (Months 2 – 6)',
    description: 'Core rehabilitation, hormonal stabilization, sleep debt navigation, and pediatric milestones.',
    primaryFocus: ['Postnatal clinical clearance', 'Progressive core strength', 'Maternal mental stamina', 'Feeding rhythm'],
  },
  TRANSITION: {
    key: 'transition',
    name: 'Transition to Motherhood',
    range: 'Months 6 – 12',
    description: 'Long-term tissue restoration, possible return of menstrual cycle, complementary feeding, and maternal identity.',
    primaryFocus: ['Joint & ligament stabilization', 'Weaning or sustained feeding', 'Emotional integration', 'Long-term vitality'],
  },
});

export const LOCHIA_STAGES = Object.freeze({
  RUBRA: {
    stage: 'Lochia Rubra',
    days: 'Days 1 – 4',
    color: 'Dark Red / Crimson',
    expectedFlow: 'Moderate to heavy with small dime-sized clots.',
    guidance: 'Expected right after birth as the placental site contracts. Frequent pad changes and horizontal rest help prevent surges.',
    redFlags: 'Soaking more than one large pad per hour for 2+ consecutive hours, or passing clots larger than a golf ball.',
  },
  SEROSA: {
    stage: 'Lochia Serosa',
    days: 'Days 5 – 10 (up to Day 14)',
    color: 'Pinkish / Brown / Watery',
    expectedFlow: 'Lighter consistency, less active blood.',
    guidance: 'Shows active tissue healing. If bleeding suddenly returns to bright red heavy flow, your body is signalling for you to slow down physical activity.',
    redFlags: 'Foul-smelling discharge, sudden fever, or sudden return of heavy bright red bleeding with cramping.',
  },
  ALBA: {
    stage: 'Lochia Alba',
    days: 'Weeks 2 – 6',
    color: 'Yellowish-white / Cream',
    expectedFlow: 'Scant discharge consisting of mucus and healing tissue.',
    guidance: 'The final phase of uterine lining renewal. Light panty liners are usually sufficient.',
    redFlags: 'Persistent burning with urination, pelvic pain, or discharge accompanied by fever (>100.4°F / 38°C).',
  },
});

export const RECOVERY_MILESTONES = Object.freeze([
  {
    day: 1,
    title: 'Welcome Home & The Golden Rest',
    vaginal: 'Focus on horizontal rest, ice packs/witch hazel for perineal comfort, and gentle hydration.',
    cesarean: 'Prioritize wound splinting when coughing/laughing, scheduled analgesia, and slow assisted walking.',
  },
  {
    day: 3,
    title: 'Hormonal Reset & Milk Transition',
    vaginal: 'Dramatic estrogen/progesterone drop. Tearfulness ("Baby Blues") is completely physiological. Warm showers help breast engorgement.',
    cesarean: 'Incision begins superficial sealing. Gas pains can peak today; gentle walking and hydration help mobility.',
  },
  {
    day: 7,
    title: 'First Week Completed',
    vaginal: 'Lochia transitions from dark red to pink/brown (Serosa). Pelvic heaviness should be decreasing with rest.',
    cesarean: 'First incision check with provider. Steri-strips or glue may begin peeling; keep clean and dry without scrubbing.',
  },
  {
    day: 14,
    title: 'Two-Week Wellbeing & Mood Checkpoint',
    vaginal: 'Perineal stitches usually starting to dissolve. Two-week emotional check-in (EPDS screening checkpoint).',
    cesarean: 'Incision tenderness shifting from sharp to dull ache. Two-week emotional check-in (EPDS screening checkpoint).',
  },
  {
    day: 28,
    title: 'One Month Milestone',
    vaginal: 'Lochia shifting toward scant white/yellow (Alba). Gentle diaphragmatic breathing and deep core reconnection.',
    cesarean: 'Subsurface incision tissue continues remodeling. Light walking can be extended; avoid lifting heavier than your baby.',
  },
  {
    day: 42,
    title: 'Six-Week Postnatal Clinical Review',
    vaginal: 'Official OB/GYN or midwife comprehensive exam: pelvic floor tone, cervix closure, contraception counseling, mental health.',
    cesarean: 'Comprehensive checkup: deep abdominal scar healing, diastasis recti assessment, safe return to gradual fitness clearance.',
  },
]);

export const CAN_I_DO_THIS_YET = Object.freeze([
  {
    activity: 'Exercise',
    icon: 'fitness',
    category: 'Movement',
    timeline: 'Vaginal: Gentle walks right away, core/light rehab 2–4w, high impact 6–12w. C-Section: Walking right away, formal exercise after 6–8w clearance.',
    recommendation: 'Walking and diaphragmatic breathing can begin immediately. Hold off on running, jumping, crunches, and heavy weights until your 6-week pelvic floor and incision check.',
  },
  {
    activity: 'Driving',
    icon: 'car',
    category: 'Mobility',
    timeline: 'Vaginal: Usually 1–2 weeks once pain-free. C-Section: Typically 2–3 weeks once off narcotic pain medication and able to perform an emergency brake stop without incision hesitation.',
    recommendation: 'Test your ability to stomp the brake firmly while stationary. If it causes sharp pain or hesitation, wait a few more days.',
  },
  {
    activity: 'Lifting',
    icon: 'luggage',
    category: 'Daily Life',
    timeline: 'First 6 weeks: Never lift anything heavier than your baby in their car seat (approx 10–15 lbs / 5–7 kg).',
    recommendation: 'Excessive intra-abdominal pressure strains healing perineal tissue, C-section fascial repairs, and your pelvic floor.',
  },
  {
    activity: 'Sex & Intimacy',
    icon: 'heart',
    category: 'Intimacy',
    timeline: 'Standard clinical guideline: Wait until lochia has completely stopped and after your 6-week postnatal clearance.',
    recommendation: 'Early intercourse introduces infection risk to the placental wound site. Estrogen drops also cause vaginal dryness; lubrications and zero pressure are essential.',
  },
  {
    activity: 'Swimming & Baths',
    icon: 'pool',
    category: 'Hygiene',
    timeline: 'Showers: Immediate. Submerged baths / pools / hot tubs: Wait until bleeding has stopped and incision/perineum is fully closed (typically 4–6 weeks).',
    recommendation: 'Submerging in water while your cervix is still slightly open increases uterine infection risk.',
  },
  {
    activity: 'Sleeping on Stomach',
    icon: 'bed',
    category: 'Sleep',
    timeline: 'Vaginal: Whenever comfortable. C-Section: Once incision pressure is tolerable (often 2–4 weeks).',
    recommendation: 'If breastfeeding, sleeping on your stomach may put excessive pressure on full breasts, leading to plugged ducts. A pillow under the hips helps.',
  },
]);

export const CONTEXTUAL_READS = Object.freeze([
  {
    id: 'pr_01',
    title: 'The Great Hormone Plunge (Days 3–5)',
    topic: 'Mental Health',
    readingTime: '60 sec',
    trigger: 'day <= 7',
    summary: 'Why sudden crying and overwhelming tenderness are physiological hormonal crashes, not personal failure.',
  },
  {
    id: 'pr_02',
    title: 'Lochia Colors: When to Rest vs When to Call',
    topic: 'Physical Recovery',
    readingTime: '90 sec',
    trigger: 'bleeding',
    summary: 'How your bleeding shifts from Rubra to Serosa, and what your body is telling you when red blood returns.',
  },
  {
    id: 'pr_03',
    title: 'C-Section Scar Care: The First 3 Weeks',
    topic: 'Incision Healing',
    readingTime: '75 sec',
    trigger: 'cesarean',
    summary: 'Keep it clean, keep it dry, and why gentle abdominal splinting protects your fascial layer.',
  },
  {
    id: 'pr_04',
    title: 'Sore Nipples vs Engorgement: Immediate Relief',
    topic: 'Lactation',
    readingTime: '60 sec',
    trigger: 'breast',
    summary: 'Colostrum to mature milk transition, reverse pressure softening, and correcting shallow latches.',
  },
  {
    id: 'pr_05',
    title: 'The 2-Week Postpartum Mood Screening (EPDS)',
    topic: 'Clinical Care',
    readingTime: '90 sec',
    trigger: 'day >= 14',
    summary: 'Understanding the validated 10-question tool used worldwide to support new mothers with postpartum anxiety and depression.',
  },
]);
