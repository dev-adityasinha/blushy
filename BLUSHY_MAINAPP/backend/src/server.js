import { createServer } from 'node:http';

import app from './app.js';
import { env } from './utils/env.js';
import { initDatabase } from './utils/initDatabase.js';
import { logger } from './utils/logger.js';
import { assertCaptchaNotFalselyEnabled } from './services/captchaService.js';
import { startCapsuleDeliveryScheduler } from './services/timeCapsuleService.js';
import { connectRealtimeBus, disconnectRealtimeBus, initRealtimeHub, publishToUsers, setInboundMessageHandler, setPresenceObserver, stopRealtimeHeartbeat } from './utils/realtimeHub.js';
import { getActivePartnerUserIds } from './repositories/partnerRepository.js';
import { startCommunityCleanupScheduler } from './services/communityCleanupService.js';
import { startDailyChatSummaryScheduler } from './services/dailyChatSummaryService.js';
import { startPushDispatchScheduler } from './services/pushDispatchService.js';
import { runSchedulersOnOneProcess } from './utils/schedulerLease.js';
import { bootstrapMedicalContent } from './services/contentSeedService.js';

const port = env.port;
let stopSchedulers = () => {};

const server = createServer(app);

/**
 * The AI key and the AI endpoints have to come from the same provider. A key
 * from elsewhere authenticates against nothing and every AI feature fails with
 * a 401 that looks like an outage.
 */
function warnOnProviderMismatch() {
  // Grok (api.x.ai, `xai-...`) and Groq (api.groq.com, `gsk_...`) are different
  // companies. A key from one sent to the other authenticates against nothing
  // and every AI call fails with a 401 that reads like an outage.
  const expectations = [
    { label: 'chat', key: env.aiChatApiKey, url: env.aiChatApiUrl, envName: 'AI_CHAT_API_KEY' },
    { label: 'speech-to-text', key: env.speechToTextApiKey, url: env.speechToTextUrl, envName: 'SPEECH_TO_TEXT_API_KEY' },
  ];

  for (const { label, key, url, envName } of expectations) {
    if (!key) {
      logger.info(`AI ${label} is disabled: ${envName} is not set.`);
      continue;
    }

    const host = String(url ?? '');
    if (host.includes('api.groq.com') && !key.startsWith('gsk_')) {
      logger.error(
        `${envName} does not look like a Groq key (starts with "${key.slice(0, 4)}", expected "gsk_") ` +
        `while the ${label} endpoint points at api.groq.com. It will fail with 401.`,
      );
    }

    if (host.includes('api.x.ai') && !key.startsWith('xai-')) {
      logger.error(
        `${envName} does not look like an xAI key (starts with "${key.slice(0, 4)}", expected "xai-") ` +
        `while the ${label} endpoint points at api.x.ai. It will fail with 401.`,
      );
    }

    if (host.includes('openrouter.ai') && !key.startsWith('sk-or-')) {
      logger.error(
        `${envName} does not look like an OpenRouter key (starts with "${key.slice(0, 4)}", expected "sk-or-") ` +
        `while the ${label} endpoint points at openrouter.ai. It will fail with 401.`,
      );
    }
  }
}

async function start() {
  warnOnProviderMismatch();
  assertCaptchaNotFalselyEnabled();
  await initDatabase();
  await bootstrapMedicalContent();
  initRealtimeHub(server);
  // When a user's socket connects or fully disconnects, tell their active
  // partners so the partner screen can show an online/offline dot. Registered
  // here (not inside the hub) so the hub stays free of partner/DB imports.
  setPresenceObserver(async (userId, online) => {
    try {
      const partnerIds = await getActivePartnerUserIds(userId);
      if (partnerIds.length > 0) {
        publishToUsers(partnerIds, 'partner.presence', { subjectUserId: userId, online });
      }
    } catch (error) {
      logger.warn(`Presence notify failed: ${error?.message ?? error}`);
    }
  });
  // Relay a typing ping to the sender's active partners so their messenger can
  // show a "typing…" indicator. Fire-and-forget; a dropped ping is harmless.
  setInboundMessageHandler(async (userId, message) => {
    if (message?.type !== 'typing') return;
    try {
      const partnerIds = await getActivePartnerUserIds(userId);
      if (partnerIds.length > 0) {
        publishToUsers(partnerIds, 'partner.typing', {
          subjectUserId: userId,
          typing: message.typing === true,
        });
      }
    } catch (error) {
      logger.warn(`Typing relay failed: ${error?.message ?? error}`);
    }
  });
  // Joins the cross-instance bus. No-op without REDIS_URL, so a single
  // instance behaves exactly as before.
  await connectRealtimeBus();
  // Behind a lease, so a second instance serves traffic without also sending
  // every push notification and delivering every time capsule a second time.
  stopSchedulers = await runSchedulersOnOneProcess(() => [
    startCommunityCleanupScheduler(),
    startDailyChatSummaryScheduler(),
    startPushDispatchScheduler(),
    startCapsuleDeliveryScheduler(),
  ]);

  server.listen(port, () => {
    logger.info(`Blushy auth backend listening on port ${port}`);
  });
}

start().catch((error) => {
  logger.error(`Failed to start server: ${error?.message ?? error}`);
  process.exit(1);
});

process.on('SIGINT', () => {
  logger.info('Shutting down gracefully');
  stopSchedulers();
  stopRealtimeHeartbeat();
  disconnectRealtimeBus().catch(() => {});
  server.close(() => process.exit(0));
});