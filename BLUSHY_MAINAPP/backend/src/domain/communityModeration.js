/**
 * Community moderation rules (spec §12 "Community",
 * §22 "COMMUNITY FUNCTIONALITY").
 *
 * Pure and dependency-free so the rules are testable without a database.
 *
 * The engine flags content for human review; it never silently rewrites or
 * deletes a post on its own judgement. Community content is not medical truth
 * (spec §12), so the strongest automatic action is to hide pending review and
 * attach a warning - a claim is never "corrected" by the app.
 */

export const MODERATION_RULESET_VERSION = 'moderation-v1.0.0';

/**
 * Female and partner communities are separate audiences (spec §12). A post is
 * only ever served to the audience it was written for.
 */
export const AUDIENCES = Object.freeze({
  FEMALE: 'female_user',
  PARTNER: 'partner',
});

export function audienceForRole(role) {
  return role === 'man' || role === 'partner' ? AUDIENCES.PARTNER : AUDIENCES.FEMALE;
}

/**
 * The partner community is anonymous by default (spec §12).
 */
export function defaultAnonymity(audience) {
  return audience === AUDIENCES.PARTNER;
}

export const MODERATION_STATES = Object.freeze({
  VISIBLE: 'visible',
  PENDING_REVIEW: 'pending_review',
  MEDICAL_REVIEW: 'medical_review',
  WARNED: 'warned',
  HIDDEN: 'hidden',
  REMOVED: 'removed',
});

/**
 * States in which a post is still shown in a feed. `warned` stays visible with
 * a notice attached rather than being taken down, because most flagged health
 * talk is people sharing experience, not misinformation.
 */
const VISIBLE_STATES = new Set([MODERATION_STATES.VISIBLE, MODERATION_STATES.WARNED]);

export function isVisibleState(state) {
  return VISIBLE_STATES.has(state ?? MODERATION_STATES.VISIBLE);
}

export const REPORT_REASONS = Object.freeze([
  'misinformation',
  'harmful_advice',
  'harassment',
  'spam',
  'off_topic',
  'privacy',
  'other',
]);

export function isValidReportReason(reason) {
  return REPORT_REASONS.includes(reason);
}

/**
 * Topics that get extra safeguards (spec §12). A post touching one of these is
 * not suppressed - it is routed for medical review when it also makes a
 * treatment-style claim.
 *
 * The spec names PCOS, fertility, pregnancy, postpartum, HRT, supplements and
 * treatment claims. The remaining conditions here are the ones Blushy's own
 * condition picker offers, because a user posting about endometriosis or PMDD
 * is in exactly the same position as one posting about PCOS, and it would be
 * inconsistent to attach a notice to one and not the other.
 */
export const SENSITIVE_TOPICS = Object.freeze({
  pcos: ['pcos', 'polycystic'],
  endometriosis: ['endometriosis', 'endo flare'],
  adenomyosis: ['adenomyosis'],
  pmdd: ['pmdd', 'pmt', 'premenstrual dysphoric'],
  fibroids: ['fibroid'],
  thyroid: ['thyroid', 'hypothyroid', 'hyperthyroid', 'hashimoto'],
  menopause: ['menopause', 'perimenopause', 'hot flush', 'hot flash'],
  fertility: ['fertility', 'ttc', 'trying to conceive', 'ivf', 'iui', 'ovulation induction'],
  pregnancy: ['pregnant', 'pregnancy', 'trimester', 'miscarriage'],
  postpartum: ['postpartum', 'post partum', 'after birth', 'breastfeeding', 'lactation'],
  hrt: ['hrt', 'hormone replacement', 'oestrogen', 'estrogen', 'progesterone patch'],
  supplements: ['supplement', 'inositol', 'berberine', 'ashwagandha', 'dim ', 'vitex', 'maca'],
  treatment: ['metformin', 'letrozole', 'clomid', 'spironolactone', 'dose', 'dosage', 'mg of', 'prescription'],
});

/**
 * Phrasing that turns a personal account into advice for others. This is the
 * distinction that matters: "this worked for me" is experience, "you should
 * take X" is a treatment claim.
 */
const CLAIM_PATTERNS = [
  /\byou should (?:take|try|stop|use)\b/i,
  /\byou need to (?:take|try|stop|use)\b/i,
  /\bstop taking\b/i,
  /\bdon'?t take your\b/i,
  /\bcures?\b/i,
  /\bwill cure\b/i,
  /\bguaranteed?\b/i,
  /\breverses?\s+(?:pcos|endometriosis|infertility)\b/i,
  /\bdoctors? (?:are wrong|don'?t want you to know|won'?t tell you)\b/i,
  /\bno need (?:for|to see) a doctor\b/i,
  /\binstead of (?:your )?(?:medication|treatment|prescription)\b/i,
];

const DOSAGE_PATTERN = /\b\d+\s?(?:mg|mcg|ml|iu)\b/i;

