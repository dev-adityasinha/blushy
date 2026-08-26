import dotenv from 'dotenv';
dotenv.config();

import { db } from '../src/utils/db.js';

const femaleKeysToDelete = [
  'sexually_active',
  'track_intimacy',
  'sex_high_libido_phases',
  'sex_desire_cycle_changes',
  'sex_in_relationship',
  'sex_emotional_connection',
  'contraception_using',
  'contraception_type',
  'contraception_consistency',
  'contraception_cycle_change',
  'contraception_side_effects',
  'partner_compatibility_with',
  'partner_compatibility_option',
  'skin_type',
  'skin_concerns',
  'skin_routine_frequency',
  'skin_cycle_changes',
  'fitness_activity_level',
  'fitness_types',
  'fitness_frequency',
  'fitness_cycle_impact',
  'sex_ed_comfort_level',
  'sex_ed_topics',
  'sex_ed_resources_wanted',
  'contraceptor_awareness_level',
  'contraceptor_interested_types',
  'contraceptor_decision_help',
  'goal_partner_compatibility',
  'goal_enhance_sex_life',
  'goal_explore_contraception',
  'goal_skin_care',
  'goal_body_fitness',
  'goal_sex_education',
  'goal_know_contraceptors'
];

const femaleGoalsToRemove = [
  'partner_compatibility',
  'enhance_sex_life',
  'explore_contraception',
  'skin_care',
  'body_fitness',
  'sex_education',
  'know_contraceptors'
];

const maleKeysToDelete = [
  'intimacy_satisfaction',
  'intimacy_frequency',
  'intimacy_communication',
  'intimacy_interests',
  'partner_compatibility_with',
  'partner_compatibility_option',
  'fertility_disease_diagnosed',
  'fertility_disease_types',
  'fertility_disease_other_detail',
  'child_planning_timeline',
  'sexual_wellness_awareness',
  'sexual_wellness_topics',
  'sexual_wellness_protection',
  'skin_type',
  'skin_concerns',
  'skin_routine_frequency',
  'skin_product_knowledge',
  'fitness_activity_level',
  'fitness_types',
  'fitness_frequency',
  'fitness_goals',
  'sex_ed_comfort_level',
  'sex_ed_topics',
  'sex_ed_partner_discussion',
  'contraceptor_awareness_level',
  'contraceptor_interested_types',
  'contraceptor_discussion_partner',
  'contraceptor_responsibility',
  'goal_enhance_intimacy',
  'goal_partner_compatibility',
  'goal_want_child',
  'goal_sexual_wellness',
  'goal_skin_care',
  'goal_body_fitness',
  'goal_sex_education',
  'goal_know_contraceptors'
];

const maleGoalsToRemove = [
  'enhance_intimacy',
  'partner_compatibility',
  'want_child',
  'sexual_wellness',
  'skin_care',
  'body_fitness',
  'sex_education',
  'know_contraceptors'
];

function cleanAnswers(answers, keysToDelete, goalsToRemove) {
  if (!answers) return null;
  let changed = false;
  const newAnswers = { ...answers };

  for (const key of keysToDelete) {
    if (key in newAnswers) {
      delete newAnswers[key];
      changed = true;
    }
  }

  const selectedGoalsStr = newAnswers['selected_goals'];
  if (selectedGoalsStr) {
    const goals = selectedGoalsStr
      .split(',')
      .map(g => g.trim())
      .filter(g => g.length > 0);
    
    const filteredGoals = goals.filter(g => !goalsToRemove.includes(g));
    if (goals.length !== filteredGoals.length) {
      newAnswers['selected_goals'] = filteredGoals.join(',');
      changed = true;
    }
  }

  return changed ? newAnswers : null;
}

async function migrateCollection(collectionName, keysToDelete, goalsToRemove) {
  console.log(`Starting migration for ${collectionName}...`);
  const cursor = db.collection(collectionName).find({ onboarding_answers: { $ne: null } });
  
  let totalChecked = 0;
  let totalUpdated = 0;

  while (await cursor.hasNext()) {
    const user = await cursor.next();
    totalChecked++;

    const cleaned = cleanAnswers(user.onboarding_answers, keysToDelete, goalsToRemove);
    if (cleaned) {
      await db.collection(collectionName).updateOne(
        { _id: user._id },
        { $set: { onboarding_answers: cleaned } }
      );
      totalUpdated++;
    }
  }

  console.log(`Finished ${collectionName}: Checked ${totalChecked}, Updated ${totalUpdated}`);
}

async function main() {
  try {
    // Wait a brief moment to ensure DB has connected
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    await migrateCollection('users_woman', femaleKeysToDelete, femaleGoalsToRemove);
    await migrateCollection('users_man', maleKeysToDelete, maleGoalsToRemove);
    
    console.log('Database cleanup completed successfully.');
    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

main();
