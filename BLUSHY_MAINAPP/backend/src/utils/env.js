import dotenv from 'dotenv';

dotenv.config();

function required(name, fallback = '') {
  const value = process.env[name] ?? fallback;
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const env = {
  port: Number(process.env.PORT ?? 3000),
  nodeEnv: process.env.NODE_ENV ?? 'development',
  jwtSecret: required('JWT_SECRET', 'change-me-in-production'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  corsOrigin: process.env.CORS_ORIGIN ?? '*',
  hstsPreloadEnabled: String(process.env.HSTS_PRELOAD_ENABLED ?? 'false').toLowerCase() === 'true',
  captchaEnabled: String(process.env.CAPTCHA_ENABLED ?? 'false').toLowerCase() === 'true',
  captchaProvider: process.env.CAPTCHA_PROVIDER ?? 'placeholder',
  storeEncryptedPhone: String(process.env.STORE_ENCRYPTED_PHONE ?? 'false').toLowerCase() === 'true',
  encryptionKey: process.env.ENCRYPTION_KEY ?? '',

  smtpHost: process.env.SMTP_HOST ?? '',
  smtpPort: Number(process.env.SMTP_PORT ?? 587),
  smtpUser: process.env.SMTP_USER ?? '',
  smtpPassword: process.env.SMTP_PASSWORD ?? '',
  emailFrom: process.env.EMAIL_FROM ?? '',
  smtpConnectionTimeout: Number(process.env.SMTP_CONNECTION_TIMEOUT ?? 20000),
  smtpGreetingTimeout: Number(process.env.SMTP_GREETING_TIMEOUT ?? 20000),
  smtpSocketTimeout: Number(process.env.SMTP_SOCKET_TIMEOUT ?? 20000),
  smtpAttemptTimeout: Number(process.env.SMTP_ATTEMPT_TIMEOUT ?? 20000),
  emailDeliveryFallbackEnabled: String(process.env.EMAIL_DELIVERY_FALLBACK_ENABLED ?? 'true').toLowerCase() === 'true',
  reacherApiUrl: process.env.REACHER_API_URL ?? 'https://api.reacher.email',
  reacherApiKey: process.env.REACHER_API_KEY ?? '',
  appPublicUrl: process.env.APP_PUBLIC_URL ?? '',
  mobileAppDeepLinkBase: process.env.MOBILE_APP_DEEP_LINK_BASE ?? 'blushy://auth/email-verified',
  grokApiKey: process.env.GROK_API_KEY ?? '',
  grokModel: process.env.GROK_MODEL ?? 'x-ai/grok-4.3',
  grokApiUrl: process.env.GROK_API_URL ?? 'https://openrouter.ai/api/v1/chat/completions',
  grokVoiceWsUrl: process.env.GROK_VOICE_WS_URL ?? 'wss://api.x.ai/v1/realtime',
  grokVoiceModel: process.env.GROK_VOICE_MODEL ?? 'grok-voice-think-fast-1.0',
  communityCleanupEnabled: String(process.env.COMMUNITY_CLEANUP_ENABLED ?? 'true').toLowerCase() === 'true',
  communityCleanupHourUtc: Number(process.env.COMMUNITY_CLEANUP_HOUR_UTC ?? 0),
  dailyChatSummaryEnabled: String(process.env.DAILY_CHAT_SUMMARY_ENABLED ?? 'true').toLowerCase() === 'true',
  mongodbUri: process.env.MONGODB_URI ?? 'mongodb://127.0.0.1:27017/blushy',
  redisUrl: process.env.REDIS_URL ?? '',
  refreshTokenExpiresIn: process.env.REFRESH_TOKEN_EXPIRES_IN ?? '7d',
  googleClientIdWeb: process.env.GOOGLE_CLIENT_ID_WEB ?? '',
  googleClientIdAndroid: process.env.GOOGLE_CLIENT_ID_ANDROID ?? '',
  googleClientIdIos: process.env.GOOGLE_CLIENT_ID_IOS ?? '',
};
