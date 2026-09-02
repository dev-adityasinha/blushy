import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

/**
 * What the transcription request declares its audio to be.
 *
 * The provider checks the multipart part's content type against the registered
 * list before reading a byte. Android records AAC-LC in an MP4 container and
 * the record plugin labels it `audio/m4a`, which is not a registered type;
 * that was forwarded verbatim and rejected, surfacing in the app as a bare 502.
 */
const source = readFileSync(
  new URL('../src/controllers/aiController.js', import.meta.url), 'utf8');

test('the incoming mimetype is not forwarded verbatim', () => {
  assert.equal(
    source.includes("type: file.mimetype || 'application/octet-stream'"),
    false,
    'audio/m4a would be sent straight through again',
  );
});

test('m4a and aac are declared as the container they actually are', () => {
  assert.match(source, /m4a: 'audio\/mp4'/);
  assert.match(source, /aac: 'audio\/mp4'/);
});

test('every format the controller accepts has a canonical type', () => {
  const supported = ['wav', 'mp3', 'webm', 'ogg', 'm4a', 'aac', 'flac'];
  const start = source.indexOf('const CANONICAL_AUDIO_TYPES');
  const table = source.slice(start, source.indexOf('};', start));
  for (const format of supported) {
    assert.ok(table.includes(`${format}:`), `${format} has no canonical type`);
  }
});

test('the failure log names the type that was sent', () => {
  // Without this the log said only the status, which is what made this take
  // three guesses to find.
  assert.match(source, /provider status \$\{response\.status\}/);
  assert.match(source, /\$\{contentType\}/);
});
