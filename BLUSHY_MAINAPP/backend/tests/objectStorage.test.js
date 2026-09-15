import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  storeUpload,
  publicUrlFor,
  deleteUpload,
  objectStorageEnabled,
} from '../src/utils/objectStorage.js';

/**
 * Uploads were written to the instance's own disk. That filesystem is
 * ephemeral on the deployment host and no persistent disk is declared, so
 * every community image, post attachment and partner voice note was deleted on
 * the next deploy or sleep-wake, while the database row kept pointing at it.
 *
 * These cover the local fallback and the URL shapes. The bucket path itself
 * cannot be exercised without credentials and a real bucket.
 */
const uploadsRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)), '../uploads',
);

test('with no bucket configured, nothing changes for development', async (t) => {
  assert.equal(objectStorageEnabled(), false,
    'the suite runs without S3 settings, so this is the fallback path');

  const filename = `test-${Date.now()}.png`;
  t.after(async () => { await deleteUpload(`community/${filename}`); });

  const stored = await storeUpload({
    folder: 'community',
    filename,
    buffer: Buffer.from([0x89, 0x50, 0x4e, 0x47]),
    contentType: 'image/png',
  });

  assert.equal(stored.storage, 'local');
  assert.equal(stored.url, `/uploads/community/${filename}`);
  assert.equal(stored.key, `community/${filename}`);
  assert.ok(fs.existsSync(path.join(uploadsRoot, 'community', filename)),
    'the bytes must actually be on disk');
});

test('the folder becomes the key prefix, so both layouts match', async (t) => {
  const filename = `test-${Date.now()}.m4a`;
  t.after(async () => { await deleteUpload(`partner_chat/${filename}`); });

  const stored = await storeUpload({
    folder: 'partner_chat',
    filename,
    buffer: Buffer.from('audio'),
    contentType: 'audio/mp4',
  });

  assert.equal(stored.key, `partner_chat/${filename}`);
  assert.ok(fs.existsSync(path.join(uploadsRoot, 'partner_chat', filename)));
});

test('deleting removes the file and is safe to repeat', async () => {
  const filename = `test-del-${Date.now()}.png`;
  await storeUpload({
    folder: 'posts', filename,
    buffer: Buffer.from([1, 2, 3]), contentType: 'image/png',
  });

  assert.equal(await deleteUpload(`posts/${filename}`), true);
  assert.equal(fs.existsSync(path.join(uploadsRoot, 'posts', filename)), false);

  // A file that is already gone is not an error worth raising.
  assert.equal(await deleteUpload(`posts/${filename}`), false);
  assert.equal(await deleteUpload(null), false);
});

test('the served URL follows the configured location', () => {
  // Unconfigured: the local path, which is what the app has always served.
  assert.equal(publicUrlFor('community/a.png'), '/uploads/community/a.png');
});

test('the middleware no longer writes to disk before checking the file', () => {
  const source = fs.readFileSync(
    path.resolve(path.dirname(fileURLToPath(import.meta.url)),
      '../src/middleware/uploadMiddleware.js'), 'utf8');

  // diskStorage put the file down before anything had looked at it, so a
  // rejected upload had to be written and then unlinked.
  assert.ok(!source.includes('multer.diskStorage'),
    'uploads must be buffered, or the destination cannot be a choice');
  assert.ok(source.includes('multer.memoryStorage()'));
  assert.ok(source.includes('fileTypeFromBuffer'),
    'the signature check reads the buffer, not a path on disk');
  assert.ok(source.includes('storeUpload('),
    'and storage decides where the bytes land');
});
