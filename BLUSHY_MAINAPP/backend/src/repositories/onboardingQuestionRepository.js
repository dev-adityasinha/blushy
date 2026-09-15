import { db } from '../utils/db.js';

const DEFAULT_WOMEN_QUESTIONS = [
  {
    key: 'preferred_name',
    title: 'What should we call you?',
    subtitle: 'Your preferred name for personalized greetings.',
    type: 'text',
    required: true,
  },
  {
    key: 'date_of_birth',
    title: 'When is your birthday?',
    subtitle: 'Used to provide age-appropriate health insights.',
    type: 'date',
    required: true,
  },
  {
    key: 'life_stage',
    title: 'What stage best describes your current journey?',
    subtitle: 'Blushy tailors health recommendations to your exact life stage.',
    type: 'single_choice',
    options: [
      { key: 'firstPeriodNotStarted', label: 'First Period Not Started' },
      { key: 'firstPeriodStarted', label: 'First Period Started' },
      { key: 'reproductiveYears', label: 'Reproductive Years / Regular Tracking' },
      { key: 'hormonalHealth', label: 'Hormonal & Cycle Support' },
      { key: 'tryingToConceive', label: 'Trying to Conceive' },
      { key: 'pregnancy', label: 'Pregnancy Journey' },
      { key: 'postpartum', label: 'Postpartum Care' },
      { key: 'perimenopause', label: 'Perimenopause' },
      { key: 'menopause', label: 'Menopause' },
    ],
    required: true,
  },
  {
    key: 'goals',
    title: 'What are your primary goals with Blushy?',
    subtitle: 'Select all that apply.',
    type: 'multi_choice',
    options: [
      { key: 'cycle_tracking', label: 'Track cycle & ovulation' },
      { key: 'symptom_management', label: 'Manage PMS & symptoms' },
      { key: 'conception', label: 'Prepare for pregnancy' },
      { key: 'postpartum_care', label: 'Postpartum care & baby milestones' },
      { key: 'hormone_balance', label: 'Hormonal balance' },
      { key: 'ai_companion', label: 'AI wellness companion guidance' },
    ],
    required: false,
  },
  {
    key: 'symptoms',
    title: 'Do you regularly experience any of these symptoms?',
    subtitle: 'Select all that apply.',
    type: 'multi_choice',
    options: [
      { key: 'cramps', label: 'Cramps' },
      { key: 'bloating', label: 'Bloating' },
      { key: 'mood_swings', label: 'Mood swings' },
      { key: 'fatigue', label: 'Fatigue' },
      { key: 'acne', label: 'Acne & Skin breakouts' },
      { key: 'headaches', label: 'Headaches' },
      { key: 'irregularity', label: 'Irregular periods' },
    ],
    required: false,
  },
  {
    key: 'conditions',
    title: 'Do you have any diagnosed health conditions?',
    subtitle: 'Select all that apply.',
    type: 'multi_choice',
    options: [
      { key: 'pcos', label: 'PCOS' },
      { key: 'endometriosis', label: 'Endometriosis' },
      { key: 'fibroids', label: 'Fibroids' },
      { key: 'thyroid', label: 'Thyroid Imbalance' },
      { key: 'none', label: 'None / Prefer not to say' },
    ],
    required: false,
  },
  {
    key: 'reproductive_cycle_type',
    title: 'How would you describe your cycle regularity?',
    subtitle: 'Helps predict future cycle dates accurately.',
    type: 'single_choice',
    options: [
      { key: 'predictable', label: 'Predictable (25-35 days)' },
      { key: 'slightly_variable', label: 'Slightly variable' },
      { key: 'unpredictable', label: 'Highly unpredictable' },
    ],
    required: false,
  },
];

const DEFAULT_PARTNER_QUESTIONS = [
  {
    key: 'preferred_name',
    title: 'What is your name?',
    subtitle: 'Your name for partner notifications and mode.',
    type: 'text',
    required: true,
  },
  {
    key: 'partner_stage',
    title: 'Which stage is your partner currently in?',
    subtitle: 'Helps Blushy provide appropriate partner tips.',
    type: 'single_choice',
    options: [
      { key: 'first_periods', label: 'First Periods' },
      { key: 'cycle_tracking', label: 'Cycle & Mood Tracking' },
      { key: 'pregnancy', label: 'Pregnancy Journey' },
      { key: 'postpartum', label: 'Postpartum Care' },
      { key: 'menopause', label: 'Menopause Support' },
    ],
    required: true,
  },
  {
    key: 'partner_support_areas',
    title: 'How do you want to support your partner?',
    subtitle: 'Select all that apply.',
    type: 'multi_choice',
    options: [
      { key: 'cycle_awareness', label: 'Cycle & mood awareness' },
      { key: 'gifts', label: 'Comfort & gift recommendations' },
      { key: 'emotional_tips', label: 'Emotional support guidance' },
      { key: 'symptom_tracking', label: 'Health & symptom tracking' },
    ],
    required: false,
  },
];

export async function getQuestionsByRole(role = 'woman') {
  const normalizedRole = role === 'partner' || role === 'man' ? 'partner' : 'woman';
  const collection = db.collection('onboarding_questions');

  let record = await collection.findOne({ role: normalizedRole });
  if (!record) {
    // Seed default questions into MongoDB collection if not present
    const defaultQuestions = normalizedRole === 'partner' ? DEFAULT_PARTNER_QUESTIONS : DEFAULT_WOMEN_QUESTIONS;
    record = {
      role: normalizedRole,
      questions: defaultQuestions,
      updated_at: new Date(),
    };
    await collection.insertOne(record);
  }

  return {
    role: normalizedRole,
    questions: record.questions ?? [],
    updatedAt: record.updated_at ? new Date(record.updated_at).toISOString() : null,
  };
}

export async function updateQuestionsByRole(role = 'woman', questions = []) {
  const normalizedRole = role === 'partner' || role === 'man' ? 'partner' : 'woman';
  const collection = db.collection('onboarding_questions');

  if (!Array.isArray(questions)) {
    throw new Error('questions must be an array');
  }

  const now = new Date();
  await collection.updateOne(
    { role: normalizedRole },
    {
      $set: {
        role: normalizedRole,
        questions: questions,
        updated_at: now,
      },
    },
    { upsert: true }
  );

  return getQuestionsByRole(normalizedRole);
}

export const onboardingQuestionRepository = {
  getQuestionsByRole,
  updateQuestionsByRole,
};
