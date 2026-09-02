import dotenv from 'dotenv';

dotenv.config();

function required(name, fallback = '') {
  const value = process.env[name] ?? fallback;
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

const nodeEnv = process.env.NODE_ENV ?? 'development';
const configuredJwtSecret = process.env.JWT_SECRET ?? '';
if (nodeEnv === 'production' &&
    (configuredJwtSecret.length < 32 || configuredJwtSecret === 'change-me-in-production')) {
  throw new Error('FATAL SECURITY ERROR: JWT_SECRET must be a random value of at least 32 characters in production.');
}

export const env = {
  port: Number(process.env.PORT ?? 3000),
  nodeEnv,
  jwtSecret: required('JWT_SECRET', 'change-me-in-production'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  corsOrigin: process.env.CORS_ORIGIN ?? '*',
  hstsPreloadEnabled: String(process.env.HSTS_PRELOAD_ENABLED ?? 'false').toLowerCase() === 'true',
  captchaEnabled: String(process.env.CAPTCHA_ENABLED ?? 'false').toLowerCase() === 'true',
  captchaProvider: process.env.CAPTCHA_PROVIDER ?? 'placeholder',
  storeEncryptedPhone: String(process.env.STORE_ENCRYPTED_PHONE ?? 'false').toLowerCase() === 'true',
  encryptionKey: process.env.ENCRYPTION_KEY ?? '',

  // Brevo's HTTP API is tried before SMTP. Hosted platforms routinely block
  // outbound SMTP ports, and a blocked port looks exactly like a bad password
  // from the client side, so an ordinary HTTPS call is the more reliable path.
  // SMTP stays as the fallback so an existing deployment keeps working.
  brevoApiKey: process.env.BREVO_API_KEY ?? '',
  brevoApiUrl: process.env.BREVO_API_URL ?? 'https://api.brevo.com/v3/smtp/email',
  emailFromName: process.env.EMAIL_FROM_NAME ?? 'Blushy',
  // Comma-separated resolvers used for the MongoDB SRV lookup. Empty means
  // the system resolver, which is correct nearly everywhere.
  dnsServers: (process.env.DNS_SERVERS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
  // Grok reasons by default and spends most of its output budget on thinking
  // the user never sees. Measured on the real prompts it cost 3-4x the latency
  // and produced vaguer clinical answers, so it is off unless asked for.
  aiReasoningEnabled:
    String(process.env.AI_REASONING_ENABLED ?? 'false').toLowerCase() === 'true',
  // No call had a timeout before; a stalled provider held the request open.
  aiRequestTimeoutMs: Number(process.env.AI_REQUEST_TIMEOUT_MS ?? 30000),
  smtpHost: process.env.SMTP_HOST ?? '',
  smtpPort: Number(process.env.SMTP_PORT ?? 587),
  smtpUser: process.env.SMTP_USER ?? '',
  smtpPassword: process.env.SMTP_PASSWORD ?? '',
  emailFrom: process.env.EMAIL_FROM ?? '',
  smtpConnectionTimeout: Number(process.env.SMTP_CONNECTION_TIMEOUT ?? 20000),
  smtpGreetingTimeout: Number(process.env.SMTP_GREETING_TIMEOUT ?? 20000),
  smtpSocketTimeout: Number(process.env.SMTP_SOCKET_TIMEOUT ?? 20000),
  smtpAttemptTimeout: Number(process.env.SMTP_ATTEMPT_TIMEOUT ?? 20000),
  // Returns the verification code in the API response when email delivery
  // fails. That is a useful development convenience and an account takeover in
  // production: anyone can register an address they do not control, because
  // the server hands them the code. Defaults off in production, so a broken
  // mail server fails closed rather than giving codes away.
  emailDeliveryFallbackEnabled:
    String(
      process.env.EMAIL_DELIVERY_FALLBACK_ENABLED
        ?? (process.env.NODE_ENV === 'production' ? 'false' : 'true'),
    ).toLowerCase() === 'true',
  reacherApiUrl: process.env.REACHER_API_URL ?? 'https://api.reacher.email',
  reacherApiKey: process.env.REACHER_API_KEY ?? '',
  appPublicUrl: process.env.APP_PUBLIC_URL ?? '',
  mobileAppDeepLinkBase: process.env.MOBILE_APP_DEEP_LINK_BASE ?? 'blushy://auth/email-verified',
  // Chat and speech-to-text are separate providers on purpose.
  //
  // Chat runs Grok through OpenRouter (openrouter.ai, keys `sk-or-...`), which
  // is what the `x-ai/grok-*` model slug is addressed to. Transcription cannot
  // go there: OpenRouter serves no speech-to-text endpoint, so it points at a
  // Whisper host -- Groq (api.groq.com, keys `gsk_...`) by default.
  //
  // Three similarly named things are in play: xAI's Grok (the model),
  // Groq (a different company, Whisper hosting) and OpenRouter (the gateway
  // serving Grok here). Naming these by what they DO rather than who provides
  // them is what keeps them from being swapped again.
  //
  // GROK_*/GROQ_* are still read as fallbacks so an older .env keeps working.
  // Object storage for uploads. Unset means the local `uploads/` directory,
  // which is what development uses and what production used until now -- and
  // on an ephemeral filesystem that meant every uploaded file was lost on the
  // next restart. S3-compatible, so the same four settings work for AWS,
  // Cloudflare R2, Backblaze B2, DigitalOcean Spaces and MinIO.
  // Connection pool bounds. See the comments in `utils/db.js` for why the
  // driver's defaults are wrong here; these are sized for a cluster that
  // allows 500 connections in total.
  mongoMaxPoolSize: Number(process.env.MONGO_MAX_POOL_SIZE ?? 20),
  mongoWaitQueueTimeoutMs: Number(process.env.MONGO_WAIT_QUEUE_TIMEOUT_MS ?? 10000),
  mongoMaxIdleTimeMs: Number(process.env.MONGO_MAX_IDLE_TIME_MS ?? 60000),

  s3Bucket: process.env.S3_BUCKET ?? '',
  s3Region: process.env.S3_REGION ?? 'auto',
  s3AccessKeyId: process.env.S3_ACCESS_KEY_ID ?? '',
  s3SecretAccessKey: process.env.S3_SECRET_ACCESS_KEY ?? '',
  // Required for everything except AWS itself.
  s3Endpoint: process.env.S3_ENDPOINT ?? '',
  // A CDN or custom domain in front of the bucket, when there is one.
  s3PublicBaseUrl: process.env.S3_PUBLIC_BASE_URL ?? '',

  aiChatApiKey: process.env.AI_CHAT_API_KEY ?? process.env.OPENROUTER_API_KEY ?? process.env.GROK_API_KEY ?? '',
  aiChatModel: process.env.AI_CHAT_MODEL ?? process.env.GROQ_MODEL ?? process.env.GROK_MODEL ?? 'x-ai/grok-4.3',
  aiChatApiUrl: process.env.AI_CHAT_API_URL ?? process.env.GROK_API_URL ?? process.env.GROQ_API_URL ?? 'https://openrouter.ai/api/v1/chat/completions',

  speechToTextApiKey: process.env.SPEECH_TO_TEXT_API_KEY ?? process.env.GROQ_API_KEY ?? '',
  speechToTextModel: process.env.SPEECH_TO_TEXT_MODEL ?? 'whisper-large-v3-turbo',
  speechToTextUrl: process.env.SPEECH_TO_TEXT_URL ?? process.env.GROQ_SPEECH_TO_TEXT_URL ?? 'https://api.groq.com/openai/v1/audio/transcriptions',
  communityCleanupEnabled: String(process.env.COMMUNITY_CLEANUP_ENABLED ?? 'true').toLowerCase() === 'true',
  communityCleanupHourUtc: Number(process.env.COMMUNITY_CLEANUP_HOUR_UTC ?? 0),
  dailyChatSummaryEnabled: String(process.env.DAILY_CHAT_SUMMARY_ENABLED ?? 'true').toLowerCase() === 'true',
  mongodbUri: process.env.MONGODB_URI ?? 'mongodb://127.0.0.1:27017/blushy',
  redisUrl: process.env.REDIS_URL ?? '',
  refreshTokenExpiresIn: process.env.REFRESH_TOKEN_EXPIRES_IN ?? '7d',
  googleClientIdWeb: process.env.GOOGLE_CLIENT_ID_WEB ?? '',
  googleClientIdAndroid: process.env.GOOGLE_CLIENT_ID_ANDROID ?? '',
  googleClientIdIos: process.env.GOOGLE_CLIENT_ID_IOS ?? '',

  // Push transport. The dispatch worker stays off until this is set, so an
  // unconfigured deployment does not spin over the queue doing nothing.
  fcmServiceAccountJson: process.env.FCM_SERVICE_ACCOUNT_JSON ?? '',
  get pushProviderConfigured() {
    return this.fcmServiceAccountJson.trim().length > 0;
  },
};
