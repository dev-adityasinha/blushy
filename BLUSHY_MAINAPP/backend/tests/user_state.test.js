import assert from 'node:assert/strict';
import test, { before, after } from 'node:test';
import { startTestServer, stopTestServer, api, createTestUser } from './helpers/testServer.js';

before(async () => { await startTestServer(); });
after(async () => { await stopTestServer(); });

/**
 * Thirteen screen documents lived only on the device. This is the store that
 * moves them onto the account: generic on purpose, because the shapes differ
 * and none is queried by anything but its own screen.
 */
test('a document round-trips and comes back with everything else', async () => {
  const woman = await createTestUser({ role: 'woman' });

  const empty = await api('GET', '/api/v1/user-state', { token: woman.token });
  assert.equal(empty.status, 200);
  assert.deepEqual(empty.body.state, {}, 'a new account starts empty');

  const put = await api('PUT', '/api/v1/user-state/stage4_treatments', {
    token: woman.token,
    body: { value: { items: [{ name: 'Metformin', dose: '500mg' }] } },
  });
  assert.equal(put.status, 200);

  await api('PUT', '/api/v1/user-state/stage3_life_mode', {
    token: woman.token, body: { value: { mode: 'gentle' } },
  });

  const all = await api('GET', '/api/v1/user-state', { token: woman.token });
  assert.equal(all.body.state.stage4_treatments.items[0].name, 'Metformin');
  assert.equal(all.body.state.stage3_life_mode.mode, 'gentle');
});

test('a second write replaces rather than accumulating', async () => {
  const woman = await createTestUser({ role: 'woman' });
  const k = '/api/v1/user-state/stage1_period_kit';
  await api('PUT', k, { token: woman.token, body: { value: { items: ['pads'] } } });
  await api('PUT', k, { token: woman.token, body: { value: { items: ['pads', 'spare'] } } });

  const all = await api('GET', '/api/v1/user-state', { token: woman.token });
  assert.deepEqual(all.body.state.stage1_period_kit.items, ['pads', 'spare'],
    'the screen owns the whole document, so last write wins');
});

test('one account never sees another', async () => {
  const a = await createTestUser({ role: 'woman' });
  const b = await createTestUser({ role: 'woman' });
  await api('PUT', '/api/v1/user-state/partner_letters', {
    token: a.token, body: { value: { letters: ['private'] } },
  });

  const seen = await api('GET', '/api/v1/user-state', { token: b.token });
  assert.deepEqual(seen.body.state, {}, 'state is scoped to the token, never the body');
});

test('it refuses what it should', async () => {
  const woman = await createTestUser({ role: 'woman' });

  const noAuth = await api('GET', '/api/v1/user-state');
  assert.equal(noAuth.status, 401);

  const badKey = await api('PUT', '/api/v1/user-state/Not-A-Key!', {
    token: woman.token, body: { value: {} },
  });
  assert.equal(badKey.status, 400, 'keys are namespaced and validated');

  const noValue = await api('PUT', '/api/v1/user-state/stage3_noticings', {
    token: woman.token, body: {},
  });
  assert.equal(noValue.status, 400, 'a missing value is not an empty one');

  const huge = await api('PUT', '/api/v1/user-state/stage3_noticings', {
    token: woman.token, body: { value: { blob: 'x'.repeat(300 * 1024) } },
  });
  assert.equal(huge.status, 413, 'this is a document store, not a file store');
});

test('deleting removes only that document', async () => {
  const woman = await createTestUser({ role: 'woman' });
  await api('PUT', '/api/v1/user-state/stage2_school_bag', { token: woman.token, body: { value: { a: 1 } } });
  await api('PUT', '/api/v1/user-state/stage3_noticings', { token: woman.token, body: { value: { b: 2 } } });

  const del = await api('DELETE', '/api/v1/user-state/stage2_school_bag', { token: woman.token });
  assert.equal(del.body.deleted, 1);

  const all = await api('GET', '/api/v1/user-state', { token: woman.token });
  assert.equal(all.body.state.stage2_school_bag, undefined);
  assert.equal(all.body.state.stage3_noticings.b, 2);
});
