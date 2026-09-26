import { pregnancyService } from '../services/pregnancyService.js';

export async function getPregnancyOverview(req, res, next) {
  try {
    const dueDate = req.query.dueDate || req.user?.dueDate;
    const userId = req.user.userId;
    const data = await pregnancyService.getOverview({ dueDate, userId });
    return res.json({ state: 'ready', data });
  } catch (err) {
    next(err);
  }
}

export async function getTodayBrief(req, res, next) {
  try {
    const dueDate = req.query.dueDate || req.user?.dueDate;
    const activeMode = req.query.mode || 'default';
    const userId = req.user.userId;
    const data = await pregnancyService.getTodayBrief({ dueDate, userId, activeMode });
    return res.json({ state: 'ready', data });
  } catch (err) {
    next(err);
  }
}

export async function recordPregnancyCheckIn(req, res, next) {
  try {
    const userId = req.user.userId;
    const checkin = req.body?.checkin || req.body || {};
    const result = await pregnancyService.recordCheckIn({ userId, checkin });
    return res.json({ state: 'ready', data: result });
  } catch (err) {
    next(err);
  }
}

export async function getPregnancyBaseline(req, res, next) {
  try {
    const userId = req.user.userId;
    const data = await pregnancyService.getBaselineAndDeltas({ userId });
    return res.json({ state: 'ready', data });
  } catch (err) {
    next(err);
  }
}

export async function classifySymptom(req, res, next) {
  try {
    const query = req.body?.query || req.query.query || '';
    const week = parseInt(req.body?.week || req.query.week || 20, 10);
    const data = pregnancyService.classifySymptomIsThisNormal({ query, week });
    return res.json({ state: 'ready', data });
  } catch (err) {
    next(err);
  }
}

export async function checkFoodSafety(req, res, next) {
  try {
    const query = req.body?.query || req.query.query || '';
    const week = parseInt(req.body?.week || req.query.week || 20, 10);
    const data = pregnancyService.checkFoodAndMedicineSafety({ query, week });
    return res.json({ state: 'ready', data });
  } catch (err) {
    next(err);
  }
}

export async function savePregnancyMemory(req, res, next) {
  try {
    const userId = req.user.userId;
    const memory = req.body || {};
    const data = await pregnancyService.saveMemory({ userId, memory });
    return res.json({ state: 'ready', data });
  } catch (err) {
    next(err);
  }
}

export async function getPregnancyMemories(req, res, next) {
  try {
    const userId = req.user.userId;
    const data = await pregnancyService.getMemories({ userId });
    return res.json({ state: 'ready', data });
  } catch (err) {
    next(err);
  }
}

export async function savePregnancyQuestion(req, res, next) {
  try {
    const userId = req.user.userId;
    const question = req.body || {};
    const data = await pregnancyService.saveQuestion({ userId, question });
    return res.json({ state: 'ready', data });
  } catch (err) {
    next(err);
  }
}

export async function getPregnancyQuestions(req, res, next) {
  try {
    const userId = req.user.userId;
    const data = await pregnancyService.getQuestions({ userId });
    return res.json({ state: 'ready', data });
  } catch (err) {
    next(err);
  }
}
