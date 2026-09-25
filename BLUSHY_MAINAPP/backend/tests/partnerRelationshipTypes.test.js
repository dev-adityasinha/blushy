import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  normalizeRelationshipType,
  categoryForType,
  capabilitiesForType,
  forbiddenGrantsForType,
  isRelationshipTypeAllowedForStage,
  isRelationshipTypeAllowedFor,
  isMinorByDateOfBirth,
  ageFromDateOfBirth,
  allowedCategoriesForStage,
  RELATIONSHIP_CATEGORIES,
} from '../src/domain/partnerRelationshipTypes.js';
import { buildPartnerSafeContext } from '../src/domain/partnerPermissions.js';

test('relationship types normalize, including common aliases', () => {
  assert.equal(normalizeRelationshipType('Mom'), 'mother');
  assert.equal(normalizeRelationshipType('DAD'), 'father');
  assert.equal(normalizeRelationshipType('best friend'), 'best_friend');
  assert.equal(normalizeRelationshipType('boyfriend'), 'boyfriend');
  assert.equal(normalizeRelationshipType('nonsense'), null);
  assert.equal(normalizeRelationshipType(null), null);
});

test('each type maps to the right capability category', () => {
  assert.equal(categoryForType('boyfriend'), RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER);
  assert.equal(categoryForType('mother'), RELATIONSHIP_CATEGORIES.FAMILY);
  assert.equal(categoryForType('best_friend'), RELATIONSHIP_CATEGORIES.FRIEND);
  assert.equal(categoryForType('doula'), RELATIONSHIP_CATEGORIES.COPARENT_CAREGIVER);
});

test('only romantic types get the couple surface', () => {
  assert.equal(capabilitiesForType('boyfriend').coupleFeatures, true);
  assert.equal(capabilitiesForType('mother').coupleFeatures, false);
  assert.equal(capabilitiesForType('best_friend').coupleFeatures, false);
  // family/friend get their own experiences instead
  assert.equal(capabilitiesForType('mother').caregiverTools, true);
  assert.equal(capabilitiesForType('best_friend').peerSupport, true);
  // an unset type grants no experience and is never romantic
  assert.equal(capabilitiesForType(null).coupleFeatures, false);
});

test('the fertile window is hard-forbidden for parents and friends', () => {
  assert.deepEqual(forbiddenGrantsForType('mother'), ['fertility.window']);
  assert.deepEqual(forbiddenGrantsForType('best_friend'), ['fertility.window']);
  assert.deepEqual(forbiddenGrantsForType('boyfriend'), []);
  assert.deepEqual(forbiddenGrantsForType('coparent'), []);
});

test('minor life stage forbids a romantic companion but allows family and friends', () => {
  assert.equal(isRelationshipTypeAllowedForStage('boyfriend', 'first_period'), false);
  assert.equal(isRelationshipTypeAllowedForStage('mother', 'first_period'), true);
  assert.equal(isRelationshipTypeAllowedForStage('best_friend', 'first_period'), true);
  // adults may connect anyone
  assert.equal(isRelationshipTypeAllowedForStage('boyfriend', 'cycle_tracking'), true);
  // an unset type is always allowed (it grants nothing)
  assert.equal(isRelationshipTypeAllowedForStage(null, 'first_period'), true);
  assert.ok(!allowedCategoriesForStage('first_period').includes(RELATIONSHIP_CATEGORIES.ROMANTIC_PARTNER));
});

test('date of birth under 18 blocks a romantic companion even in an adult stage', () => {
  const now = new Date();
  const dobUnder = `${now.getFullYear() - 15}-01-01`; // ~15 years old
  const dobAdult = `${now.getFullYear() - 30}-01-01`; // ~30 years old

  assert.equal(isMinorByDateOfBirth(dobUnder), true);
  assert.equal(isMinorByDateOfBirth(dobAdult), false);
  assert.equal(isMinorByDateOfBirth(null), false);
  assert.equal(ageFromDateOfBirth('not-a-date'), null);

  // Stage says adult, but the stated DOB is a minor -> romantic refused.
  assert.equal(
    isRelationshipTypeAllowedFor({ type: 'boyfriend', lifeStage: 'cycle_tracking', dateOfBirth: dobUnder }),
    false,
  );
  // Family is still fine for a minor.
  assert.equal(
    isRelationshipTypeAllowedFor({ type: 'mother', lifeStage: 'cycle_tracking', dateOfBirth: dobUnder }),
    true,
  );
  // An adult by DOB in an adult stage can add a romantic companion.
  assert.equal(
    isRelationshipTypeAllowedFor({ type: 'boyfriend', lifeStage: 'cycle_tracking', dateOfBirth: dobAdult }),
    true,
  );
  // No DOB falls back to the stage rule alone.
  assert.equal(
    isRelationshipTypeAllowedFor({ type: 'boyfriend', lifeStage: 'cycle_tracking', dateOfBirth: null }),
    true,
  );
});

test('the safe context hard-caps the fertile window for a parent even when permitted', () => {
  const full = {
    preferredName: 'Nithya',
    lifeStage: 'cycle_tracking',
    relationshipType: 'mother',
    cyclePhase: { phase: 'luteal', cycleDay: 20 },
    fertileWindow: { start: 'x', end: 'y' },
    mood: { value: 'ok' },
  };
  // She turned everything on -- the hard cap must still strip the fertile window.
  const perms = { cycle_insights: true, fertility_insights: true, mood: true };
  const r = buildPartnerSafeContext(full, perms, { connectionState: 'accepted' });

  assert.equal(r.context.relationshipCategory, RELATIONSHIP_CATEGORIES.FAMILY);
  assert.equal(r.context.capabilities.coupleFeatures, false);
  assert.ok(r.context.cyclePhase, 'cycle phase she shared still reaches her mother');
  assert.equal(r.context.fertileWindow, undefined, 'fertile window is hard-capped off');
  assert.ok(r.context.mood, 'mood she shared still reaches her mother');
  assert.ok(!r.allowedGrants.includes('fertility.window'));
});

test('a romantic partner sees the fertile window she shared and the couple surface', () => {
  const full = {
    preferredName: 'Nithya',
    lifeStage: 'ttc',
    relationshipType: 'boyfriend',
    fertileWindow: { start: 'x', end: 'y' },
  };
  const perms = { fertility_insights: true };
  const r = buildPartnerSafeContext(full, perms, { connectionState: 'accepted' });
  assert.equal(r.context.capabilities.coupleFeatures, true);
  assert.ok(r.context.fertileWindow, 'romantic partner may see the fertile window');
});
