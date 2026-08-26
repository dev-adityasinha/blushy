import express from 'express';
import { requireAuth } from '../middleware/requireAuth.js';
import { submitCheckin, getCheckinByDate } from '../controllers/checkinController.js';

const router = express.Router();

router.use(requireAuth);

router.post('/', submitCheckin);
router.get('/:date', getCheckinByDate);

export default router;
