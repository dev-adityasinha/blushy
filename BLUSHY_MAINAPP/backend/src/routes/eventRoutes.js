import { Router } from 'express';
import { requireAuth } from '../middleware/requireAuth.js';
import {
  getEventSchema,
  logEvent,
  getEvents,
  getEvent,
  editEvent,
  removeEvent,
  getTimeline,
  syncEvents,
} from '../controllers/eventsController.js';

/**
 * Health event and timeline routes (spec §6, §11, §25).
 * Authorization is mandatory on every route: these are private health records.
 */
const router = Router();

router.get('/schema', getEventSchema);
router.get('/timeline', requireAuth, getTimeline);
router.post('/sync', requireAuth, syncEvents);

router.post('/', requireAuth, logEvent);
router.get('/', requireAuth, getEvents);
router.get('/:eventId', requireAuth, getEvent);
router.patch('/:eventId', requireAuth, editEvent);
router.delete('/:eventId', requireAuth, removeEvent);

export default router;
