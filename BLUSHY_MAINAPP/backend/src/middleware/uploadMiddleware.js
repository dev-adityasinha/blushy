import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import multer from 'multer';

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

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 8 * 1024 * 1024,
  },
});

export const uploadCommunityImage = upload.single('image');

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

export const uploadPostImage = uploadPosts.single('image');

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

export const uploadDirectMessageImage = uploadDms.single('image');

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
  limits: {
    fileSize: 20 * 1024 * 1024, // 20 MB limit
  },
});

export const uploadPartnerAttachment = uploadPartnerChat.single('file');
