import express from 'express';
import { requireAuth } from '../middleware/requireAuth.js';
import { getMonthlyInsights } from '../controllers/insightsController.js';

const router = express.Router();

router.use(requireAuth);

router.get('/monthly', getMonthlyInsights);

export default router;
