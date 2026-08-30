import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/requireAuth.js';
import {
  getCategories,
  getMyPreferences,
  patchMyPreferences,
  getMyNotifications,
  markNotificationsRead,
  createReminder,
  cancelReminder,
  getAnalyticsSchema,
  trackAnalytics,
  getAnalyticsFunnel,
  registerPushDevice,
  unregisterPushDevice,
  getPushDevices,
  getPushDeliveryLog,
} from '../controllers/notificationController.js';

/**
 * Notification preferences and analytics ingest (spec §19, §24, §26).
 */
const router = Router();

router.get('/categories', getCategories);
router.get('/preferences', requireAuth, getMyPreferences);
router.patch('/preferences', requireAuth, patchMyPreferences);
router.get('/', requireAuth, getMyNotifications);
router.post('/read', requireAuth, markNotificationsRead);
router.post('/reminders', requireAuth, createReminder);
router.delete('/reminders/:entityType/:entityId', requireAuth, cancelReminder);

router.post('/devices', requireAuth, registerPushDevice);
router.delete('/devices', requireAuth, unregisterPushDevice);
router.get('/devices', requireAuth, getPushDevices);
router.get('/delivery-log', requireAuth, getPushDeliveryLog);

router.get('/analytics/schema', getAnalyticsSchema);
router.post('/analytics/track', requireAuth, trackAnalytics);
router.get('/analytics/funnel', requireAuth, requireRole('admin'), getAnalyticsFunnel);

export default router;
