/**
 * Companion nudges: small, one-tap gestures a companion sends TO the woman.
 *
 * The catalogue is server-authoritative: the client sends only a `nudgeId`, and
 * the server looks up the delivered message here. That prevents arbitrary text
 * injection and keeps a family/friend companion from sending romantic content —
 * the allowed nudges are scoped by the connection's capability category
 * (see partnerRelationshipTypes.js).
 *
 * Pure module: unit-testable without a database.
 */

import { RELATIONSHIP_CATEGORIES } from './partnerRelationshipTypes.js';

const CAREGIVER_NUDGES = [
  { id: 'snacks', label: 'Got your snacks', message: 'Picked up your favourite snacks 🛍️' },
  { id: 'take_it_easy', label: 'Take it easy', message: 'Take it easy today, I’ve got things covered 💛' },
  { id: 'hot_water_bottle', label: 'Hot water bottle', message: 'On my way with a hot water bottle 🔥' },
  { id: 'chores_handled', label: 'Chores tonight', message: 'Handling chores tonight — just rest 🧹' },
  { id: 'proud_of_you', label: 'Proud of you', message: 'So proud of you 💛' },
];

const FRIEND_NUDGES = [
  { id: 'virtual_chocolate', label: 'Virtual chocolate', message: 'Sending you virtual chocolate 🍫' },
  { id: 'cramp_hug', label: 'Cramp hug', message: 'Sending a big cramp hug 🧸' },
  { id: 'thinking_of_you', label: 'Thinking of you', message: 'Thinking of you today 💕' },
  { id: 'hangout', label: 'Hangout soon?', message: 'Pyjama + movie hangout soon? 🎬' },
  { id: 'you_got_this', label: 'You got this', message: 'You’ve got this 💪' },
];

const ROMANTIC_NUDGES = [
  { id: 'thinking_of_you', label: 'Thinking of you', message: 'Thinking of you 💭❤️' },
  { id: 'bringing_treat', label: 'Bringing a treat', message: 'Bringing your favourite coffee/tea ☕' },
  { id: 'massage_offer', label: 'Offer a rub', message: 'Offering a shoulder or foot rub later 💆' },
  { id: 'here_for_you', label: 'Here for you', message: 'I’m here for you ❤️' },
];

/**
 * The nudges each capability category may send. Co-parent/caregiver share the
 * caregiver set. A null/unset category gets a small, safe neutral set.
 */
const NUDGES_BY_CATEGORY = Object.freeze({
  [RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER]: ROMANTIC_NUDGES,
  [RELATIONSHIP_CATEGORIES.FAMILY]: CAREGIVER_NUDGES,
  [RELATIONSHIP_CATEGORIES.COPARENT_CAREGIVER]: CAREGIVER_NUDGES,
  [RELATIONSHIP_CATEGORIES.FRIEND]: FRIEND_NUDGES,
});

// Unset/legacy connections: a neutral, non-romantic subset.
const NEUTRAL_NUDGES = [
  { id: 'thinking_of_you', label: 'Thinking of you', message: 'Thinking of you 💛' },
];

/**
 * The nudge list a companion in this category may send (for the client UI).
 */
export function nudgesForCategory(category) {
  if (!category) return NEUTRAL_NUDGES;
  return NUDGES_BY_CATEGORY[category] ?? NEUTRAL_NUDGES;
}

/**
 * Resolves a nudgeId to its catalogue entry for the given category, or null if
 * the id is unknown or not allowed for that category.
 */
export function resolveNudge(category, nudgeId) {
  if (typeof nudgeId !== 'string' || !nudgeId) return null;
  const list = nudgesForCategory(category);
  return list.find((n) => n.id === nudgeId) ?? null;
}
