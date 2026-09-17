/**
 * postpartumController.js
 * HTTP controllers for all Postpartum Command Center endpoints.
 */

import { PostpartumService } from '../services/postpartumService.js';
import { PostpartumSafetyService } from '../services/postpartumSafetyService.js';

export async function getPostpartumOverview(req, res, next) {
  try {
    const userId = req.user.userId;
    const overview = PostpartumService.getOverview(userId);
    return res.json({ ok: true, data: overview });
  } catch (err) {
    return next(err);
  }
}

export async function getPostpartumTodayBrief(req, res, next) {
  try {
    const userId = req.user.userId;
    const brief = await PostpartumService.getTodayBrief(userId);
    return res.json({ ok: true, data: brief });
  } catch (err) {
    return next(err);
  }
}

export async function calibratePostpartum(req, res, next) {
  try {
    const userId = req.user.userId;
    const { deliveryDate, deliveryType, feedingMethod, lowEnergyMode } = req.body || {};
    const updated = PostpartumService.updateCalibration(userId, {
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
    const result = PostpartumService.recordCheckin(userId, req.body || {});
    return res.json({ ok: true, data: result });
  } catch (err) {
    return next(err);
  }
}

export async function recordBabyEvent(req, res, next) {
  try {
    const userId = req.user.userId;
    const event = PostpartumService.recordBabyEvent(userId, req.body || {});
    return res.json({ ok: true, data: event });
  } catch (err) {
    return next(err);
  }
}

export async function getBabyEvents(req, res, next) {
  try {
    const userId = req.user.userId;
    const date = req.query.date;
    const events = PostpartumService.getBabyEvents(userId, date);
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
