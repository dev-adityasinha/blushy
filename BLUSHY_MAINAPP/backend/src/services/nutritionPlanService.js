import { createHttpError } from '../utils/httpError.js';
import { env } from '../utils/env.js';
import { aiFetch } from '../utils/aiRequest.js';
import { logger } from '../utils/logger.js';

class NutritionPlanService {
  async generateNutritionPlan({
    dietaryPreference,
    allergies = [],
    cookingFrequency,
    nutritionGoals = [],
    cyclePhase = null,
    role = 'woman',
  }) {
    if (!env.aiChatApiKey) {
      throw createHttpError(503, 'AI nutrition planning is not configured. Add GROK_API_KEY in backend .env');
    }

    const prompt = this.buildPlanGenerationPrompt({
      dietaryPreference,
      allergies,
      cookingFrequency,
      nutritionGoals,
      cyclePhase,
      role,
    });

    let response;
    try {
      response = await aiFetch(env.aiChatApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.aiChatApiKey}`,
          'Content-Type': 'application/json',
          'X-Title': 'Blushy Nutrition',
        },
        body: JSON.stringify({
          model: env.aiChatModel,
          messages: [
            { role: 'system', content: 'Return ONLY valid JSON, no markdown.' },
            { role: 'user', content: prompt },
          ],
          max_tokens: 4000,
        }),
      });
    } catch (error) {
      logger.error('Unable to reach AI provider', error);
      throw createHttpError(502, 'Unable to reach the AI provider right now.');
    }

    let payload = {};
    try {
      payload = await response.json();
    } catch (error) {
      logger.error('Invalid nutrition AI JSON response', error);
      throw createHttpError(502, 'Invalid response from AI provider.');
    }

    const assistantMessage = payload.choices?.[0]?.message?.content || '';
    if (!assistantMessage) {
      throw createHttpError(502, 'No meal plan generated. Please try again.');
    }

    let planData;
    try {
      planData = JSON.parse(assistantMessage);
    } catch (error) {
      logger.error('Failed to parse nutrition plan JSON', error);
      throw createHttpError(502, 'Invalid meal plan format received.');
    }

    return this.normalizePlanData(planData);
  }

  buildPlanGenerationPrompt({ dietaryPreference, allergies, cookingFrequency, nutritionGoals, cyclePhase, role }) {
    let prompt = `Generate a personalized 30-day nutrition meal plan in JSON format.\n\nUser Preferences:\n- Dietary Preference: ${dietaryPreference || 'no restriction'}\n- Allergies/Sensitivities: ${allergies && allergies.length > 0 ? allergies.join(', ') : 'none'}\n- Cooking Frequency: ${cookingFrequency || 'moderate'}\n- Nutrition Goals: ${nutritionGoals && nutritionGoals.length > 0 ? nutritionGoals.join(', ') : 'general health'}`;

    if (role === 'woman' && cyclePhase) {
      prompt += `\n- Cycle Phase: ${cyclePhase}\n\nAdjust meals for the current cycle phase.`;
    }

    prompt += `\n\nReturn ONLY valid JSON with this exact structure:\n{\n  "generatedAt": "ISO timestamp",\n  "days": [\n    {\n      "date": "YYYY-MM-DD",\n      "morning": [{"foods": ["item1"], "calories": 300, "protein_g": 15, "carbs_g": 40, "fat_g": 10}],\n      "afternoon": [],\n      "evening": [],\n      "night": []\n    }\n  ]\n}`;

    return prompt;
  }

  normalizePlanData(rawData) {
    if (!rawData || typeof rawData !== 'object' || !Array.isArray(rawData.days)) {
      throw createHttpError(502, 'Meal plan must contain days array.');
    }

    const now = new Date().toISOString();
    return {
      generatedAt: rawData.generatedAt || now,
      updatedAt: now,
      days: rawData.days.slice(0, 30).map((day, index) => ({
        date: typeof day.date === 'string' ? day.date : new Date(Date.now() + index * 86400000).toISOString().slice(0, 10),
        morning: this.normalizeMeals(day.morning),
        afternoon: this.normalizeMeals(day.afternoon),
        evening: this.normalizeMeals(day.evening),
        night: this.normalizeMeals(day.night),
      })),
    };
  }

  normalizeMeals(meals) {
    if (!Array.isArray(meals)) {
      return [];
    }

    return meals
      .filter((meal) => meal && typeof meal === 'object')
      .slice(0, 4)
      .map((meal) => ({
        foods: Array.isArray(meal.foods) ? meal.foods.slice(0, 10).map((item) => String(item)) : [],
        calories: Math.max(0, Number(meal.calories) || 0),
        protein_g: Math.max(0, Number(meal.protein_g) || 0),
        carbs_g: Math.max(0, Number(meal.carbs_g) || 0),
        fat_g: Math.max(0, Number(meal.fat_g) || 0),
      }));
  }
}

export const nutritionPlanService = new NutritionPlanService();