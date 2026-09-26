/**
 * postpartumController.js
 * HTTP controllers for all Postpartum Command Center endpoints.
 */

import { PostpartumService } from '../services/postpartumService.js';
import { PostpartumSafetyService } from '../services/postpartumSafetyService.js';

export async function getPostpartumOverview(req, res, next) {
  try {
    const userId = req.user?.userId || 'preview_user';
    const overview = await PostpartumService.getOverview(userId);
    return res.json({ ok: true, data: overview });
  } catch (err) {
    return next(err);
  }
}

export async function getPostpartumTodayBrief(req, res, next) {
  try {
    const userId = req.user?.userId || 'preview_user';
    const brief = await PostpartumService.getTodayBrief(userId);
    return res.json({ ok: true, data: brief });
  } catch (err) {
    return next(err);
  }
}

export async function checkPostpartumSafety(req, res, next) {
  try {
    const query = req.body?.query || req.body?.item || req.query.query || req.query.item || '';
    const daysSinceBirth = parseInt(req.body?.daysSinceBirth || req.query.daysSinceBirth || 14, 10);
    const feedingMethod = req.body?.feedingMethod || req.query.feedingMethod || 'breastfeeding';
    const data = await PostpartumService.checkLactationSafety({ query, daysSinceBirth, feedingMethod });
    return res.json({ ok: true, state: 'ready', data });
  } catch (err) {
    return next(err);
  }
}

export async function calibratePostpartum(req, res, next) {
  try {
    const userId = req.user.userId;
    const { deliveryDate, deliveryType, feedingMethod, lowEnergyMode } = req.body || {};
    const updated = await PostpartumService.updateCalibration(userId, {
      deliveryDate,
      deliveryType,
      feedingMethod,
      lowEnergyMode,
    });
    return res.json({ ok: true, data: updated });
  } catch (err) {
    return next(err);
  }
}

export async function recordPostpartumCheckin(req, res, next) {
  try {
    const userId = req.user.userId;
    const result = await PostpartumService.recordCheckin(userId, req.body || {});
    return res.json({ ok: true, data: result });
  } catch (err) {
    return next(err);
  }
}

export async function recordBabyEvent(req, res, next) {
  try {
    const userId = req.user.userId;
    const event = await PostpartumService.recordBabyEvent(userId, req.body || {});
    return res.json({ ok: true, data: event });
  } catch (err) {
    return next(err);
  }
}

export async function getBabyEvents(req, res, next) {
  try {
    const userId = req.user.userId;
    const date = req.query.date;
    const events = await PostpartumService.getBabyEvents(userId, date);
    return res.json({ ok: true, data: events });
  } catch (err) {
    return next(err);
  }
}

export async function generateHelpSOS(req, res, next) {
  try {
    const { needs, recipientName } = req.body || {};
    const sos = PostpartumService.generateHelpMessage({ needs, recipientName });
    return res.json({ ok: true, data: sos });
  } catch (err) {
    return next(err);
  }
}

export async function evaluateSafetyTriage(req, res, next) {
  try {
    const result = PostpartumSafetyService.evaluateSafety(req.body || {});
    return res.json({ ok: true, data: result });
  } catch (err) {
    return next(err);
  }
}
