import { Router } from 'express';
import { MenopauseService } from '../services/menopauseService.js';

const router = Router();

function resolveUserId(req) {
  return req.user?.id || req.user?.userId || req.headers['x-user-id'] || 'default_user';
}

router.get('/overview', async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const profile = req.user || {};
    const data = await MenopauseService.getOverview(userId, profile);
    res.json({ state: 'ready', success: true, data });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error fetching menopause overview' });
  }
});

router.get('/today-brief', async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const profile = req.user || {};
    const data = await MenopauseService.getTodayBrief(userId, profile);
    res.json({ state: 'ready', success: true, data });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error generating today brief' });
  }
});

router.post('/checkin', async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const record = MenopauseService.recordCheckin(userId, req.body);
    res.json({ state: 'ready', success: true, data: record });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error recording checkin' });
  }
});

router.post('/check-in', async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const record = MenopauseService.recordCheckin(userId, req.body);
    res.json({ state: 'ready', success: true, data: record });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error recording checkin' });
  }
});

router.post('/life-mode', async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const mode = MenopauseService.setLifeMode(userId, req.body.lifeMode || req.body.mode);
    res.json({ state: 'ready', success: true, data: { lifeMode: mode } });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error updating life mode' });
  }
});

router.post('/private-mode', async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const privateMode = MenopauseService.setPrivateMode(userId, req.body.enabled);
    res.json({ state: 'ready', success: true, data: { privateMode } });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error updating private mode' });
  }
});

router.post('/is-this-normal', async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const query = req.body.query || req.body.question || req.body.symptomText || req.body.text || '';
    const response = await MenopauseService.askIsThisNormal(userId, { query });
    res.json({ state: 'ready', success: true, data: response });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error resolving question' });
  }
});

router.post('/parse-note', async (req, res) => {
  try {
    const userId = resolveUserId(req);
    const noteText = req.body.note || req.body.text || req.body.noteText || req.body.rawText || '';
    const result = await MenopauseService.parseNaturalNote(userId, { noteText });
    res.json({ state: 'ready', success: true, data: result });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error parsing note' });
  }
});

router.get('/questions', (req, res) => {
  try {
    const userId = resolveUserId(req);
    const questions = MenopauseService.getQuestions(userId);
    res.json({ state: 'ready', success: true, data: questions });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error fetching questions' });
  }
});

router.post('/questions', (req, res) => {
  try {
    const userId = resolveUserId(req);
    const q = MenopauseService.addQuestion(userId, req.body);
    res.json({ state: 'ready', success: true, data: q });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error saving question' });
  }
});

router.delete('/questions/:id', (req, res) => {
  try {
    const userId = resolveUserId(req);
    MenopauseService.deleteQuestion(userId, req.params.id);
    res.json({ state: 'ready', success: true, message: 'Question removed' });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error removing question' });
  }
});

router.get('/treatments', (req, res) => {
  try {
    const userId = resolveUserId(req);
    const treatments = MenopauseService.getTreatments(userId);
    res.json({ state: 'ready', success: true, data: treatments });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error fetching treatments' });
  }
});

router.post('/treatment', (req, res) => {
  try {
    const userId = resolveUserId(req);
    const t = MenopauseService.addTreatment(userId, req.body);
    res.json({ state: 'ready', success: true, data: t });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error saving treatment' });
  }
});

router.delete('/treatment/:id', (req, res) => {
  try {
    const userId = resolveUserId(req);
    MenopauseService.removeTreatment(userId, req.params.id);
    res.json({ state: 'ready', success: true, message: 'Treatment removed' });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error removing treatment' });
  }
});

router.get('/clinician-brief', (req, res) => {
  try {
    const userId = resolveUserId(req);
    const profile = req.user || {};
    const brief = MenopauseService.getClinicianBrief(userId, profile);
    res.json({ state: 'ready', success: true, data: brief });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error generating clinician brief' });
  }
});

router.get('/why-am-i-seeing-this/:moduleKey', (req, res) => {
  try {
    const userId = resolveUserId(req);
    const info = MenopauseService.getWhyAmISeeingThis(userId, req.params.moduleKey);
    res.json({ state: 'ready', success: true, data: info });
  } catch (err) {
    res.status(500).json({ state: 'error', success: false, message: err?.message || 'Error fetching explanation' });
  }
});

export default router;
