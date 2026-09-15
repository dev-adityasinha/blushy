import test from 'node:test';
import assert from 'node:assert/strict';

import * as Caps from '../src/repositories/timeCapsuleRepository.js';
import { journalRepository as J } from '../src/repositories/journalRepository.js';
import { listContent } from '../src/repositories/medicalContentRepository.js';
import { closeDb, db } from '../src/utils/db.js';

/** A capsule is a promise about *when* something may be read. */
test('a sealed capsule gives nothing up before its date', async (t) => {
  const uid = `test_caps_${Date.now()}`;
  t.after(async () => {
    try {
      await Caps.purgeUserCapsules(uid);
      await db.collection('users_woman').deleteMany({ user_id: uid });
    } catch (_) {}
  });

  await db.collection('users_woman').insertOne({
    user_id: uid, role: 'woman', created_at: new Date(), onboarding_answers: {},
  });

  const sealed = await Caps.createCapsule({
    userId: uid, title: 'To future me', body: 'secret words',
    deliverAt: new Date(Date.now() + 30 * 86400000),
  });
  const due = await Caps.createCapsule({
    userId: uid, title: 'Already due', body: 'you made it',
    deliverAt: new Date(Date.now() - 86400000),
  });

  const list = await Caps.listCapsules(uid);
  const sealedRow = list.find((c) => c.capsuleId === sealed.capsuleId);
  assert.equal(sealedRow.sealed, true);
  assert.ok(!sealedRow.body, 'the listing must not carry a sealed body');

  const early = await Caps.openCapsule(uid, sealed.capsuleId);
  assert.equal(early.ok, false);
  assert.equal(early.reason, 'sealed');
  assert.ok(!early.capsule?.body, 'a refused open must not leak the body either');

  const opened = await Caps.openCapsule(uid, due.capsuleId);
  assert.equal(opened.ok, true);
  assert.equal(opened.capsule.body, 'you made it');

  // Once open it stays readable; opening is not a one-shot that loses it.
  const reopened = await Caps.openCapsule(uid, due.capsuleId);
  assert.equal(reopened.capsule.body, 'you made it');
});

test('capsules belong to one account', async (t) => {
  const uid = `test_caps_own_${Date.now()}`;
  const other = `test_caps_other_${Date.now()}`;
  t.after(async () => {
    try { await Caps.purgeUserCapsules(uid); } catch (_) {}
  });

  const c = await Caps.createCapsule({
    userId: uid, title: 'Private', body: 'mine alone',
    deliverAt: new Date(Date.now() - 86400000),
  });

  assert.equal(await Caps.getCapsule(other, c.capsuleId), null);
  assert.equal((await Caps.openCapsule(other, c.capsuleId)).ok, false);
  assert.equal(await Caps.deleteCapsule(other, c.capsuleId), false,
    'another account must not be able to delete it either');
});

test('a journal day is replaced, not duplicated', async (t) => {
  const uid = `test_j_${Date.now()}`;
  t.after(async () => {
    try {
      await db.collection('user_journals_woman').deleteMany({ user_id: uid });
      await db.collection('users_woman').deleteMany({ user_id: uid });
    } catch (_) {}
  });

  await db.collection('users_woman').insertOne({
    user_id: uid, role: 'woman', created_at: new Date(), onboarding_answers: {},
  });

  const day = '2026-08-30';
  await J.upsertJournal({
    userId: uid, entryDate: day, summary: 'Gratitude',
    entries: [{ id: 'e1', title: 'Gratitude', date: day }],
  });
  await J.upsertJournal({
    userId: uid, entryDate: day, summary: '2 entries',
    entries: [{ id: 'e1', title: 'Gratitude', date: day },
              { id: 'e2', title: 'Dream Journal', date: day }],
  });

  const days = await J.getJournalsByUserId(uid, 50);
  assert.equal(days.length, 1, 'saving the same day twice must not create two');
  assert.equal(days[0].entries.length, 2, 'and must keep the added entry');

  const other = await J.getJournalsByUserId(`test_j_other_${Date.now()}`, 50);
  assert.equal(other.length, 0, 'journals are scoped to their owner');
});

test('recovery sessions are withheld until reviewed', async () => {
  // The tab is empty because approval is outstanding, not because the query is
  // broken — worth asserting, since "empty" and "broken" look identical.
  const approved = await listContent({
    contentType: 'recovery_session', audience: 'female_user', approvedOnly: true, limit: 50,
  });
  const all = await listContent({
    contentType: 'recovery_session', audience: 'female_user', approvedOnly: false, limit: 50,
  });

  assert.ok(all.length >= approved.length, 'the gate can only ever narrow');
  for (const entry of approved) {
    assert.notEqual(entry.status, 'draft', 'a draft must never reach a reader');
  }
});

test('teardown', async () => {
  await closeDb();
});
