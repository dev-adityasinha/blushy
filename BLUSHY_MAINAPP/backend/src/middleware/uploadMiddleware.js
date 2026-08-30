import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import multer from 'multer';
import { fileTypeFromFile } from 'file-type';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const uploadDir = path.resolve(__dirname, '../../uploads/community');

if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const imageMimeTypes = new Set([
  'image/png',
  'image/jpeg',
  'image/jpg',
  'image/webp',
  'image/bmp',
  'image/heic',
  'image/heif',
]);

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, uploadDir);
  },
  filename: (_req, file, cb) => {
    const extension = path.extname(file.originalname || '').toLowerCase();
    const safeExt = extension.length > 0 ? extension : '.jpg';
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${safeExt}`);
  },
});

function fileFilter(_req, file, cb) {
  if (!imageMimeTypes.has(file.mimetype)) {
    cb(new Error('Only image files are allowed. GIF and video formats are not supported.'));
    return;
  }

  cb(null, true);
}

function withSignatureValidation(uploadMiddleware, allowedExtensions) {
  return (req, res, next) => {
    uploadMiddleware(req, res, async (error) => {
      if (error || !req.file) {
        next(error);
        return;
      }

      try {
        const detected = await fileTypeFromFile(req.file.path);
        if (!detected || !allowedExtensions.has(detected.ext)) {
          await fs.promises.unlink(req.file.path).catch(() => {});
          next(new Error('Uploaded file content does not match an allowed file type.'));
          return;
        }

        next();
      } catch (validationError) {
        await fs.promises.unlink(req.file.path).catch(() => {});
        next(validationError);
      }
    });
  };
}

const imageExtensions = new Set(['png', 'jpg', 'jpeg', 'webp', 'bmp', 'heic', 'heif']);
const attachmentExtensions = new Set([
  ...imageExtensions,
  'aac',
  'flac',
  'm4a',
  'mp3',
  'mp4',
  'ogg',
  'wav',
  'webm',
]);

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 8 * 1024 * 1024,
  },
});

export const uploadCommunityImage = withSignatureValidation(upload.single('image'), imageExtensions);

const uploadPostsDir = path.resolve(__dirname, '../../uploads/posts');
if (!fs.existsSync(uploadPostsDir)) {
  fs.mkdirSync(uploadPostsDir, { recursive: true });
}

const storagePosts = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, uploadPostsDir);
  },
  filename: (_req, file, cb) => {
    const extension = path.extname(file.originalname || '').toLowerCase();
    const safeExt = extension.length > 0 ? extension : '.jpg';
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${safeExt}`);
  },
});

const uploadPosts = multer({
  storage: storagePosts,
  fileFilter,
  limits: {
    fileSize: 8 * 1024 * 1024,
  },
});

export const uploadPostImage = withSignatureValidation(uploadPosts.single('image'), imageExtensions);

const uploadDmsDir = path.resolve(__dirname, '../../uploads/direct_messages');
if (!fs.existsSync(uploadDmsDir)) {
  fs.mkdirSync(uploadDmsDir, { recursive: true });
}

const storageDms = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, uploadDmsDir);
  },
  filename: (_req, file, cb) => {
    const extension = path.extname(file.originalname || '').toLowerCase();
    const safeExt = extension.length > 0 ? extension : '.jpg';
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${safeExt}`);
  },
});

const uploadDms = multer({
  storage: storageDms,
  fileFilter,
  limits: {
    fileSize: 8 * 1024 * 1024,
  },
});

export const uploadDirectMessageImage = withSignatureValidation(uploadDms.single('image'), imageExtensions);

const uploadPartnerChatDir = path.resolve(__dirname, '../../uploads/partner_chat');
if (!fs.existsSync(uploadPartnerChatDir)) {
  fs.mkdirSync(uploadPartnerChatDir, { recursive: true });
}

const storagePartnerChat = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, uploadPartnerChatDir);
  },
  filename: (_req, file, cb) => {
    const extension = path.extname(file.originalname || '').toLowerCase();
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${extension}`);
  },
});

const uploadPartnerChat = multer({
  storage: storagePartnerChat,
  fileFilter: (_req, file, cb) => {
    const allowedMimeTypes = new Set([
      ...imageMimeTypes,
      'audio/aac',
      'audio/flac',
      'audio/m4a',
      'audio/mpeg',
      'audio/mp4',
      'audio/ogg',
      'audio/wav',
      'audio/webm',
      'audio/x-m4a',
    ]);
    if (!allowedMimeTypes.has(file.mimetype)) {
      cb(new Error('Only supported image and audio files are allowed.'));
      return;
    }
    cb(null, true);
  },
  limits: {
    fileSize: 8 * 1024 * 1024,
  },
});

export const uploadPartnerAttachment = withSignatureValidation(uploadPartnerChat.single('file'), attachmentExtensions);
