import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  womanAlerts,
  resolveWomanAlert,
  renderAlertMessage,
  WOMAN_ALERT_IDS,
} from '../src/domain/partnerAlerts.js';

test('the alert catalogue exposes id/label pairs for the client', () => {
  const list = womanAlerts();
  assert.ok(list.length >= 2);
  for (const a of list) {
    assert.ok(a.id && typeof a.id === 'string');
    assert.ok(a.label && typeof a.label === 'string');
  }
  assert.ok(WOMAN_ALERT_IDS.includes('need_pad'));
});

test('resolveWomanAlert returns the entry or null', () => {
  const pad = resolveWomanAlert('need_pad');
  assert.ok(pad);
  assert.equal(pad.title, 'Pad Squad');
  assert.equal(resolveWomanAlert('nope'), null);
  assert.equal(resolveWomanAlert(''), null);
  assert.equal(resolveWomanAlert(null), null);
});

test('renderAlertMessage fills the sender name, with a safe fallback', () => {
  const pad = resolveWomanAlert('need_pad');
  assert.ok(renderAlertMessage(pad, 'Maya').startsWith('Maya needs a pad'));
  assert.ok(renderAlertMessage(pad, '').startsWith('Someone needs a pad'));
  assert.ok(renderAlertMessage(pad, null).startsWith('Someone needs a pad'));
  // The placeholder must not survive.
  assert.ok(!renderAlertMessage(pad, 'Maya').includes('{name}'));
});
