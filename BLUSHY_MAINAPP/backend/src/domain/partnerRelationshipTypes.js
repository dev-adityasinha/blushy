/**
 * Companion relationship types (the "who is this to you?" layer).
 *
 * The permission matrix in `partnerPermissions.js` decides WHAT data a companion
 * may see, field by field, all default-off. This module adds the orthogonal
 * question of WHO the companion is, which drives three things:
 *
 *   1. capabilities  - which whole experiences the companion app renders
 *                      (the romantic couple surface, caregiver tools, peer
 *                      support). This is a HARD gate: a non-romantic companion
 *                      never sees love notes / date planner / couple games,
 *                      regardless of any data permission.
 *   2. forbiddenGrants - data grants that are stripped for this relationship
 *                      even if the woman somehow enabled them. Defence in depth
 *                      for the few fields that are inappropriate by relationship
 *                      (a parent or friend has no business seeing a fertile
 *                      window).
 *   3. stage gating  - which relationship types may exist at all for the
 *                      woman's life stage. A user in the minor `first_period`
 *                      stage can never have a romantic companion.
 *
 * Health data itself stays the woman's choice (soft, per-connection toggles);
 * the archetype only sets which experiences render and the few hard caps above.
 *
 * Pure module: no I/O, unit-testable without a database.
 */

export const RELATIONSHIP_TYPES_VERSION = 'relationship-types-v1.0.0';

/**
 * The four capability profiles. `relationship_type` (the specific label the
 * woman picks) maps onto one of these categories, which is what the rest of the
 * system reasons about.
 */
export const RELATIONSHIP_CATEGORIES = Object.freeze({
  ROMANTIC_PARTNER: 'romantic_partner',
  FAMILY: 'family',
  FRIEND: 'friend',
  COPARENT_CAREGIVER: 'coparent_caregiver',
});

/**
 * Specific relationship labels a woman can assign to a connection. Each maps to
 * exactly one category. The list is intentionally small and closed; unknown
 * values normalize to `null` (treated as an unset, capability-less connection).
 */
export const RELATIONSHIP_TYPES = Object.freeze({
  // romantic_partner
  spouse: RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER,
  husband: RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER,
  wife: RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER,
  partner: RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER,
  boyfriend: RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER,
  girlfriend: RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER,
  // family
  mother: RELATIONSHIP_CATEGORIES.FAMILY,
  father: RELATIONSHIP_CATEGORIES.FAMILY,
  sister: RELATIONSHIP_CATEGORIES.FAMILY,
  brother: RELATIONSHIP_CATEGORIES.FAMILY,
  daughter: RELATIONSHIP_CATEGORIES.FAMILY,
  son: RELATIONSHIP_CATEGORIES.FAMILY,
  parent: RELATIONSHIP_CATEGORIES.FAMILY,
  family: RELATIONSHIP_CATEGORIES.FAMILY,
  // friend
  best_friend: RELATIONSHIP_CATEGORIES.FRIEND,
  friend: RELATIONSHIP_CATEGORIES.FRIEND,
  // coparent_caregiver
  coparent: RELATIONSHIP_CATEGORIES.COPARENT_CAREGIVER,
  doula: RELATIONSHIP_CATEGORIES.COPARENT_CAREGIVER,
  caregiver: RELATIONSHIP_CATEGORIES.COPARENT_CAREGIVER,
});

export const RELATIONSHIP_TYPE_KEYS = Object.freeze(Object.keys(RELATIONSHIP_TYPES));

/**
 * Capabilities per category. These flip whole experiences on/off in the
 * companion app. `framing` is a hint the client uses for copy/persona.
 */
const CATEGORY_CAPABILITIES = Object.freeze({
  [RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER]: {
    coupleFeatures: true,   // love notes, date planner, couple games, flirty nudges
    caregiverTools: false,
    peerSupport: false,
    framing: 'romantic',
  },
  [RELATIONSHIP_CATEGORIES.FAMILY]: {
    coupleFeatures: false,
    caregiverTools: true,   // care-request inbox, supply/support prompts
    peerSupport: false,
    framing: 'family',
  },
  [RELATIONSHIP_CATEGORIES.FRIEND]: {
    coupleFeatures: false,
    caregiverTools: false,
    peerSupport: true,      // peer empathy nudges, neutral cycle-overlap view
    framing: 'peer',
  },
  [RELATIONSHIP_CATEGORIES.COPARENT_CAREGIVER]: {
    coupleFeatures: false,
    caregiverTools: true,
    peerSupport: false,
    framing: 'logistics',
  },
});

/**
 * A companion with no assigned type (legacy/unset) gets no special experience:
 * data still flows through the permission matrix, but no couple/caregiver/peer
 * surface renders. Kept conservative so an unset connection is never romantic.
 */
const NO_CAPABILITIES = Object.freeze({
  coupleFeatures: false,
  caregiverTools: false,
  peerSupport: false,
  framing: 'neutral',
});

