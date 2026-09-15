const SENSITIVE_KEYS = new Set([
  'password',
  'newpassword',
  'confirmpassword',
  'passwordhash',
  'otp',
  'code',
  'codehash',
  'token',
  'secret',
  'verificationtoken',
  'verificationtokenhash',
]);

function sanitize(data) {
  if (!data) return data;
  if (typeof data === 'string') {
    return data;
  }
  if (typeof data !== 'object') return data;
  if (Array.isArray(data)) return data.map(sanitize);

  const clean = {};
  for (const [key, value] of Object.entries(data)) {
    if (SENSITIVE_KEYS.has(key.toLowerCase())) {
      clean[key] = '[REDACTED]';
    } else if (typeof value === 'object' && value !== null) {
      clean[key] = sanitize(value);
    } else {
      clean[key] = value;
    }
  }
  return clean;
}

function format(level, message, meta) {
  const metaStr = meta !== undefined ? ` ${JSON.stringify(sanitize(meta))}` : '';
  return `[${new Date().toISOString()}] [${level}] ${typeof message === 'object' ? JSON.stringify(sanitize(message)) : message}${metaStr}`;
}

export const logger = {
  info(message, meta) {
    console.log(format('INFO', message, meta));
  },
  warn(message, meta) {
    console.warn(format('WARN', message, meta));
  },
  error(message, meta) {
    console.error(format('ERROR', message, meta));
  },
};