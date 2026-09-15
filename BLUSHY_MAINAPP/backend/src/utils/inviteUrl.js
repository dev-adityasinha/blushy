import { env } from './env.js';
import { logger } from './logger.js';

/// The web app a shareable invite opens.
///
/// This was hard-coded to `https://blushy.life/partner/claim`, and both halves
/// of that were wrong. `blushy.life` is a static host with no single-page
/// rewrite, so `/partner/claim` is a 404 there -- the recipient never reached
/// any app at all -- and the build it does serve at `/` is an older, different
/// package than the one shipping today.
///
/// So the path is dropped: the code travels in the fragment, which the app
/// reads from whatever URL it was opened with, and `/` is the one path a plain
/// static host is guaranteed to answer.
///
/// Set PARTNER_INVITE_BASE_URL to move links onto another host -- blushy.life
/// once it serves the current build, for instance. The fallback is the origin
/// that serves it today.
const DEFAULT_INVITE_BASE_URL = 'https://blushy-web-upload.vercel.app';

function resolveInviteBaseUrl() {
  const configured = typeof env.partnerInviteBaseUrl === 'string'
    ? env.partnerInviteBaseUrl.trim().replace(/\/+$/, '')
    : '';

  // https only: an invite is opened by somebody else, on another device, so a
  // localhost or plain-http base is never the right answer for a real link.
  if (/^https:\/\/[^\s/]+$/i.test(configured)) {
    return configured;
  }

  if (configured) {
    logger.warn('PARTNER_INVITE_BASE_URL is not a plain https origin; falling back', {
      configured,
    });
  }

  return DEFAULT_INVITE_BASE_URL;
}

/// Builds the link itself. The token lives in the fragment on purpose: a
/// fragment is never sent to a server, so the invite stays out of access logs
/// and Referer headers on the way.
export function buildInviteUrl(token) {
  return `${resolveInviteBaseUrl()}/#code=${token}`;
}
