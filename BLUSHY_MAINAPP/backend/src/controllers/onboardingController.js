import { onboardingQuestionRepository } from '../repositories/onboardingQuestionRepository.js';
import { createHttpError } from '../utils/httpError.js';

export async function getOnboardingQuestions(req, res, next) {
  try {
    const role = req.query.role || 'woman';
    const result = await onboardingQuestionRepository.getQuestionsByRole(role);
    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
}

export async function updateOnboardingQuestions(req, res, next) {
  try {
    const { role, questions } = req.body || {};

    if (!role || (role !== 'woman' && role !== 'partner' && role !== 'man')) {
      throw createHttpError(400, 'role must be "woman" or "partner".');
    }

    if (!Array.isArray(questions)) {
      throw createHttpError(400, 'questions must be an array of question definitions.');
    }

    const updated = await onboardingQuestionRepository.updateQuestionsByRole(role, questions);
    res.status(200).json({
      message: 'Onboarding questions updated successfully.',
      ...updated,
    });
  } catch (error) {
    next(error);
  }
}
