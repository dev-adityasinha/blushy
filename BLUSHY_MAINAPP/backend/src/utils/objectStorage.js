import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { env } from './env.js';
import { logger } from './logger.js';

/**
 * Where uploaded files live.
 *
 * They were written to `uploads/` on the instance's own disk. Render's
 * filesystem is ephemeral and no persistent disk is declared, so every
 * community image, post attachment and partner voice note was deleted on the
 * next deploy or sleep-wake — which on the free plan is constantly. The row in
 * the database kept pointing at a file that no longer existed.
 *
 * When an S3-compatible bucket is configured, uploads go there and the stored
 * URL is absolute. When it is not, the local directory is used exactly as
 * before, so development needs no credentials and nothing changes for it.
 *
 * S3-compatible rather than S3: the same settings work for Cloudflare R2,
 * Backblaze B2, DigitalOcean Spaces, MinIO and AWS itself, which is worth more
 * than tying the app to one vendor.
 */

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const LOCAL_ROOT = path.resolve(__dirname, '../../uploads');

let client = null;

/** Whether uploads are stored in a bucket rather than on this instance. */
export function objectStorageEnabled() {
  return Boolean(env.s3Bucket && env.s3AccessKeyId && env.s3SecretAccessKey);
}

async function getClient() {
  if (client) return client;

  const { S3Client } = await import('@aws-sdk/client-s3');
  client = new S3Client({
    region: env.s3Region,
    // Set for every provider except AWS, whose endpoint is derived from region.
    ...(env.s3Endpoint ? { endpoint: env.s3Endpoint, forcePathStyle: true } : {}),
    credentials: {
      accessKeyId: env.s3AccessKeyId,
      secretAccessKey: env.s3SecretAccessKey,
    },
  });
  return client;
}

/**
 * Stores one file and returns the URL to serve it from.
 *
 * `folder` is the sub-path used both as the bucket key prefix and, when
 * falling back, as the local directory — so the two layouts stay identical and
 * a bucket can be seeded from a local `uploads/` tree if one ever needs to be.
 *
 * Never throws: an upload that cannot reach the bucket falls back to the local
 * disk and says so. Losing the file later is bad; refusing the message she is
 * sending right now is worse.
 */
export async function storeUpload({ folder, filename, buffer, contentType }) {
  const key = `${folder}/${filename}`;

  if (objectStorageEnabled()) {
    try {
      const { PutObjectCommand } = await import('@aws-sdk/client-s3');
      const s3 = await getClient();
      await s3.send(new PutObjectCommand({
        Bucket: env.s3Bucket,
        Key: key,
        Body: buffer,
        ContentType: contentType || 'application/octet-stream',
        // Uploads are read by the app over plain HTTP, so the object has to be
        // readable. Buckets that block public ACLs should set S3_PUBLIC_BASE_URL
        // to a CDN or a bucket policy instead.
        CacheControl: 'public, max-age=31536000, immutable',
      }));

      return { url: publicUrlFor(key), key, storage: 's3' };
    } catch (error) {
      logger.error(`Object storage upload failed for ${key}; using local disk`, error);
    }
  }

  const dir = path.join(LOCAL_ROOT, folder);
  await fs.promises.mkdir(dir, { recursive: true });
  await fs.promises.writeFile(path.join(dir, filename), buffer);

  return { url: `/uploads/${key}`, key, storage: 'local' };
}

/** The address a stored key is served from. */
export function publicUrlFor(key) {
  if (!objectStorageEnabled()) return `/uploads/${key}`;

  const base = env.s3PublicBaseUrl
    || (env.s3Endpoint
      ? `${env.s3Endpoint.replace(/\/+$/, '')}/${env.s3Bucket}`
      : `https://${env.s3Bucket}.s3.${env.s3Region}.amazonaws.com`);

  return `${base.replace(/\/+$/, '')}/${key}`;
}

/** Removes a stored file. Best effort: a leftover object is not worth an error. */
export async function deleteUpload(key) {
  if (!key) return false;

  if (objectStorageEnabled()) {
    try {
      const { DeleteObjectCommand } = await import('@aws-sdk/client-s3');
      const s3 = await getClient();
      await s3.send(new DeleteObjectCommand({ Bucket: env.s3Bucket, Key: key }));
      return true;
    } catch (error) {
      logger.warn(`Could not delete ${key} from object storage: ${error.message}`);
      return false;
    }
  }

  try {
    await fs.promises.unlink(path.join(LOCAL_ROOT, key));
    return true;
  } catch {
    return false;
  }
}
