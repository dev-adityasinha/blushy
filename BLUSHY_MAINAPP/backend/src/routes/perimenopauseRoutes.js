import { Router } from 'express';
import { requireAuth } from '../middleware/requireAuth.js';
import { PerimenopauseService } from '../services/perimenopauseService.js';

const router = Router();

// Identity comes only from the verified token. The previous version trusted
// req.headers['x-user-id'] and fell back to a shared 'default_user', so any
// caller could read or write another user's data -- or everyone's at once --
// by setting a header or sending none. requireAuth on every route below now
// guarantees req.user.userId is present and authenticated.
function resolveUserId(req) {
  return req.user.userId;
}

router.get('/overview', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const data = await PerimenopauseService.getOverview(userId);
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error fetching perimenopause overview' });
  }
});

router.get('/today-brief', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const data = await PerimenopauseService.getTodayBrief(userId);
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error generating today brief' });
  }
});

router.post('/checkin', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const record = PerimenopauseService.recordCheckin(userId, req.body);
    res.json({ success: true, data: record });
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error recording checkin' });
  }
});

router.post('/check-in', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const record = PerimenopauseService.recordCheckin(userId, req.body);
    res.json({ success: true, data: record });
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error recording checkin' });
  }
});

router.post('/calibrate', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const profile = PerimenopauseService.calibrate(userId, req.body);
    res.json({ success: true, data: profile });
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error calibrating perimenopause' });
  }
});

router.post('/focus', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const profile = PerimenopauseService.setFocus(userId, req.body.focus);
    res.json({ success: true, data: profile });
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error setting focus' });
  }
});

router.post('/life-mode', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const profile = PerimenopauseService.setLifeMode(userId, req.body.lifeMode);
    res.json({ success: true, data: profile });
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error setting life mode' });
  }
});

router.post('/treatment', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const treatment = PerimenopauseService.saveTreatment(userId, req.body);
    res.json({ success: true, data: treatment });
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error saving treatment' });
  }
});

router.post('/questions', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const q = PerimenopauseService.addQuestion(userId, req.body.text || req.body.question);
    res.json({ success: true, data: q });
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error adding question' });
  }
});

router.delete('/questions/:id', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const ok = PerimenopauseService.deleteQuestion(userId, req.params.id);
    res.json({ success: ok });
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error deleting question' });
  }
});

router.post('/parse-note', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const result = await PerimenopauseService.parseNaturalNote(userId, req.body.text || '');
    res.json(result);
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error parsing note' });
  }
});

router.get('/clinician-brief', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const brief = PerimenopauseService.getClinicianBrief(userId);
    res.json({ success: true, data: brief });
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error generating clinician brief' });
  }
});

router.post('/cycle-interval', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const days = parseInt(req.body.days, 10) || 28;
    const history = PerimenopauseService.recordPeriodCycle(userId, days);
    res.json({ success: true, data: history });
  } catch (err) {
    res.status(500).json({ success: false, message: err?.message || 'Error recording cycle interval' });
  }
});

export default router;
