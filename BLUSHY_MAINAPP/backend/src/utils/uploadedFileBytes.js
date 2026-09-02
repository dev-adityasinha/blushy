import fs from 'node:fs';

/**
 * The bytes of an uploaded file, wherever multer put them.
 *
 * Uploads are buffered in memory now, so that storage can be a choice rather
 * than a hard-coded path -- see `objectStorage.js`. That change removed
 * `file.path`, which two readers still used: voice transcription and medical
 * report parsing. Both are reached through the same middleware, and both would
 * have thrown on `readFileSync(undefined)`.
 *
 * Handles either, so a middleware that goes back to disk storage keeps working.
 */
export function uploadedFileBytes(file) {
  if (!file) return null;
  if (Buffer.isBuffer(file.buffer)) return file.buffer;
  if (typeof file.path === 'string' && file.path.length > 0) {
    return fs.readFileSync(file.path);
  }
  return null;
}
