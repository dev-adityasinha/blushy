import { Router } from 'express';
import { requireAuth } from '../middleware/requireAuth.js';
import { MenopauseService } from '../services/menopauseService.js';

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
    const profile = req.user || {};
    const data = await MenopauseService.getOverview(userId, profile);
    res.json({ state: 'ready', success: true, data });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error fetching menopause overview' });
  }
});

router.get('/today-brief', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const profile = req.user || {};
    const data = await MenopauseService.getTodayBrief(userId, profile);
    res.json({ state: 'ready', success: true, data });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error generating today brief' });
  }
});

router.post('/checkin', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const record = MenopauseService.recordCheckin(userId, req.body);
    res.json({ state: 'ready', success: true, data: record });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error recording checkin' });
  }
});

router.post('/check-in', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const record = MenopauseService.recordCheckin(userId, req.body);
    res.json({ state: 'ready', success: true, data: record });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error recording checkin' });
  }
});

router.post('/life-mode', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const mode = MenopauseService.setLifeMode(userId, req.body.lifeMode || req.body.mode);
    res.json({ state: 'ready', success: true, data: { lifeMode: mode } });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error updating life mode' });
  }
});

router.post('/private-mode', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const privateMode = MenopauseService.setPrivateMode(userId, req.body.enabled);
    res.json({ state: 'ready', success: true, data: { privateMode } });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error updating private mode' });
  }
});

router.post('/is-this-normal', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const query = req.body.query || req.body.question || req.body.symptomText || req.body.text || '';
    const response = await MenopauseService.askIsThisNormal(userId, { query });
    res.json({ state: 'ready', success: true, data: response });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error resolving question' });
  }
});

router.post('/parse-note', requireAuth, async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const noteText = req.body.note || req.body.text || req.body.noteText || req.body.rawText || '';
    const result = await MenopauseService.parseNaturalNote(userId, { noteText });
    res.json({ state: 'ready', success: true, data: result });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error parsing note' });
  }
});

router.get('/questions', requireAuth, (req, res) => {
  try {
    const userId = resolveUserId(req);
    const questions = MenopauseService.getQuestions(userId);
    res.json({ state: 'ready', success: true, data: questions });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error fetching questions' });
  }
});

router.post('/questions', requireAuth, (req, res) => {
  try {
    const userId = resolveUserId(req);
    const q = MenopauseService.addQuestion(userId, req.body);
    res.json({ state: 'ready', success: true, data: q });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error saving question' });
  }
});

router.delete('/questions/:id', requireAuth, (req, res) => {
  try {
    const userId = resolveUserId(req);
    MenopauseService.deleteQuestion(userId, req.params.id);
    res.json({ state: 'ready', success: true, message: 'Question removed' });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error removing question' });
  }
});

router.get('/treatments', requireAuth, (req, res) => {
  try {
    const userId = resolveUserId(req);
    const treatments = MenopauseService.getTreatments(userId);
    res.json({ state: 'ready', success: true, data: treatments });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error fetching treatments' });
  }
});

router.post('/treatment', requireAuth, (req, res) => {
  try {
    const userId = resolveUserId(req);
    const t = MenopauseService.addTreatment(userId, req.body);
    res.json({ state: 'ready', success: true, data: t });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error saving treatment' });
  }
});

router.delete('/treatment/:id', requireAuth, (req, res) => {
  try {
    const userId = resolveUserId(req);
    MenopauseService.removeTreatment(userId, req.params.id);
    res.json({ state: 'ready', success: true, message: 'Treatment removed' });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error removing treatment' });
  }
});

router.get('/clinician-brief', requireAuth, (req, res) => {
  try {
    const userId = resolveUserId(req);
    const profile = req.user || {};
    const brief = MenopauseService.getClinicianBrief(userId, profile);
    res.json({ state: 'ready', success: true, data: brief });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error generating clinician brief' });
  }
});

router.get('/why-am-i-seeing-this/:moduleKey', requireAuth, (req, res) => {
  try {
    const userId = resolveUserId(req);
    const info = MenopauseService.getWhyAmISeeingThis(userId, req.params.moduleKey);
    res.json({ state: 'ready', success: true, data: info });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error fetching explanation' });
  }
});

export default router;
