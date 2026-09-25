import { test } from 'node:test';
import assert from 'node:assert/strict';

import { nudgesForCategory, resolveNudge } from '../src/domain/partnerNudges.js';
import { categoryForType, RELATIONSHIP_CATEGORIES } from '../src/domain/partnerRelationshipTypes.js';

test('each category offers a non-empty nudge set', () => {
  for (const cat of Object.values(RELATIONSHIP_CATEGORIES)) {
    assert.ok(nudgesForCategory(cat).length > 0, `$${cat} has nudges`);
  }
});

test('nudges are scoped: a romantic nudge is not sendable by a family companion', () => {
  const familyCat = categoryForType('mother');
  const romanticCat = categoryForType('boyfriend');

  // "massage_offer" is a romantic-only nudge.
  assert.ok(resolveNudge(romanticCat, 'massage_offer'), 'romantic can send it');
  assert.equal(resolveNudge(familyCat, 'massage_offer'), null, 'family cannot');

  // A caregiver nudge is not in the romantic set.
  assert.ok(resolveNudge(familyCat, 'hot_water_bottle'), 'family can send caregiver nudge');
  assert.equal(resolveNudge(romanticCat, 'hot_water_bottle'), null, 'romantic set has no hot_water_bottle');
});

test('an unknown nudge id resolves to null', () => {
  assert.equal(resolveNudge(categoryForType('best_friend'), 'not_a_real_nudge'), null);
  assert.equal(resolveNudge(categoryForType('best_friend'), ''), null);
  assert.equal(resolveNudge(categoryForType('best_friend'), null), null);
});

test('an unset category falls back to a neutral, non-romantic nudge set', () => {
  const list = nudgesForCategory(null);
  assert.ok(list.length > 0);
  // The neutral set must not contain the romantic-only massage offer.
  assert.equal(list.find((n) => n.id === 'massage_offer'), undefined);
});

test('every nudge has an id, a label and a delivered message', () => {
  for (const cat of Object.values(RELATIONSHIP_CATEGORIES)) {
    for (const n of nudgesForCategory(cat)) {
      assert.ok(n.id && typeof n.id === 'string');
      assert.ok(n.label && typeof n.label === 'string');
      assert.ok(n.message && typeof n.message === 'string');
    }
  }
});
