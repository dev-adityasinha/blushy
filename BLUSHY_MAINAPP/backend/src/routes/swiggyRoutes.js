import { Router } from 'express';
import { getSwiggyAuthUrl, handleSwiggyCallback, handleSwiggyChat } from '../controllers/swiggyController.js';
import { optionalAuth } from '../middleware/optionalAuth.js';

const router = Router();

router.get('/auth-url', optionalAuth, getSwiggyAuthUrl);
router.get('/callback', handleSwiggyCallback);
router.post('/chat', optionalAuth, handleSwiggyChat);

export default router;
