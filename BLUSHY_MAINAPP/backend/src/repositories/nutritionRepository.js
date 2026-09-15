import { db } from '../utils/db.js';

async function getColl(userId, baseName) {
  const isMan = await db.collection('users_man').findOne({ user_id: userId });
  return isMan ? `${baseName}_man` : `${baseName}_woman`;
}

function mapAnswersRow(row) {
  if (!row) {
    return null;
  }

  return {
    userId: row.user_id,
    dietaryPreference: row.dietary_preference ?? null,
    allergies: row.allergies ?? [],
    cookingFrequency: row.cooking_frequency ?? null,
    nutritionGoals: row.nutrition_goals ?? [],
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

function mapPlanRow(row) {
  if (!row) {
    return null;
  }

  return {
    userId: row.user_id,
    planData: row.plan_data ?? { generatedAt: null, updatedAt: null, days: [] },
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

async function saveNutritionAnswers({
  userId,
  dietaryPreference = null,
  allergies = [],
  cookingFrequency = null,
  nutritionGoals = [],
}) {
  const filter = { user_id: userId };
  const update = {
    $set: {
      dietary_preference: dietaryPreference,
      allergies: allergies,
      cooking_frequency: cookingFrequency,
      nutrition_goals: nutritionGoals,
      updated_at: new Date(),
    },
    $setOnInsert: {
      created_at: new Date(),
    },
  };

  await db.collection(await getColl(userId, 'user_nutrition_answers')).updateOne(filter, update, { upsert: true });

  const doc = await db.collection(await getColl(userId, 'user_nutrition_answers')).findOne(filter);
  return mapAnswersRow(doc);
}

async function getNutritionAnswers(userId) {
  const doc = await db.collection(await getColl(userId, 'user_nutrition_answers')).findOne({ user_id: userId });
  return mapAnswersRow(doc);
}

async function saveNutritionPlan(userId, planData) {
  const filter = { user_id: userId };
  const update = {
    $set: {
      plan_data: planData,
      updated_at: new Date(),
    },
    $setOnInsert: {
      created_at: new Date(),
    },
  };

  await db.collection(await getColl(userId, 'user_nutrition_plans')).updateOne(filter, update, { upsert: true });

  const doc = await db.collection(await getColl(userId, 'user_nutrition_plans')).findOne(filter);
  return mapPlanRow(doc);
}

async function getNutritionPlan(userId) {
  const doc = await db.collection(await getColl(userId, 'user_nutrition_plans')).findOne({ user_id: userId });
  return mapPlanRow(doc);
}

export const nutritionRepository = {
  saveNutritionAnswers,
  getNutritionAnswers,
  saveNutritionPlan,
  getNutritionPlan,
};