function normalize(text) {
  return String(text ?? '').toLowerCase();
}

/**
 * Which sensitive topics a post touches.
 */
export function detectSensitiveTopics(text) {
  const haystack = normalize(text);
  const found = [];
  for (const [topic, terms] of Object.entries(SENSITIVE_TOPICS)) {
    if (terms.some((term) => haystack.includes(term))) found.push(topic);
  }
  return found;
}

/**
 * Whether the wording reads as advice or a claim rather than personal
 * experience.
 */
export function detectClaims(text) {
  const value = String(text ?? '');
  const matched = CLAIM_PATTERNS.filter((pattern) => pattern.test(value)).map((p) => p.source);
  if (DOSAGE_PATTERN.test(value)) matched.push('dosage_mentioned');
  return matched;
}

/**
 * How many reports before a post is held pending review.
 */
export const REPORT_THRESHOLD = 3;

/**
 * A single report alleging misinformation on a sensitive-topic post is enough
 * to route it for clinical review, because that is the combination the spec
 * asks for extra care around.
 */
export function evaluatePost({ title = '', text = '', reportCount = 0, reportReasons = [] } = {}) {
  const body = `${title}\n${text}`;
  const topics = detectSensitiveTopics(body);
  const claims = detectClaims(body);

  const alleged = new Set(reportReasons);
  const medicalConcernReported = alleged.has('misinformation') || alleged.has('harmful_advice');

  // Enough people flagged it that a human should look.
  if (reportCount >= REPORT_THRESHOLD) {
    return decision(MODERATION_STATES.PENDING_REVIEW, 'report_threshold_reached', topics, claims);
  }

  // A treatment-style claim on a sensitive topic goes to clinical review.
  if (topics.length > 0 && claims.length > 0) {
    return decision(MODERATION_STATES.MEDICAL_REVIEW, 'claim_on_sensitive_topic', topics, claims);
  }

  if (medicalConcernReported && topics.length > 0) {
    return decision(MODERATION_STATES.MEDICAL_REVIEW, 'reported_medical_concern', topics, claims);
  }

  // Sensitive topic discussed as personal experience: visible, with the
  // standing reminder that community posts are not medical advice.
  if (topics.length > 0) {
    return decision(MODERATION_STATES.WARNED, 'sensitive_topic_discussion', topics, claims);
  }

  if (claims.length > 0) {
    return decision(MODERATION_STATES.WARNED, 'claim_language', topics, claims);
  }

  return decision(MODERATION_STATES.VISIBLE, null, topics, claims);
}

/**
 * Comments are evaluated by the same rules as posts. A treatment claim is no
 * safer for being in a reply, so this is a named alias rather than a separate,
 * weaker path.
 */
export function evaluateComment({ text = '', reportCount = 0, reportReasons = [] } = {}) {
  return evaluatePost({ title: '', text, reportCount, reportReasons });
}

function decision(state, reason, topics, claims) {
  return {
    state,
    reason,
    sensitiveTopics: topics,
    claimSignals: claims,
    // Attached to anything touching health, so a reader is never left to infer
    // that a post carries clinical authority (spec §12).
    notice: topics.length > 0 || claims.length > 0
      ? 'Shared from personal experience by a community member. This is not medical advice and has not been clinically reviewed.'
      : null,
    requiresHumanReview: state === MODERATION_STATES.PENDING_REVIEW || state === MODERATION_STATES.MEDICAL_REVIEW,
    rulesetVersion: MODERATION_RULESET_VERSION,
  };
}

/**
 * Moderator actions and the state each produces. Only a human can clear a post
 * back to visible or remove it.
 */
export const MODERATOR_ACTIONS = Object.freeze({
  approve: MODERATION_STATES.VISIBLE,
  attach_warning: MODERATION_STATES.WARNED,
  hide: MODERATION_STATES.HIDDEN,
  remove: MODERATION_STATES.REMOVED,
  escalate_medical: MODERATION_STATES.MEDICAL_REVIEW,
});

export function isValidModeratorAction(action) {
  return Object.prototype.hasOwnProperty.call(MODERATOR_ACTIONS, action);
}

/**
 * Whether a viewer may see a post, given audience, moderation state and blocks.
 *
 * Authors always retain sight of their own post so a hidden post does not
 * simply vanish for the person who wrote it.
 */
export function canView({
  post,
  viewerUserId,
  viewerAudience,
  blockedAuthorIds = [],
  isModerator = false,
}) {
  if (!post) return false;
  if (isModerator) return true;

  const isAuthor = post.authorId === viewerUserId;
  if (isAuthor) return post.moderationState !== MODERATION_STATES.REMOVED;

  // Audiences are separate: a partner never sees the female community feed.
  if (post.audience !== viewerAudience) return false;

  if (blockedAuthorIds.includes(post.authorId)) return false;

  return isVisibleState(post.moderationState);
}
