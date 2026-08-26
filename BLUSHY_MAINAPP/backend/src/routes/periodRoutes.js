import express from 'express';
import { requireAuth } from '../middleware/requireAuth.js';
import {
  logPeriodEntry,
  getPeriodEntriesList,
  deletePeriodEntryHandler,
  getPredictions,
} from '../controllers/periodController.js';

const router = express.Router();

router.use(requireAuth);

router.post('/entries', logPeriodEntry);
router.get('/entries', getPeriodEntriesList);
router.delete('/entries/:id', deletePeriodEntryHandler);
router.get('/predictions', getPredictions);

export default router;
