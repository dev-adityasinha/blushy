import test from 'node:test';
import assert from 'node:assert/strict';

// Only the pure module: importing the service would open a database
// connection this test never uses, and hold the process open waiting on it.
import { joinedAfterReportingMonth } from '../src/utils/monthWindow.js';

/// The window mid-August reports on. Asserted against the service's own
/// boundary logic in `monthlyInsights.test.js`, which has a database.
const endDate = '2026-07-31';

/**
 * The monthly card reports the last *completed* calendar month, so through
 * August it reports July. Someone who installed the app in August was shown a
 * list of things she had "not logged" in a month she was never here for.
 */
test('a month that ended before the account existed is not hers to have missed', () => {
  // Installed in August: July is not a month she failed to log.
  assert.equal(joinedAfterReportingMonth('2026-08-03T09:00:00.000Z', endDate), true);

  // Here for the whole month, and for part of it: both are real gaps, and
  // silencing those would hide her own data from her.
  assert.equal(joinedAfterReportingMonth('2026-05-01T09:00:00.000Z', endDate), false);
  assert.equal(joinedAfterReportingMonth('2026-07-20T09:00:00.000Z', endDate), false);
});

test('the boundary is the last instant of the month, not the first', () => {
  // Joining on the final day still counts as having been here for it.
  assert.equal(joinedAfterReportingMonth('2026-07-31T23:00:00.000Z', endDate), false);
  assert.equal(joinedAfterReportingMonth('2026-08-01T00:30:00.000Z', endDate), true);
});

test('an unknown or unparseable join date reports the month as before', () => {
  // Older accounts predate the field. Hiding the card for them would remove a
  // month they really did use, so the absence of a date must not suppress it.
  assert.equal(joinedAfterReportingMonth(null, endDate), false);
  assert.equal(joinedAfterReportingMonth(undefined, endDate), false);
  assert.equal(joinedAfterReportingMonth('not a date', endDate), false);
});

test('a Date object works as well as an ISO string', () => {
  assert.equal(joinedAfterReportingMonth(new Date('2026-08-03'), endDate), true);
  assert.equal(joinedAfterReportingMonth(new Date('2026-06-03'), endDate), false);
});
