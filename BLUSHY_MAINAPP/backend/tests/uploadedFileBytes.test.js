import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { uploadedFileBytes } from '../src/utils/uploadedFileBytes.js';

/**
 * Uploads are buffered in memory so that storage can be a choice rather than a
 * hard-coded path. That removed `file.path` — and two readers still used it:
 * voice transcription and medical report parsing, both reached through the same
 * middleware. Both would have thrown on `readFileSync(undefined)`, so voice
 * notes and report uploads broke together.
 */
test('a memory-buffered upload is read from the buffer', () => {
  const bytes = Buffer.from([0x52, 0x49, 0x46, 0x46]);
  const file = { buffer: bytes, originalname: 'note.wav', mimetype: 'audio/wav' };

  assert.deepEqual(uploadedFileBytes(file), bytes);
});

test('a disk-backed upload still works', () => {
  // So a middleware that goes back to disk storage does not break these again.
  const tmp = path.join(os.tmpdir(), `ufb-${Date.now()}.bin`);
  fs.writeFileSync(tmp, Buffer.from('on disk'));

  try {
    assert.equal(uploadedFileBytes({ path: tmp }).toString(), 'on disk');
  } finally {
    fs.unlinkSync(tmp);
  }
});

test('the buffer wins when both are present', () => {
  const tmp = path.join(os.tmpdir(), `ufb-both-${Date.now()}.bin`);
  fs.writeFileSync(tmp, Buffer.from('stale'));

  try {
    const file = { buffer: Buffer.from('fresh'), path: tmp };
    assert.equal(uploadedFileBytes(file).toString(), 'fresh');
  } finally {
    fs.unlinkSync(tmp);
  }
});

test('nothing to read returns null rather than throwing', () => {
  // The callers check for null and answer 400; throwing here would surface as
  // a 500 telling the user their audio was unclear, which it was not.
  assert.equal(uploadedFileBytes(null), null);
  assert.equal(uploadedFileBytes({}), null);
  assert.equal(uploadedFileBytes({ path: '' }), null);
});

test('no reader is left on file.path', () => {
  // The regression, guarded: these two are fed by memory storage.
  for (const file of ['../src/controllers/aiController.js',
                      '../src/services/medicalReportService.js']) {
    const source = fs.readFileSync(new URL(file, import.meta.url), 'utf8');
    assert.ok(!source.includes('readFileSync(file.path'),
      `${file} still reads a path that memory storage does not set`);
  }
});
