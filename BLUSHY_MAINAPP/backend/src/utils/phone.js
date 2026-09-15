import crypto from 'node:crypto';

import { parsePhoneNumberFromString } from 'libphonenumber-js';
import { env } from './env.js';

export function normalizePhoneNumber(phone) {
  if (!phone) {
    return null;
  }

  const parsed = parsePhoneNumberFromString(String(phone).trim());
  if (!parsed || !parsed.isValid()) {
    return null;
  }

  return parsed.number;
}

export function hashPhoneNumber(phone) {
  return crypto.createHash('sha256').update(phone).digest('hex');
}

export function maskPhoneNumber(phone) {
  const normalized = String(phone).trim();
  if (normalized.length <= 4) {
    return '****';
  }

  return `${normalized.slice(0, 2)}****${normalized.slice(-2)}`;
}

function getEncryptionKey() {
  if (!env.encryptionKey) {
    return null;
  }

  return crypto.createHash('sha256').update(env.encryptionKey).digest();
}

export function encryptPhoneNumber(phone) {
  const key = getEncryptionKey();
  if (!key) {
    return null;
  }

  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(phone, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();

  return Buffer.concat([iv, authTag, encrypted]).toString('base64');
}

export function decryptPhoneNumber(payload) {
  const key = getEncryptionKey();
  if (!key || !payload) {
    return null;
  }

  const buffer = Buffer.from(payload, 'base64');
  const iv = buffer.subarray(0, 12);
  const authTag = buffer.subarray(12, 28);
  const encrypted = buffer.subarray(28);
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(authTag);
  return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
}