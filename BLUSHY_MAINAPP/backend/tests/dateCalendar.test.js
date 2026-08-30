import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';

import { todayIso, dayStart, dayIsoFromStored } from '../src/utils/appCalendar.js';

/**
 * There must be exactly one answer to "what day is it".
 *
 * There were four, and they disagreed: the mood repository used Asia/Kolkata,
 * the sleep repository used UTC, moodFromChatService used UTC while writing
 * through the Kolkata-based mood repository, and cycleFromChatService kept its
 * own Kolkata copy. A row written under one calendar and read under another is
 * simply not found, so between 00:00 and 05:30 IST a logged mood disappeared
 * from the dashboard and from the partner decoder.
 */

test('calendar: only appCalendar defines the app day', async () => {
  // Source-level, because a second definition that happens to agree today is
  // still the bug waiting to happen -- the original four agreed for 18.5 hours
  // out of every 24.
  const offenders = [];

  async function walk(dir) {
    for (const entry of await readdir(new URL(dir, import.meta.url), { withFileTypes: true })) {
      const child = `${dir}${entry.name}${entry.isDirectory() ? '/' : ''}`;
      if (entry.isDirectory()) {
        await walk(child);
        continue;
      }
      if (!entry.name.endsWith('.js')) continue;
      if (child.endsWith('utils/appCalendar.js')) continue;

      const source = await readFile(new URL(child, import.meta.url), 'utf8');
      if (/function\s+todayIso\w*\s*\(/.test(source)) offenders.push(child);
    }
  }
  await walk('../src/');

  assert.deepEqual(offenders, [],
    `these define their own notion of today -- import it from utils/appCalendar.js instead: ${offenders.join(', ')}`);
});

test('calendar: a stored day reads back as the same day', () => {
  const today = todayIso();
  assert.equal(dayIsoFromStored(dayStart(today)), today);
});

test('calendar: a day is keyed to its start in India, not UTC midnight', () => {
  // UTC midnight sits 5.5 hours *inside* the Indian day it claims to name, so
  // the same logical day could be written under two different instants.
  assert.equal(dayStart('2026-04-19').toISOString(), '2026-04-18T18:30:00.000Z');
});

test('calendar: both stored formats already in the database read correctly', () => {
  // Live data holds two shapes: rows written by the older code at India
  // midnight, and rows written by the newer code at UTC midnight. Reads must
  // resolve both to the day the writer meant, or half the history disappears.
  assert.equal(dayIsoFromStored(new Date('2026-04-18T18:30:00.000Z')), '2026-04-19');
  assert.equal(dayIsoFromStored(new Date('2026-04-19T00:00:00.000Z')), '2026-04-19');
});

test('calendar: reading a stored day does not depend on the server timezone', async () => {
  // This machine may be set to IST while Render runs in UTC, so a behavioural
  // check passes here and fails in production. The repositories used
  // getFullYear/getMonth/getDate, which are server-local -- asserting against
  // the source is the only way to catch that from either machine.
  for (const file of ['../src/repositories/dailyMoodRepository.js', '../src/repositories/sleepRepository.js']) {
    const source = await readFile(new URL(file, import.meta.url), 'utf8');
    assert.ok(
      !/\.getFullYear\(\)|\.getMonth\(\)|\.getDate\(\)/.test(source),
      `${file} reads a date with server-local getters; use dayIsoFromStored`,
    );
  }
});

test('calendar: the decoder does not compute its own date for dated reads', async () => {
  const source = await readFile(
    new URL('../src/services/partnerDecoderService.js', import.meta.url), 'utf8');
  const offenders = source.match(/(?:getDailyMood|getSleepByDate)\([^)]*,[^)]*\)/g) ?? [];
  assert.deepEqual(offenders, [],
    `pass no date argument -- let the repository use the shared calendar. Found: ${offenders.join(', ')}`);
});
