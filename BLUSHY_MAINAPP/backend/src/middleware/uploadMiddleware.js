import multer from 'multer';
import path from 'node:path';
import { fileTypeFromBuffer } from 'file-type';

import { storeUpload } from '../utils/objectStorage.js';
import { createHttpError } from '../utils/httpError.js';

/**
 * Uploads are held in memory, checked, then handed to storage.
 *
 * They used to be written straight to `uploads/` on the instance's own disk by
 * multer. That disk is ephemeral on the host this runs on and no persistent
 * disk is declared, so every file was deleted on the next deploy or
 * sleep-wake while the database row kept pointing at it.
 *
 * Buffering first is what makes the destination a choice rather than a
 * hard-coded path: `storeUpload` puts the bytes in a bucket when one is
 * configured and in the local directory when it is not. The 8 MB limit below
 * is what keeps "in memory" reasonable.
 *
 * After this middleware, `req.file` carries:
 *   `storedUrl`  where to serve it from — absolute for a bucket, `/uploads/...`
 *                for local
 *   `storageKey` the key to delete it by
 */

const imageMimeTypes = new Set([
  'image/png',
  'image/jpeg',
  'image/jpg',
  'image/webp',
  'image/bmp',
  'image/heic',
  'image/heif',
]);

const imageExtensions = new Set(['png', 'jpg', 'jpeg', 'webp', 'bmp', 'heic', 'heif']);
const attachmentExtensions = new Set([
  ...imageExtensions,
  'aac', 'flac', 'm4a', 'mp3', 'mp4', 'ogg', 'wav', 'webm',
]);

const MAX_UPLOAD_BYTES = 8 * 1024 * 1024;

function imageFilter(_req, file, cb) {
  if (!imageMimeTypes.has(file.mimetype)) {
    cb(createHttpError(415, 'Only image files are allowed. GIF and video formats are not supported.'));
    return;
  }
  cb(null, true);
}

function attachmentFilter(_req, file, cb) {
  const allowed = new Set([
    ...imageMimeTypes,
    'audio/aac', 'audio/flac', 'audio/m4a', 'audio/mpeg', 'audio/mp4',
    'audio/ogg', 'audio/wav', 'audio/webm', 'audio/x-m4a',
  ]);
  // 415 rather than a bare Error, which the handler renders as a 500. Sending
  // the wrong kind of file is the caller's mistake, and reporting it as a
  // server fault sends people looking for an outage that is not there.
  if (!allowed.has(file.mimetype)) {
    cb(createHttpError(415, 'Only supported image and audio files are allowed.'));
    return;
  }
  cb(null, true);
}

function generatedName(file, fallbackExt) {
  const extension = path.extname(file.originalname || '').toLowerCase();
  const safeExt = extension.length > 0 ? extension : fallbackExt;
  return `${Date.now()}-${Math.round(Math.random() * 1e9)}${safeExt}`;
}

/**
 * Checks the bytes against the declared type, then stores them.
 *
 * The signature check reads the buffer rather than a path: nothing has been
 * written anywhere yet, which also means a file that fails it never lands in
 * storage at all, rather than being written and then deleted.
 */
function withStorage(uploadMiddleware, allowedExtensions, folder, {
  fallbackExt = '.jpg',
  // Community and direct-message images were served from an absolute URL and
  // partner attachments from a relative one. A bucket makes every URL absolute
  // anyway; this keeps the local fallback shaped exactly as each caller's was,
  // so nothing downstream sees a different kind of address than before.
  absoluteWhenLocal = true,
} = {}) {
  return (req, res, next) => {
    uploadMiddleware(req, res, async (error) => {
      if (error || !req.file) {
        // A body multer cannot parse (a truncated or malformed multipart
        // form, a file over the limit) is the caller's mistake, not a
        // server fault; multer's own errors carry no status and fell
        // through as 500.
        next(error && !error.statusCode ? createHttpError(400, error.message || 'Invalid upload.') : error);
        return;
      }

      try {
        const detected = await fileTypeFromBuffer(req.file.buffer);
        if (!detected || !allowedExtensions.has(detected.ext)) {
          next(createHttpError(415, 'Uploaded file content does not match an allowed file type.'));
          return;
        }

        const filename = generatedName(req.file, fallbackExt);
        const stored = await storeUpload({
          folder,
          filename,
          buffer: req.file.buffer,
          contentType: req.file.mimetype,
        });

        req.file.filename = filename;
        req.file.storedUrl = stored.storage === 'local' && absoluteWhenLocal
            ? `${req.protocol}://${req.get('host')}${stored.url}`
            : stored.url;
        req.file.storageKey = stored.key;
        req.file.storageBackend = stored.storage;

        next();
      } catch (validationError) {
        next(validationError);
      }
    });
  };
}

const memory = multer.memoryStorage();

const uploadImage = multer({
  storage: memory,
  fileFilter: imageFilter,
  limits: { fileSize: MAX_UPLOAD_BYTES },
});

const uploadAttachment = multer({
  storage: memory,
  fileFilter: attachmentFilter,
  limits: { fileSize: MAX_UPLOAD_BYTES },
});

export const uploadCommunityImage =
  withStorage(uploadImage.single('image'), imageExtensions, 'community');

export const uploadPostImage =
  withStorage(uploadImage.single('image'), imageExtensions, 'posts');

export const uploadDirectMessageImage =
  withStorage(uploadImage.single('image'), imageExtensions, 'direct_messages');

export const uploadPartnerAttachment = withStorage(
  uploadAttachment.single('file'),
  attachmentExtensions,
  'partner_chat',
  { fallbackExt: '', absoluteWhenLocal: false },
);
