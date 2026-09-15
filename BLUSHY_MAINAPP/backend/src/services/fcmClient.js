import { createSign } from 'node:crypto';

/**
 * Firebase Cloud Messaging HTTP v1 client (spec §19, §24).
 *
 * FCM delivers to Android, iOS (via an APNs key uploaded to Firebase) and web,
 * so this is the only transport the app needs. There is no SDK here on purpose:
 * the whole protocol is a signed JWT exchanged for an access token, then one
 * POST per device token, and Node can do both natively.
 *
 * Nothing in this file decides *whether* to send or *what text* to send. The
 * category preferences, quiet hours and lock-screen redaction all happen in
 * `domain/notifications.js` before anything reaches here.
 */

const TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

/** Swappable so tests can exercise the real code paths without a network. */
let _fetch = (...args) => globalThis.fetch(...args);

export function __setFetchForTests(fn) {
  _fetch = fn ?? ((...args) => globalThis.fetch(...args));
}

let _tokenCache = null;

export function __resetTokenCacheForTests() {
  _tokenCache = null;
}

function base64url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/**
 * Reads the service account from `FCM_SERVICE_ACCOUNT_JSON`, which holds either
 * the JSON itself or a base64 copy of it (some hosts cannot store raw newlines
 * in an env var).
 */
export function parseServiceAccount(raw) {
  if (typeof raw !== 'string' || raw.trim().length === 0) return null;

  let text = raw.trim();
  if (!text.startsWith('{')) {
    try {
      text = Buffer.from(text, 'base64').toString('utf8');
    } catch {
      return null;
    }
  }

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    return null;
  }

  const projectId = parsed.project_id ?? parsed.projectId;
  const clientEmail = parsed.client_email ?? parsed.clientEmail;
  const privateKey = (parsed.private_key ?? parsed.privateKey ?? '').replace(/\\n/g, '\n');

  if (!projectId || !clientEmail || !privateKey) return null;
  return { projectId, clientEmail, privateKey };
}

/**
 * Exchanges a self-signed JWT for an access token, and reuses it until it is
 * close to expiring. Minting one per notification would add a round trip to
 * Google in front of every send.
 */
export async function getAccessToken(serviceAccount, { now = Date.now() } = {}) {
  if (_tokenCache && _tokenCache.email === serviceAccount.clientEmail && _tokenCache.expiresAt > now + 60_000) {
    return _tokenCache.token;
  }

  const issuedAt = Math.floor(now / 1000);
  const expiresAt = issuedAt + 3600;

  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64url(JSON.stringify({
    iss: serviceAccount.clientEmail,
    scope: SCOPE,
    aud: TOKEN_ENDPOINT,
    iat: issuedAt,
    exp: expiresAt,
  }));

  const signer = createSign('RSA-SHA256');
  signer.update(`${header}.${claims}`);
  const signature = base64url(signer.sign(serviceAccount.privateKey));
  const assertion = `${header}.${claims}.${signature}`;

  const response = await _fetch(TOKEN_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }).toString(),
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    throw new Error(`FCM auth failed (${response.status}): ${detail.slice(0, 200)}`);
  }

  const body = await response.json();
  if (!body.access_token) throw new Error('FCM auth returned no access token.');

  _tokenCache = {
    email: serviceAccount.clientEmail,
    token: body.access_token,
    expiresAt: now + (Number(body.expires_in) || 3600) * 1000,
  };
  return _tokenCache.token;
}

/**
 * FCM error codes that mean the token will never work again, as opposed to a
 * transient failure. These are the ones worth deleting the device row for;
 * retrying them forever would send to a phone that has uninstalled the app.
 */
const DEAD_TOKEN_CODES = new Set([
  'UNREGISTERED',
  'INVALID_ARGUMENT',
  'SENDER_ID_MISMATCH',
]);

function errorCodeFrom(body, status) {
  const details = body?.error?.details;
  if (Array.isArray(details)) {
    for (const detail of details) {
      if (detail?.errorCode) return detail.errorCode;
    }
  }
  if (body?.error?.status) return body.error.status;
  return `HTTP_${status}`;
}

/**
 * Sends one already-redacted payload to one device token.
 *
 * `data` values are all strings: FCM v1 rejects any other type, and a rejected
 * message is indistinguishable from a delivery failure in the log.
 */
export async function sendMessage({ serviceAccount, accessToken, deviceToken, payload }) {
  const message = {
    token: deviceToken,
    notification: {
      title: payload.title,
      body: payload.body ?? '',
    },
    data: Object.fromEntries(
      Object.entries(payload.data ?? {})
        .filter(([, value]) => value !== null && value !== undefined)
        .map(([key, value]) => [key, String(value)]),
    ),
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  };

  const response = await _fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message }),
    },
  );

  if (response.ok) {
    return { ok: true, tokenIsDead: false, errorCode: null };
  }

  const body = await response.json().catch(() => null);
  const errorCode = errorCodeFrom(body, response.status);

  return {
    ok: false,
    tokenIsDead: DEAD_TOKEN_CODES.has(errorCode),
    errorCode,
  };
}