/**
 * Data grants that are stripped for a category even if the permission is on.
 * The fertile window is intimate/reproductive-planning context: appropriate for
 * a romantic partner or a co-parent, never for a parent or a friend. Health
 * data beyond this stays the woman's choice.
 */
const CATEGORY_FORBIDDEN_GRANTS = Object.freeze({
  [RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER]: [],
  [RELATIONSHIP_CATEGORIES.FAMILY]: ['fertility.window'],
  [RELATIONSHIP_CATEGORIES.FRIEND]: ['fertility.window'],
  [RELATIONSHIP_CATEGORIES.COPARENT_CAREGIVER]: [],
});

/**
 * Canonical life stages (from `lifeStages.js`) whose user is a presumed minor.
 * `first_period` is the puberty/menarche stage; no romantic companion may be
 * attached to a connection whose owner is in it.
 */
export const MINOR_LIFE_STAGES = Object.freeze(['first_period']);

export function isMinorLifeStage(lifeStage) {
  return MINOR_LIFE_STAGES.includes(String(lifeStage ?? '').trim().toLowerCase());
}

/** Age in whole years from a date of birth, or null if unparseable. */
export function ageFromDateOfBirth(dob) {
  if (!dob) return null;
  const d = dob instanceof Date ? dob : new Date(dob);
  if (Number.isNaN(d.getTime())) return null;
  const now = new Date();
  let age = now.getFullYear() - d.getFullYear();
  const beforeBirthday =
    now.getMonth() < d.getMonth() ||
    (now.getMonth() === d.getMonth() && now.getDate() < d.getDate());
  if (beforeBirthday) age -= 1;
  return age;
}

/** True when a stated date of birth puts the person under 18. */
export function isMinorByDateOfBirth(dob) {
  const age = ageFromDateOfBirth(dob);
  return age != null && age < 18;
}

/**
 * Whether the woman should be treated as a minor for companion gating. True if
 * either her life stage is a minor stage (first_period) OR her stated date of
 * birth is under 18. Date of birth is self-declared, so this is a strengthening,
 * not identity-verified age assurance.
 */
export function isMinorContext({ lifeStage, dateOfBirth } = {}) {
  return isMinorLifeStage(lifeStage) || isMinorByDateOfBirth(dateOfBirth);
}

/**
 * Normalizes a client-supplied relationship type to a known key, or null.
 * Accepts a few obvious aliases so the client vocabulary can drift a little
 * without silently dropping the type.
 */
export function normalizeRelationshipType(input) {
  if (typeof input !== 'string') return null;
  const key = input.trim().toLowerCase().replace(/[\s-]+/g, '_');
  if (RELATIONSHIP_TYPES[key]) return key;
  const ALIASES = {
    mom: 'mother',
    mum: 'mother',
    mummy: 'mother',
    dad: 'father',
    daddy: 'father',
    bestie: 'best_friend',
    bff: 'best_friend',
    sis: 'sister',
    bro: 'brother',
    hubby: 'husband',
    so: 'partner',
    significant_other: 'partner',
    co_parent: 'coparent',
  };
  return ALIASES[key] ?? null;
}

export function categoryForType(type) {
  const key = normalizeRelationshipType(type);
  return key ? RELATIONSHIP_TYPES[key] : null;
}

export function capabilitiesForType(type) {
  const category = categoryForType(type);
  return category ? CATEGORY_CAPABILITIES[category] : NO_CAPABILITIES;
}

export function forbiddenGrantsForType(type) {
  const category = categoryForType(type);
  return category ? CATEGORY_FORBIDDEN_GRANTS[category] : [];
}

/**
 * Which categories are permitted for a woman in the given life stage. Minor
 * stages exclude the romantic category entirely.
 */
export function allowedCategoriesForStage(lifeStage) {
  const all = Object.values(RELATIONSHIP_CATEGORIES);
  if (isMinorLifeStage(lifeStage)) {
    return all.filter((c) => c !== RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER);
  }
  return all;
}

/**
 * Child-safety choke point (life stage only). Rejects romantic types for a minor
 * stage. An unset/null type is always allowed (it grants no experience). Prefer
 * {@link isRelationshipTypeAllowedFor} where a date of birth is available.
 */
export function isRelationshipTypeAllowedForStage(type, lifeStage) {
  const category = categoryForType(type);
  if (!category) return true;
  return allowedCategoriesForStage(lifeStage).includes(category);
}

/**
 * Child-safety choke point using both life stage and stated date of birth.
 * A romantic companion is refused whenever the woman reads as a minor by either
 * signal; other categories follow the stage rule. An unset/null type is always
 * allowed.
 */
export function isRelationshipTypeAllowedFor({ type, lifeStage, dateOfBirth } = {}) {
  const category = categoryForType(type);
  if (!category) return true;
  if (
    category === RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER &&
    isMinorContext({ lifeStage, dateOfBirth })
  ) {
    return false;
  }
  return allowedCategoriesForStage(lifeStage).includes(category);
}
