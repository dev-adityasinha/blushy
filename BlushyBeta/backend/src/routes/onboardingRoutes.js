import { Router } from 'express';
import {
  getOnboardingQuestions,
  updateOnboardingQuestions,
} from '../controllers/onboardingController.js';

const router = Router();

// Public route to fetch questions for onboarding wizard
router.get('/questions', getOnboardingQuestions);

// Route for updating questions (Admin dynamic updates)
router.put('/questions', updateOnboardingQuestions);
router.put('/admin/questions', updateOnboardingQuestions);

export default router;
